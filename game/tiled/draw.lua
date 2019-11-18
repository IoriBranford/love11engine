local rad = math.rad
local LG = love.graphics

local transform = {}
local function transform_default(node, parent, root)
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

function transform.chunk(node, parent, root)
	local x = node.x or 0
	local y = node.y or 0
	local maptilewidth = root.tilewidth
	local maptileheight = root.tileheight
	LG.translate(x*maptilewidth, y*maptileheight)
end

function transform.layer(node, parent, root)
	transform_default(node, parent, root)
	local maptileheight = root.tileheight
	LG.translate(0, maptileheight)
end

function transform.object(node, parent, root)
	transform_default(node, parent, root)
	local rotation = node.rotation or 0
	LG.rotate(rad(rotation))
	local template = node.template
	local maptiles = root.tiles
	if template then
		node = template
		maptiles = template.tiles
	end
	local gid = node.gid
	local tile = gid and maptiles[gid]
	if tile then
		local width = node.width
		local height = node.height
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

function draw.data(node, parent, root)
	if type(node[1]) ~= "number" then
		return
	end
	local spritebatch = node.spritebatch
	if spritebatch then
		LG.draw(spritebatch)
		return true
	end
	local maptiles = root.tiles
	local maptilewidth = root.tilewidth
	local maptileheight = root.tileheight
	local x = 0
	local y = 0
	local width = node.width or parent.width
	local height = node.height or parent.height
	local i = 1
	for r = 1, height do
		for c = 1, width do
			local tile = maptiles[node[i]]
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
draw.chunk = draw.data

function draw.text(node, parent, root)
	local wrap = node.wrap
	local width = parent.width
	local halign = node.halign
	local valign = node.valign
	local font = node.font
	local y = 0
	local str = node.string
	if valign then
		local height = parent.height
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

function draw.object(node, parent, root)
	local template = node.template
	local maptiles = root.tiles
	if template then
		node = template
		maptiles = template.tiles
	end
	local gid = node.gid
	local tile = gid and maptiles[gid]
	if tile then
		local tileset = tile.tileset
		local tileheight = tileset.tileheight
		local tileoffsetx = tileset.tileoffsetx or 0
		local tileoffsety = tileset.tileoffsety or 0

		LG.draw(tileset.image, tile.quad, 0, 0, 0, 1, 1,
			-tileoffsetx, tileheight - tileoffsety)
		return true
	elseif #node == 0 then
		if node.ellipse then
			local hwidth = node.width/2
			local hheight = node.height/2
			LG.ellipse("line", hwidth, hheight, hwidth, hheight)
			return true
		elseif node.polygon then
			LG.polygon("line", node.polygon)
		elseif node.polyline then
			LG.line(node.polyline)
		else
			local width = node.width or 0
			local height = node.height or 0
			LG.rectangle("line", 0, 0, width, height)
			return true
		end
	end
end

local function drawRecursive(node, parent, root)
	if node.visible == 0 then
		return
	end
	root = root or node
	local tag = node.tag
	LG.push("transform")
	transform[tag](node, parent, root)
	if not draw[tag](node, parent, root) then
		for i = 1, #node do
			drawRecursive(node[i], node, root)
		end
	end
	LG.pop()
end

return drawRecursive
