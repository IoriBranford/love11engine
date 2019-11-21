local love = love
local LE = love.event
local LFS = love.filesystem
local LG = love.graphics
local LJ = love.joystick
local LK = love.keyboard
local LM = love.math
local LP = love.physics
local LT = love.timer
local LW = love.window

local floor = math.floor
local sqrt = math.sqrt
local abs = math.abs
local sin = math.sin
local cos = math.cos
local max = math.max
local min = math.min
local pi = math.pi

local pretty = require "pl.pretty"
local tiled = require "tiled"
local aseprite = require "aseprite"
local engine = require "engine"
local newObject = engine.newObject
local getObject = engine.getObject

local map

local MapViewer = {
	x = 0, y = 0, rotation = 0,
	dx = 0, dy = 0, drotation = 0,
	scalex = 1, scaley = 1,
	dscalex = 0, dscaley = 0
}

function MapViewer:update(dt)
	local keyUp = "w"
	local keyDown = "s"
	local keyLeft = "a"
	local keyRight = "d"
	local keyFire = "z"
	local keySlow = "lshift"
	local keyRotLeft = "q"
	local keyRotRight = "e"
	local keyZoomIn = "c"
	local keyZoomOut = "z"

	local joyX = 1
	local joyY = 2
	local joyHat = 1
	local joyFire = 1
	local joySlow = 2
	local padX = "leftx"
	local padY = "lefty"
	local padUp = "dpup"
	local padDown = "dpdown"
	local padLeft = "dpleft"
	local padRight = "dpright"
	local padRotLeft = "leftshoulder"
	local padRotRight = "rightshoulder"
	local padFire = "x"
	local padSlow = "a"
	local deadzonesq = 1/16
	local speedNormal = 240
	local speedSlow = 120

	local inx, iny = 0, 0
	local inr = 0
	local inz = 0
	inr = inr - (LK.isDown(keyRotLeft)	and 1 or 0)
	inr = inr + (LK.isDown(keyRotRight) 	and 1 or 0)
	inz = inz - (LK.isDown(keyZoomOut)	and 1 or 0)
	inz = inz + (LK.isDown(keyZoomIn) 	and 1 or 0)
	inx = inx - (LK.isDown(keyLeft)	and 1 or 0)
	inx = inx + (LK.isDown(keyRight)and 1 or 0)
	iny = iny - (LK.isDown(keyUp)	and 1 or 0)
	iny = iny + (LK.isDown(keyDown)	and 1 or 0)
	for _, joystick in pairs(LJ.getJoysticks()) do
		local ax, ay = 0, 0
		local bl, br, bu, bd, brl, brr
		if joystick:isGamepad() then
			ax = joystick:getGamepadAxis(padX)
			ay = joystick:getGamepadAxis(padY)
			bl = joystick:isGamepadDown(padLeft)
			br = joystick:isGamepadDown(padRight)
			brl = joystick:isGamepadDown(padRotLeft)
			brr = joystick:isGamepadDown(padRotRight)
			bu = joystick:isGamepadDown(padUp)
			bd = joystick:isGamepadDown(padDown)
		else
			ax = joystick:getAxis(joyX)
			ay = joystick:getAxis(joyY)
			local hat = joystick:getHat(joyHat)
			bl = hat:find("l")
			br = hat:find("r")
			bu = hat:find("u")
			bd = hat:find("d")
		end
		if ax*ax + ay*ay >= deadzonesq then
			inx = inx + ax
			iny = iny + ay
		end
		inr = inr - (brl and 1 or 0)
		inr = inr + (brr and 1 or 0)
		inx = inx - (bl and 1 or 0)
		inx = inx + (br and 1 or 0)
		iny = iny - (bu and 1 or 0)
		iny = iny + (bd and 1 or 0)
	end
	local insq = inx*inx + iny*iny
	if insq > 1 then
		local inmag = sqrt(insq)
		inx = inx / inmag
		iny = iny / inmag
	end

	inz = inz*2
	self.dscalex = inz
	self.dscaley = inz

	local cosr = cos(self.rotation)
	local sinr = sin(self.rotation)
	local rightx = inx*cosr
	local righty = inx*-sinr
	local downx = iny*sinr
	local downy = iny*cosr

	self.dx = -(rightx + downx)*speedNormal
	self.dy = -(righty + downy)*speedNormal
	self.drotation = -inr*pi
end

function MapViewer:fixedUpdate(fixeddt)
	self.x = self.x + self.dx * fixeddt
	self.y = self.y + self.dy * fixeddt
	self.rotation = self.rotation + self.drotation * fixeddt
	self.scalex = self.scalex + self.dscalex * fixeddt
	self.scaley = self.scaley + self.dscaley * fixeddt
	tiled.update(map, fixeddt)
end

local keypressed = {}
local function nop() end
setmetatable(keypressed, {
	__index = function()
		return nop
	end
})

function keypressed.f2()
	engine.reload()
end
function keypressed.escape()
	LE.quit()
end

function love.keypressed(key)
	keypressed[key]()
end

function love.load()
	local gamepadfile = "gamecontrollerdb.txt"
	if LFS.getInfo(gamepadfile) then
		LJ.loadGamepadMappings(gamepadfile)
	end

	local window_width = 1280
	local window_height = 720
	local window_flags = {
		vsync = -1
	}
	LW.setMode(window_width, window_height, window_flags)
end

function love.reload()
	tiled.load.clearCache()
	map = newObject(tiled.load("title.tmx"), MapViewer)
	LG.setLineStyle("rough")
	LG.getFont():setFilter("nearest", "nearest")
end

local stats = {}
function love.draw(alpha)
	local lgw = LG.getWidth()
	local lgh = LG.getHeight()
	local hlgw = lgw/2
	local hlgh = lgh/2
	local rotation = 0*pi

	-- projection matrix
	LG.translate(hlgw, hlgh)
	LG.rotate(rotation)

	tiled.draw(map, alpha)

	local font = LG.getFont()
	local h = font:getHeight()
	local mem = floor(collectgarbage("count"))

	local asinr = abs(sin(rotation))
	local hdiff = asinr*(hlgw - hlgh)
	local y = -hlgh - hdiff
	local w = hlgw - hdiff
	local dt = LT.getDelta()

	local fps = floor(1/dt)
	LG.printf(dt.." dt", 0, y, w, "right")
	y = y + h
	LG.printf(floor(fps).." fps", 0, y, w, "right")
	y = y + h
	LG.printf(mem.." kb", 0, y, w, "right")
	y = y + h
	for k, v in pairs(LG.getStats(stats)) do
		LG.printf(v.." "..k, 0, y, w, "right")
		y = y + h
	end
end
