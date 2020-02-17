local type = type
local LG = love.graphics

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
function draw.object(object, parent, map, lerp)
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
		local dx, dy, dr
		local body = object.body
		if body then
			dx, dy = body:getLinearVelocity()
			dx = dx * lerp
			dy = dy * lerp
			dr = body:getAngularVelocity() * lerp
		end

		if quad then
			LG.draw(image, quad, dx, dy, dr, 1, 1,
				tileoffsetx, tileoffsety)
		else
			LG.draw(image, dx, dy, dr, 1, 1,
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
	local triangles = object.triangles
	local polyline = object.polyline

	if fillcolor then
		LG.setColor(fillcolor)

		if ellipse then
			LG.ellipse("fill", hwidth, hheight, hwidth, hheight)
		elseif triangles then
			for i = 1, #triangles do
				LG.polygon("fill", triangles[i])
			end
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
	local x, y = node.x or 0, node.y or 0
	local r = node.rotation or 0
	local sx, sy = node.scalex or 1, node.scaley or 1
	LG.translate(x, y)
	LG.rotate(r)
	LG.scale(sx, sy)
	if not draw[tag](node, parent, map, lerp) then
		for i = 1, #node do
			drawRecursive(node[i], node, map, lerp)
		end
	end
	LG.pop()
end

return function(map, lerp)
	drawRecursive(map, nil, map, lerp)
end
