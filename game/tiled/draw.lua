local pretty = require "pl.pretty"
local type = type
local cos = math.cos
local sin = math.sin
local LG = love.graphics
local LM = love.math

local transform = {}
local function transform_default(node, parent, map, lerp)
	local x = node.x or 0
	local y = node.y or 0
	local offsetx = node.offsetx or 0
	local offsety = node.offsety or 0
	local dx = node.dx or 0
	local dy = node.dy or 0
	x = x + offsetx + dx*lerp
	y = y + offsety + dy*lerp
	LG.translate(x, y)

	local rotation = node.rotation
	if rotation then
		rotation = rotation + (node.drotation or 0)*lerp
		LG.rotate(rotation)
	end
	local scalex, scaley = node.scalex, node.scaley
	if scalex and scaley then
		local dscalex = node.dscalex or 0
		local dscaley = node.dscaley or 0
		scalex = scalex + dscalex*lerp
		scaley = scaley + dscaley*lerp
		LG.scale(scalex, scaley)
	end
end
setmetatable(transform, {
	__index = function()
		return transform_default
	end
})

function transform.map(node, parent, map, lerp)
	-- view matrix
	local rotation = node.rotation
	if rotation then
		rotation = rotation + (node.drotation or 0)*lerp
		LG.rotate(rotation)
	end
	local scalex, scaley = node.scalex, node.scaley
	if scalex and scaley then
		LG.scale(scalex, scaley)
	end

	-- model matrix
	local x = node.x
	local y = node.y
	if x and y then
		local offsetx = node.offsetx or 0
		local offsety = node.offsety or 0
		local dx = node.dx or 0
		local dy = node.dy or 0
		x = x + offsetx + dx*lerp
		y = y + offsety + dy*lerp
		LG.translate(x, y)
	end
end

function transform.object(object, objectgroup, map, lerp)
	local tile = object.tile
	if tile then
		local width = object.width
		local height = object.height
		local flipx = object.flipx or 1
		local flipy = object.flipy or 1
		local tileset = tile.tileset
		local tilewidth = tileset.tilewidth
		local tileheight = tileset.tileheight
		object.scalex, object.scaley = flipx*width/tilewidth, flipy*height/tileheight
	end
	transform_default(object, objectgroup, map, lerp)
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
	local backgroundcolor = map.backgroundcolor
	if backgroundcolor then
		LG.clear(backgroundcolor)
	end
end

local function drawLayerTile(layer, i, tile, x, y, sx, sy, r)
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
		LG.draw(image, quad, x, y, r, sx, sy, tileoffsetx, tileoffsety)
	else
		LG.draw(image, x, y, r, sx, sy, tileoffsetx, tileoffsety)
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
--[[
function draw.asepritebatch(asepritebatch, parent, map)
	local spritebatch = object.spritebatch
	if spritebatch then
		LG.draw(spritebatch)
	end
end
]]
function draw.object(object, parent, map)
	local spritebatch = object.spritebatch
	if spritebatch then
		if not object.spritei then
			LG.draw(spritebatch)
		end
		return
	end

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

function draw.objectgroup(objectgroup, map, _, lerp)
	local spritebatch = objectgroup.spritebatch
	if spritebatch then
		LG.draw(spritebatch)
		return true
	end
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
