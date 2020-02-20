require "pl.strict"
local love = love
local LE = love.event
local LFS = love.filesystem
local LG = love.graphics
local LJ = love.joystick
local LT = love.timer
local LW = love.window

local floor = math.floor
local abs = math.abs
local sin = math.sin
local pi = math.pi

local pretty = require "pl.pretty"
local assets = require "assets"

local maps = {}

local function init()
	local gamepadfile = "gamecontrollerdb.txt"
	if LFS.getInfo(gamepadfile) then
		LJ.loadGamepadMappings(gamepadfile)
	end

	local window_width = 640
	local window_height = 480
	local window_flags = {
		resizable = true,
		vsync = -1
	}
	LW.setMode(window_width, window_height, window_flags)
	LW.setTitle(LFS.getIdentity())
	LW.maximize()
	LE.push("load", "game.tmx")
end

local function onEvent(ev, ...)
	for filename, map in pairs(maps) do
		local script = map.script
		if script then
			local handler = script[ev]
			if handler then
				handler(map, ...)
			end
		end
	end
end

local function load(...)
	assets.clear()
	local font = assets.get(".defaultFont", floor(LG.getHeight()/48))
	LG.setFont(font)

	maps = {}
	for i = 1, select("#", ...) do
		local filename = select(i, ...)
		local map = filename and assets.get(filename)
		if map then
			map.script = assets.get(map.script)
			maps[filename] = map
		end
	end

	onEvent("start")
end

local function update(dt)
	onEvent("update", dt)
end

local function fixedUpdate(dt)
	onEvent("fixedUpdate", dt)
	for filename, map in pairs(maps) do
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
		LG.push()
		local viewtransform = map.viewtransform
		if viewtransform then
			LG.applyTransform(viewtransform)
		end
		map:draw(lerp)
		onEvent("drawOver", lerp)
		LG.pop()
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

	local fixedfps = 60
	local fixeddt = 1/fixedfps

	local dt = 0
	local timeaccum = 0

	-- Main loop time.
	return function()
		-- Process events.
		if LE then
			LE.pump()
			for name, a,b,c,d,e,f in LE.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end

				onEvent(name, a, b, c, d, e, f)

				if name == "load" then
					load(a, b, c, d, e, f)
					collectgarbage()
					if LT then LT.step() end
					break
				end
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
