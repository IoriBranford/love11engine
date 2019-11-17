local pretty = require "pl.pretty"
local xml = require "pl.xml"
local tablex = require "pl.tablex"
local ffi = require "ffi"
local floor = math.floor
local rad = math.rad
local tonumber = tonumber
local love = love
local LD = love.data
local LFS = love.filesystem
local LG = love.graphics
local LM = love.math

local Tiled = {}

local loaded = {}

local load = {}
setmetatable(load, {
	__index = function()
		return function(node)
			return node
		end
	end
})

function load.properties(node, parent, dir)
	for i = 1, #node do
		local property = node[i]
		local ptype = property.type
		local value = property.value or property.default
		if value and ptype == "file" then
			value = dir..value
		end
		parent[property.name] = value
	end
end

function load.objecttype(node, parent, dir)
	load.properties(node, node, dir)
	for i = #node, 1, -1 do
		node[i] = nil
	end
	return node
end

function load.objecttypes(node, parent, dir)
	for i = #node, 1, -1 do
		local objecttype = node[i]
		node[objecttype.name] = objecttype
		node[i] = nil
	end
	return node
end

function load.ellipse(node, parent, dir)
	parent.ellipse = true
end

function load.point(node, parent, dir)
	parent.point = true
end

local function parsePoints(pointsstring)
	local points = {}
	for point in pointsstring:gmatch("[-.%d]+,[-.%d]+") do
		local x, y = point:match("([-.%d]+),([-.%d]+)")
		points[#points+1] = tonumber(x)
		points[#points+1] = tonumber(y)
	end
	return points
end

function load.polygon(node, parent, dir)
	parent.polygon = parsePoints(node.points)
end

function load.polyline(node, parent, dir)
	parent.polyline = parsePoints(node.points)
end

function load.text(node, parent, dir)
	node.string = node[1]
	node[1] = nil
	local fontfamily = node.fontfamily
	local file = dir..fontfamily
	if node.bold then
		file = file.."bold"
	end
	if node.italic then
		file = file.."italic"
	end
	if node.underline then
		file = file.."underline"
	end
	local pixelsize = node.pixelsize or 16
	local ttfsize = file..".ttf"..pixelsize
	local fnt = file..pixelsize..".fnt"
	local font = loaded[fnt] or loaded[ttfsize]
	if not font then
		font = LFS.getInfo(fnt) and LG.newFont(fnt)
		if font then
			loaded[fnt] = font
		end
	end
	if not font then
		local ttf = file..".ttf"
		font = LFS.getInfo(ttf) and LG.newFont(ttf, pixelsize)
		if font then
			loaded[ttfsize] = font
		end
	end
	if not font then
		local defaultfont = "defaultfont"..pixelsize
		font = loaded[defaultfont] or LG.newFont(pixelsize)
		loaded[defaultfont] = font
	end
	font:setFilter("nearest", "nearest")
	node.font = font
	return node
end

local function decodeData(gids, data, encoding, compression)
	if not data then
		return
	end
	if encoding == "base64" then
		data = LD.decode("data", encoding, data)
	end
	if compression then
		data = LD.decompress("data", compression, data)
	end
	local pointer = ffi.cast("uint32_t*", data:getFFIPointer())
	gids = gids or {}
	local n = floor(data:getSize() / ffi.sizeof("uint32_t"))
	for i = 0, n-1 do
		gids[#gids + 1] = pointer[i]
	end
end

function load.template(node, parent, dir)
	load.map(node, parent, dir)
	local object = node[2] or node[1]
	object.tiles = node.tiles
	return object
end

function load.object(node, parent, dir)
	local template = node.template
	if template then
		local file = dir..template
		template = loaded[file] or Tiled.load(file)
		loaded[file] = template
		node.template = template
	end
	return node
end

function load.animation(node, parent, dir)
	parent.animation = node
end

function load.terraintypes(node, parent, dir)
	parent.terraintypes = node
end

function load.tile(node, parent, dir)
	local gid = node.gid
	if gid then
		parent[#parent + 1] = gid
	end
	local terrain = node.terrain
	if terrain then
		terrain = { terrain:match("(%d*),(%d*),(%d*),(%d*)") }
		for i = 1, 4 do
			local t = tonumber(terrain[i])
			terrain[i] = t and (t + 1) or false
		end
		node.terrain = terrain
	end
	return node
end

function load.data(node, parent, dir)
	local data = node[1]
	if type(data) == "string" then
		node[1] = nil
		local encoding = node.encoding or parent.encoding
		local compression = node.compression or parent.compression
		decodeData(node, data, encoding, compression)
	end
	return node
end
load.chunk = load.data

function load.tileoffset(node, parent, dir)
	parent.tileoffsetx = node.x
	parent.tileoffsety = node.y
end

function load.grid(node, parent, dir)
	parent.gridwidth = node.width
	parent.gridheight = node.height
	parent.gridorientation = node.orientation
end

function load.image(node, parent, dir)
	local file = dir..node.source
	local image = loaded[file]
	if not image then
		image = LG.newImage(file)
		if image then
			image:setFilter("nearest", "nearest")
		end
		loaded[file] = image
	end
	parent.image = image
end

function load.tileset(node, parent, dir)
	local source = node.source
	if source then
		local file = dir..source
		local exttileset = loaded[file]
		if not exttileset then
			exttileset = Tiled.load(file)
			loaded[file] = exttileset
		end
		tablex.update(node, exttileset)
	end

	local tilecount = node.tilecount or 0
	local columns = node.columns or 0
	local rows = floor(tilecount/columns)
	local tilewidth = node.tilewidth
	local tileheight = node.tileheight
	local image = node.image
	local imagewidth = image:getWidth()
	local imageheight = image:getHeight()
	local i, x, y = 0, 0, 0
	for r = 1, rows do
		for c = 1, columns do
			local tile = node[i] or {}
			node[i] = tile
			tile.tileset = node
			tile.quad = LG.newQuad(x, y, tilewidth, tileheight,
						imagewidth, imageheight)
			x = x + tilewidth
			i = i + 1
		end
		x = 0
		y = y + tileheight
	end

	if parent then
		local tilesets = parent.tilesets or {}
		parent.tilesets = tilesets
		tilesets[#tilesets + 1] = node
		return
	end

	return node
end

function load.map(node, parent, dir)
	local tilesets = node.tilesets or {}
	local tiles = {}
	node.tiles = tiles
	for i = 1, #tilesets do
		local tileset = tilesets[i]
		local gid = tileset.firstgid
		local tile = tileset[0]
		if tile then
			tiles[gid] = tile
			gid = gid + 1
		end
		for t = 1, #tileset do
			local tile = tileset[t]
			tiles[gid] = tile
			gid = gid + 1
		end
	end
	return node
end

local function loadRecursive(doc, parent, dir)
	if type(doc) == "string" then
		return doc
	end
	local node = {}
	local tag = doc.tag
	node.tag = tag
	local attr = doc.attr
	for k,v in pairs(attr) do
		local number = tonumber(v)
		if number then
			v = number
		elseif v == "" then
			v = nil
		elseif v == "false" then
			v = false
		elseif v == "true" then
			v = true
		end
		node[k] = v
	end
	local n = #doc
	for i = 1, n do
		node[i] = loadRecursive(doc[i], node, dir)
	end
	node = load[tag](node, parent, dir)
	if not node then
		return
	end
	for gap2 = n-1, 1, -1 do
		if not node[gap2] then
			for gap1 = gap2-1, 0, -1 do
				if gap1 == 0 or node[gap1] then
					local gapsize = gap2 - (gap1 + 1)
					for i = gap2+1, n do
						gap1 = gap1 + 1
						node[gap1] = node[i]
						node[i] = nil
					end
					n = n - gapsize
					break
				end
			end
		end
	end
	return node
end

function Tiled.load(file)
	local text, doc, err
	text, err = LFS.read(file)
	if not text then
		print(err)
		return
	end
	doc, err = xml.parse(text)
	if not doc then
		print(err)
		return
	end

	local dir = file:match('(.*/)[^/]*$') or ""
	return loadRecursive(doc, nil, dir)
end

local transform = {}
local function transform_default(node, parent, root)
	local x = node.x or 0
	local y = node.y or 0
	local offsetx = node.offsetx or 0
	local offsety = node.offsety or 0
	local rotation = node.rotation or 0
	LG.translate(x + offsetx, y + offsety)
	LG.rotate(rad(rotation))
end
setmetatable(transform, {
	__index = function()
		return transform_default
	end
})

function transform.object(node, parent, root)
	transform_default(node, parent, root)
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
	local maptiles = root.tiles
	if not maptiles then
		return
	end
	local width = node.width or parent.width
	local height = node.height or parent.height
	local maptilewidth = root.tilewidth
	local maptileheight = root.tileheight
	local i = 1
	local x = node.x or 0
	local y = node.y or 0
	for r = 1, height do
		for c = 1, width do
			local tile = maptiles[node[i]]
			if tile then
				local tileset = tile.tileset
				local tileoffsetx = tileset.tileoffsetx or 0
				local tileoffsety = tileset.tileoffsety or 0
				LG.draw(tileset.image, tile.quad, x, y, 0, 1, 1,
					-tileoffsetx, -tileoffsety)
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
	LG.printf(node.string, node.font, 0, 0, wrap and width, halign)
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
Tiled.draw = drawRecursive

function Tiled.unload()
	loaded = {}
end

return Tiled
