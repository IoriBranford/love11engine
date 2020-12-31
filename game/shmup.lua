local assets = require "assets"
local player = require "player"
local world = require "world"
local shmup = {}

function shmup.load(args)
	local commandline = args[1]
	local mapfile = commandline and commandline[1]
	mapfile = mapfile and love.filesystem.getInfo(mapfile) and mapfile or "shmup.json"
	shmup.map = assets.get(mapfile)

	love.graphics.setLineStyle("rough")
	assets.get(".defaultFont"):setFilter("nearest", "nearest")
	shmup.canvas = love.graphics.newCanvas(480, 640)
	shmup.canvas:setFilter("nearest", "nearest")

	world.load()
	world.physics_world:add({ team = "boundary" }, -16, 0, 16, 640)
	world.physics_world:add({ team = "boundary" }, 480, 0, 16, 640)
	world.physics_world:add({ team = "boundary" }, 0, -16, 480, 16)
	world.physics_world:add({ team = "boundary" }, 0, 640, 480, 16)

	shmup.player = player.create(240, 640)
end

function shmup.quit()
	world.quit()
	assets.clear()
end

function shmup.fixedupdate()
	world.fixedupdate()
end

function shmup.update(dt)
	world.update(dt)
end

function shmup.draw(lerp)
	love.graphics.setCanvas(shmup.canvas)
	love.graphics.clear(shmup.map.backgroundcolor)
	shmup.map:draw()
	world.draw(lerp)
	love.graphics.setCanvas()

	local graphicshalfw = love.graphics.getWidth()/2
	local graphicshalfh = love.graphics.getHeight()/2
	local canvashalfw = shmup.canvas:getWidth()/2
	local canvashalfh = shmup.canvas:getHeight()/2
	local canvasscale = math.min(graphicshalfw/canvashalfw, graphicshalfh/canvashalfh)
	love.graphics.draw(shmup.canvas, graphicshalfw, graphicshalfh, 0, canvasscale, canvasscale, canvashalfw, canvashalfh)
	love.graphics.printf(string.format("%d fps", love.timer.getFPS()), 0, 0, 480)
end

return shmup
