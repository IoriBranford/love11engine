local rad = math.rad
local LG = love.graphics

local transform = {}
local function transform_default(node, parent, map)
	local x = node.x or 0
	local y = node.y or 0
	local offsetx = node.offsetx or 0
	local offsety = node.offsety or 0
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

function transform.layer(layer, map)
	transform_default(layer, map)
	local maptileheight = map.tileheight
	LG.translate(0, maptileheight)
end

function transform.object(object, objectgroup, map)
	transform_default(object, objectgroup, map)
	local rotation = object.rotation or 0
	LG.rotate(rad(rotation))
	local template = object.template
	local maptiles = map.tiles
	if template then
		object = template
		maptiles = template.tiles
	end
	local gid = object.gid
	local tile = gid and maptiles[gid]
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
	local maptiles = map.tiles
	local maptilewidth = map.tilewidth
	local maptileheight = map.tileheight
	local x = 0
	local y = 0
	local width = layer.width or map.width
	local height = layer.height or map.height
	local i = 1
	for r = 1, height do
		for c = 1, width do
			local tile = maptiles[layer[i]]
			if tile then
				local tileset = tile.tileset
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
	local maptiles = map.tiles
	if template then
		object = template
		maptiles = template.tiles
	end
	local gid = object.gid
	local tile = gid and maptiles[gid]
	if tile then
		local tileset = tile.tileset
		local tileheight = tileset.tileheight
		local tileoffsetx = tileset.tileoffsetx or 0
		local tileoffsety = tileset.tileoffsety or 0

		LG.draw(tileset.image, tile.quad, 0, 0, 0, 1, 1,
			-tileoffsetx, tileheight - tileoffsety)
		return true
	elseif #object == 0 then
		if object.ellipse then
			local hwidth = object.width/2
			local hheight = object.height/2
			LG.ellipse("line", hwidth, hheight, hwidth, hheight)
			return true
		elseif object.polygon then
			LG.polygon("line", object.polygon)
		elseif object.polyline then
			LG.line(object.polyline)
		else
			local width = object.width or 0
			local height = object.height or 0
			LG.rectangle("line", 0, 0, width, height)
			return true
		end
	end
end

local function drawRecursive(node, parent, map)
	if node.visible == 0 then
		return
	end
	map = map or node
	local tag = node.tag
	LG.push("transform")
	transform[tag](node, parent, map)
	if not draw[tag](node, parent, map) then
		for i = 1, #node do
			drawRecursive(node[i], node, map)
		end
	end
	LG.pop()
end

return drawRecursive
