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

local postprocess = {}
setmetatable(postprocess, {
	__index = function()
		return function(doc)
			return doc
		end
	end
})

function postprocess.properties(node, parent, dir)
	for c = 1, #node do
		local property = node[c]
		local ptype = property.type
		local value = property.value or property.default
		if value and ptype == "file" then
			value = dir..value
		end
		parent[property.name] = value
	end
end

postprocess.objecttype = postprocess.properties

function postprocess.ellipse(node, parent, dir)
	parent.ellipse = true
end

function postprocess.point(node, parent, dir)
	parent.point = true
end

function postprocess.polygon(node, parent, dir)
	parent.polygon = node.points
end

function postprocess.polyline(node, parent, dir)
	parent.polyline = node.points
end

function postprocess.text(node, parent, dir)
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
		font = LFS.getInfo(fnt) and LG.newFont(file)
		if font then
			loaded[fnt] = font
		else
			local ttf = file..".ttf"
			font = LFS.getInfo(ttf) and LG.newFont(ttf, pixelsize)
			if font then
				loaded[ttfsize] = font
			end
		end
	end
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

function postprocess.tile(node, parent, dir)
	local gid = node.gid
	if gid then
		parent[#parent + 1] = gid
	end
	return node
end

function postprocess.data(node, parent, dir)
	local encoding = node.encoding
	local compression = node.compression
	if encoding or compression then
		local data = node[1]
		if type(data) == "string" then
			decodeData(node, data, encoding, compression)
		else
			for i = 1, #node do
				data = node[i]
				decodeData(data, data, encoding, compression)
			end
		end
	end
	return node
end

function postprocess.tileoffset(node, parent, dir)
	parent.tileoffsetx = node.x
	parent.tileoffsety = node.y
end

function postprocess.grid(node, parent, dir)
	parent.gridwidth = node.width
	parent.gridheight = node.height
	parent.gridorientation = node.orientation
end

function postprocess.image(node, parent, dir)
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

function postprocess.tileset(node, parent, dir)
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

function postprocess.map(node, parent, dir)
	local tilesets = node.tilesets or {}
	local tiles = {}
	node.tiles = tiles
	for i = 1, #tilesets do
		local tileset = tilesets[i]
		local gid = tileset.firstgid
		for t = 0, #tileset-1 do
			local tile = tileset[t]
			tiles[gid] = tile
			gid = gid + 1
		end
	end
	return node
end

local function walk(doc, parent, dir)
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
		node[i] = walk(doc[i], node, dir)
	end
	node = postprocess[tag](node, parent, dir)
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
	return walk(doc, nil, dir)
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
	local gid = node.gid
	if gid then
		local maptiles = root.tiles
		local tile = tiles[gid]
		if tile then
			local tileset = tile.tileset
			local tilewidth = tileset.tilewidth
			local tileheight = tileset.tileheight
			local width = node.width
			local height = node.height
			local sx, sy = width/tilewidth, height/tileheight
			LG.scale(sx, sy)
		end
	end
end

local draw = {}
setmetatable(draw, {
	__index = function()
		return function() end
	end
})

function draw.data(node, parent, root)
	local maptiles = root.tiles
	if not maptiles then
		return
	end
	local width = node.width
	local height = node.height
	local maptilewidth = root.tilewidth
	local maptileheight = root.tileheight
	local i = 1
	local x, y = 0, 0
	for r = 1, height do
		for c = 1, width do
			local tile = maptiles[data[i]]
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
end
draw.chunk = draw.data

function draw.text(node, parent, root)
	local wrap = node.wrap
	local width = parent.width
	local halign = node.halign
	LG.printf(node.string, node.font, 0, 0, wrap and width, halign)
end

function draw.object(node, parent, root)
	local gid = node.gid
	if gid then
		local maptiles = root.tiles
		local tile = tiles[gid]
		if tile then
			local width = node.width
			local tileset = tile.tileset
			local tileheight = tileset.tileheight
			local tileoffsetx = tileset.tileoffsetx or 0
			local tileoffsety = tileset.tileoffsety or 0

			LG.draw(tileset.image, tile.quad, 0, 0, 0, 1, 1,
				-tileoffsetx, tileheight - tileoffsety)
		end
	elseif node.ellipse then
		local width = node.width
		local height = node.height
		LG.ellipse("line", 0, 0, width/2, height/2)
	else
		local width = node.width or 0
		local height = node.height or 0
		LG.rectangle("line", 0, 0, width, height)
	end
end

function Tiled.draw(node, parent, root)
	if node.visible == false then
		return
	end
	root = root or node
	local tag = node.tag
	LG.push("transform")
	transform[tag](node)
	for i = 1, #node do
		draw[tag](node[i], node, root)
	end
	LG.pop()
end

function Tiled.unload()
	loaded = {}
end

return Tiled
