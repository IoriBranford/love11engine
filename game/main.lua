local love = love
local LE = love.event
local LFS = love.filesystem
local LG = love.graphics
local LJ = love.joystick
local LT = love.timer
local LW = love.window

local floor = math.floor
local sqrt = math.sqrt
local abs = math.abs
local sin = math.sin
local pi = math.pi

local pretty = require "pl.pretty"
local assets = require "assets"

local fixedfps = 60
local fixeddt = 1/fixedfps
local toload = { "title.tmx", "gameplay.tmx" }

local maps = nil

local function init()
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

local function load()
	assets.clear()
	local font = assets.get(".defaultFont", floor(LG.getHeight()/48))
	font:setFilter("nearest", "nearest")
	LG.setFont(font)
	maps = {}
	for i = 1, #toload do
		local filename = toload[i]
		local map = assets.get(filename)
		maps[filename] = map
		map:broadcast("init")
	end
end

local function broadcast(ev, ...)
	for filename, map in pairs(maps) do
		map:broadcast(ev, ...)
	end
end

local function update(dt)
	for filename, map in pairs(maps) do
		map:broadcast("update", dt)
	end
end

local function fixedUpdate(dt)
	for filename, map in pairs(maps) do
		map:broadcast("fixedUpdate", dt)
		map:update(dt)
	end
end

local stats = {}
local function draw(lerp)
	local lgw = LG.getWidth()
	local lgh = LG.getHeight()
	local hlgw = lgw/2
	local hlgh = lgh/2
	local rotation = 0*pi

	-- projection matrix
	LG.translate(hlgw, hlgh)
	LG.rotate(rotation)

	for filename, map in pairs(maps) do
		map:draw(lerp)
	end

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

function love.run()
	init(love.arg.parseGameArguments(arg), arg)
	if LT then LT.step() end

	local dt = 0
	local timeaccum = 0

	-- Main loop time.
	return function()
		if toload then
			load()
			collectgarbage()
			toload = nil
			if LT then LT.step() end
		end

		-- Process events.
		if LE then
			LE.pump()
			for name, a,b,c,d,e,f in LE.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				broadcast(name, a, b, c, d, e, f)
			end
		end

		if LT then dt = LT.step() end

		update(dt)

		timeaccum = timeaccum + dt
		while timeaccum >= fixeddt do
			fixedUpdate(fixeddt)
			timeaccum = timeaccum - fixeddt
		end

		if LG and LG.isActive() then
			LG.origin()
			draw(timeaccum)
			LG.present()
		end

		if LT then LT.sleep(0.001) end
		collectgarbage("step", 2)
	end
end
