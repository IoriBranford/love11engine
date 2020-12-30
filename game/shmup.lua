local assets = require "assets"
local player = require "player"
local unit = require "unit"
local shmup = {}

function shmup.load()
	shmup.map = assets.get("shmup.json")
	love.graphics.setLineStyle("rough")
	assets.get(".defaultFont"):setFilter("nearest", "nearest")
	shmup.canvas = love.graphics.newCanvas(480, 640)
	shmup.canvas:setFilter("nearest", "nearest")

	unit.load()
	unit.world:add({ team = "boundary" }, -16, 0, 16, 640)
	unit.world:add({ team = "boundary" }, 480, 0, 16, 640)
	unit.world:add({ team = "boundary" }, 0, -16, 480, 16)
	unit.world:add({ team = "boundary" }, 0, 640, 480, 16)

	shmup.player = player.create(240, 640)
end

function shmup.quit()
	unit.quit()
	assets.clear()
end

function shmup.fixedupdate()
	unit.fixedupdateall()
end

function shmup.update(dt)
	unit.updateall(dt)
end

function shmup.draw(lerp)
	love.graphics.setCanvas(shmup.canvas)
	love.graphics.clear(shmup.map.backgroundcolor)
	shmup.map:draw()
	unit.drawall(lerp)
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
