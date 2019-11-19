local pretty = require "pl.pretty"
local type = type
local rad = math.rad
local LG = love.graphics

local transform = {}
local function transform_default(node, parent, map, lerp)
	local x = node.x
	local y = node.y
	if x and y then
		local offsetx = node.offsetx or 0
		local offsety = node.offsety or 0
		local body = node.body
		if body then
			local vx, vy = body:getLinearVelocity()
			x = x + (vx*lerp)
			y = y + (vy*lerp)
		end
		LG.translate(x + offsetx, y + offsety)
	end
	local rotation = node.rotation or 0
	if rotation then
		LG.rotate(rad(rotation))
	end
end
setmetatable(transform, {
	__index = function()
		return transform_default
	end
})

function transform.chunk(chunk, layer, map)
	local x = chunk.x or 0
	local y = chunk.y or 0
	local maptilewidth = map.tilewidth
	local maptileheight = map.tileheight
	LG.translate(x*maptilewidth, y*maptileheight)
end

function transform.layer(layer, map, _, lerp)
	transform_default(layer, map, _, lerp)
	local maptileheight = map.tileheight
	LG.translate(0, maptileheight)
end

function transform.object(object, objectgroup, map, lerp)
	transform_default(object, objectgroup, map, lerp)
	local tile = object.tile
	if tile then
		local width = object.width
		local height = object.height
		local tileset = tile.tileset
		local tilewidth = tileset.tilewidth
		local tileheight = tileset.tileheight
		local sx, sy = width/tilewidth, height/tileheight
		LG.scale(sx, sy)
	end
end

local draw = {}
setmetatable(draw, {
	__index = function()
		return function()
			return false
		end
	end
})

function draw.map(map)
	LG.clear(map.backgroundcolor)
end

local function drawLayerTile(layer, tile, x, y, i)
	if not tile then
		return
	end
	local tileset = tile.tileset
	local f = layer.tileanimationframes[i]
	if f then
		tile = tileset:getAnimationFrameTile(tile, f)
	end
	local tileoffsetx = tileset.tileoffsetx
	local tileoffsety = tileset.tileoffsety
	local image = tile.image or tileset.image
	local quad = tile.quad
	if quad then
		LG.draw(image, quad, x, y, 0, 1, 1, tileoffsetx, tileoffsety)
	else
		LG.draw(image, x, y, 0, 1, 1, tileoffsetx, tileoffsety)
	end
end

function draw.layer(layer, map)
	if type(layer[1]) ~= "number" then
		return
	end
	local spritebatch = layer.spritebatch
	if spritebatch then
		LG.draw(spritebatch)
	else
		map:forEachLayerTile(layer, drawLayerTile)
	end
	return true
end
local draw_layer = draw.layer

function draw.chunk(chunk, layer, map)
	return draw_layer(chunk, map)
end

function draw.text(text, object, map)
	local wrap = text.wrap
	local width = object.width
	local halign = text.halign
	local valign = text.valign
	local font = text.font
	local y = 0
	local str = text.string
	if valign then
		local height = object.height
		local _, lines = font:getWrap(str, wrap and width or 1048576)
		local textheight = font:getHeight()*#lines
		y = height - textheight
		if valign == "center" then
			y = y/2
		end
	end
	LG.printf(str, font, 0, y, wrap and width, halign)
	return true
end

function draw.object(object, objectgroup, map)
	local tile = object.tile
	if tile then
		local tileset = tile.tileset
		local tileoffsetx = tileset.tileoffsetx
		local tileoffsety = tileset.tileoffsety
		local image = tile.image or tileset.image
		local quad = tile.quad
		if quad then
			LG.draw(image, quad, 0, 0, 0, 1, 1,
				tileoffsetx, tileoffsety)
		else
			LG.draw(image, 0, 0, 0, 1, 1,
				tileoffsetx, tileoffsety)
		end
		return true
	end

	local fillcolor = object.fillcolor
	local linecolor = object.linecolor
	if not fillcolor and not linecolor then
		return
	end

	local width = object.width or 2
	local height = object.height or 2
	local hwidth = width/2
	local hheight = height/2
	local ellipse = object.ellipse or object.point
	local polygon = object.polygon
	local polyline = object.polyline

	if fillcolor then
		LG.setColor(fillcolor)

		if ellipse then
			LG.ellipse("fill", hwidth, hheight, hwidth, hheight)
		elseif polygon then
			LG.polygon("fill", polygon)
		else
			LG.rectangle("fill", 0, 0, width, height)
		end
	end

	if linecolor then
		LG.setColor(linecolor)

		if ellipse then
			LG.ellipse("line", hwidth, hheight, hwidth, hheight)
		elseif polygon then
			LG.polygon("line", polygon)
		elseif polyline then
			LG.line(polyline)
		else
			LG.rectangle("line", 0, 0, width, height)
		end
	end

	LG.setColor(1,1,1)
end

local function drawRecursive(node, parent, map, lerp)
	if node.visible == false then
		return
	end
	map = map or node
	local tag = node.tag
	LG.push("transform")
	transform[tag](node, parent, map, lerp)
	if not draw[tag](node, parent, map) then
		for i = 1, #node do
			drawRecursive(node[i], node, map, lerp)
		end
	end
	LG.pop()
end

return function(map, lerp)
	drawRecursive(map, nil, map, lerp)
end
