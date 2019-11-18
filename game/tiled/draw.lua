local pretty = require "pl.pretty"
local rad = math.rad
local LG = love.graphics

local transform = {}
local function transform_default(node, parent, map, lerp)
	local x = node.x or 0
	local y = node.y or 0
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
	local rotation = object.rotation or 0
	LG.rotate(rad(rotation))
	local template = object.template
	local tiles = map.tiles
	local gid = object.gid
	if template then
		object = template
		gid = gid or template.gid
		tiles = template.tileset
	end
	local tile = tiles and tiles[gid]
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

function draw.layer(layer, map)
	if type(layer[1]) ~= "number" then
		return
	end
	local spritebatch = layer.spritebatch
	if spritebatch then
		LG.draw(spritebatch)
		return true
	end
	local tiles = map.tiles
	local maptilewidth = map.tilewidth
	local maptileheight = map.tileheight
	local x = 0
	local y = 0
	local width = layer.width or map.width
	local height = layer.height or map.height
	local i = 1
	local tileanimationframes = layer.tileanimationframes
	for r = 1, height do
		for c = 1, width do
			local tile = tiles[layer[i]]

			if tile then
				local tileset = tile.tileset
				local f = tileanimationframes[i]
				if f then
					tile = tileset:getAnimationFrameTile(tile, f)
				end
				local tileheight = tileset.tileheight or 0
				local tileoffsetx = tileset.tileoffsetx or 0
				local tileoffsety = tileset.tileoffsety or 0
				LG.draw(tileset.image, tile.quad, x, y, 0, 1, 1,
					-tileoffsetx, tileheight-tileoffsety)
			end
			i = i + 1
			x = x + maptilewidth
		end
		x = 0
		y = y + maptileheight
	end
	return true
end

function draw.chunk(chunk, layer, map)
	return draw.layer(chunk, map)
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
	local template = object.template
	local tiles = map.tiles
	local gid = object.gid
	if template then
		gid = gid or template.gid
		tiles = template.tileset
	end
	local tile = tiles and tiles[gid]
	if tile then
		local tileset = tile.tileset
		local tileheight = tileset.tileheight
		local tileoffsetx = tileset.tileoffsetx or 0
		local tileoffsety = tileset.tileoffsety or 0
		local f = object.animationframe
		if f then
			tile = tileset[tile.animation[f].tileid]
		end

		LG.draw(tileset.image, tile.quad, 0, 0, 0, 1, 1,
			-tileoffsetx, tileheight - tileoffsety)
		return true
	end

	local fillcolor = object.fillcolor
	local linecolor = object.linecolor
	object = template or object
	if fillcolor or linecolor then
		if object.ellipse then
			local hwidth = object.width/2
			local hheight = object.height/2
			LG.ellipse("line", hwidth, hheight, hwidth, hheight)
		elseif object.polygon then
			LG.polygon("line", object.polygon)
		elseif object.polyline then
			LG.line(object.polyline)
		else
			local width = object.width or 0
			local height = object.height or 0
			LG.rectangle("line", 0, 0, width, height)
		end
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

return drawRecursive
