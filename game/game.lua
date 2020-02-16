local LG = love.graphics

local Game = {}

function Game.start(map)
	map:setViewTransform(-LG.getWidth()/2, -LG.getHeight()/2)
end

function Game.update(map)
end

function Game.fixedUpdate(map)
end

return Game
