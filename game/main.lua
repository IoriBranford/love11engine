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
local assets = require "assets"

local fixedfps = 60
local fixeddt = 1/fixedfps
local nextmapfiles = { "title.tmx", "gameplay.tmx" }

local coroutines = {}

local maps = nil

local MapViewer = {}

yield = coroutine.yield
function changeMaps(...)
	nextmapfiles = {...}
end

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

local function loadNextMaps()
	coroutines = {}
	assets.clear()
	local font = assets.get(".defaultFont", floor(LG.getHeight()/48))
	font:setFilter("nearest", "nearest")
	LG.setFont(font)
	maps = {}
	for i = 1, #nextmapfiles do
		local filename = nextmapfiles[i]
		local map = assets.get(filename)
		maps[filename] = map
		local script = map.properties.script
		script = script and assets.get(script)
		local co = script and coroutine.create(script)
		if co then
			coroutines[filename] = co
		end
	end
	--MapViewer.init(maps["title.tmx"])
	--local hudmap = maps["gameplay.tmx"]
	--if hudmap then
	--	hudmap.x = -LG.getWidth()/2
	--	hudmap.y = -LG.getHeight()/2
	--end
	LG.setLineStyle("rough")
end

local function update(dt)
	--MapViewer.update(maps["title.tmx"], dt)
end

local function fixedUpdate(dt)
	--MapViewer.fixedUpdate(maps["title.tmx"], dt)
	for id, co in pairs(coroutines) do
		self = maps[id]
		local ok, err = coroutine.resume(co, dt)
		if coroutine.status(co) == "dead" then
			coroutines[id] = nil
		end
		if not ok then
			error(err)
		end
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
		if nextmapfiles then
			loadNextMaps()
			collectgarbage()
			nextmapfiles = nil
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
				love.handlers[name](a,b,c,d,e,f)
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
