local pi = math.pi
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local LE = love.event
local LG = love.graphics
local LJ = love.joystick
local LK = love.keyboard

local MapViewer = {}

function MapViewer:start()
	LG.setLineStyle("rough")
	self.x = 0
	self.y = 0
	self.rotation = 0
	self.scalex = 1
	self.scaley = 1
	self.dx = 0
	self.dy = 0
	self.drotation = 0
	self.dscalex = 0
	self.dscaley = 0
end

function MapViewer:keypressed(key)
	if key == "f2" then
		setNextMaps(self.filename, "gameplay.tmx")
	elseif key == "escape" then
		LE.quit()
	end
end

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

function MapViewer:fixedUpdate(dt)
	self.x = self.x + self.dx * dt
	self.y = self.y + self.dy * dt
	self.rotation = self.rotation + self.drotation * dt
	self.scalex = self.scalex + self.dscalex * dt
	self.scaley = self.scaley + self.dscaley * dt
end

return MapViewer
