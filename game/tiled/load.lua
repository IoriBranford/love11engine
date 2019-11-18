local pretty = require "pl.pretty"
local xml = require "pl.xml"
local tablex = require "pl.tablex"
local ffi = require "ffi"
local floor = math.floor
local max = math.max
local min = math.min
local huge = math.huge
local type = type
local pairs = pairs
local tonumber = tonumber
local love = love
local LD = love.data
local LFS = love.filesystem
local LG = love.graphics

local Tiled = {}

local Map = {}

local loaded = {}

local load = {}
setmetatable(load, {
	__index = function()
		return function(node)
			return node
		end
	end
})

function load.properties(properties, parent, dir)
	for i = 1, #properties do
		local property = properties[i]
		local ptype = property.type
		local value = property.value or property.default
		if value and ptype == "file" then
			value = dir..value
		end
		parent[property.name] = value
	end
end

function load.objecttype(objecttype, objecttypes, dir)
	load.properties(objecttype, objecttype, dir)
	for i = #objecttype, 1, -1 do
		objecttype[i] = nil
	end
	return objecttype
end

function load.objecttypes(objecttypes, parent, dir)
	for i = #objecttypes, 1, -1 do
		local objecttype = objecttypes[i]
		objecttypes[objecttype.name] = objecttype
		objecttypes[i] = nil
	end
	return objecttypes
end

function load.ellipse(ellipse, object, dir)
	object.ellipse = true
end

function load.point(point, object, dir)
	object.point = true
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

function load.polygon(polygon, object, dir)
	object.polygon = parsePoints(polygon.points)
end

function load.polyline(polyline, object, dir)
	object.polyline = parsePoints(polyline.points)
end

function load.text(text, object, dir)
	text.string = text[1]
	text[1] = nil
	local fontfamily = text.fontfamily
	local file = dir..fontfamily
	if text.bold then
		file = file.."bold"
	end
	if text.italic then
		file = file.."italic"
	end
	if text.underline then
		file = file.."underline"
	end
	local pixelsize = text.pixelsize or 16
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
	text.font = font
	return text
end

function load.template(template, _, dir)
	local object = template[#template]
	object.tileset = template.tileset
	Map.setObjectGid(template, object, object.gid)
	return object
end

function load.object(object, parent, dir)
	local template = object.template
	if template then
		local file = dir..template
		template = loaded[file] or Tiled.load(file)
		loaded[file] = template
		object.template = template
	end
	return object
end

function load.objectgroup(objectgroup, parent, dir)
	if parent.tag == "map" then
		for i = 1, #objectgroup do
			local object = objectgroup[i]
			Map.setObjectGid(parent, object, object.gid)
		end
	end
	return objectgroup
end

local Animation = {}
Animation.__index = Animation

function Animation.getUpdate(animation, f, msecs, dt)
	local deltamsecs = dt * 1000
	msecs = msecs + deltamsecs
	local duration = animation[f].duration
	while msecs >= duration do
		msecs = msecs - duration
		f = (f == #animation) and 1 or (f + 1)
		duration = animation[f].duration
	end
	return f, msecs
end

function load.animation(animation, tile, dir)
	setmetatable(animation, Animation)
	tile.animation = animation
	animation.globalmsecs = 0
	animation.globalframe = 1
end

function load.terraintypes(terraintypes, parent, dir)
	parent.terraintypes = terraintypes
end

function load.tile(tile, parent, dir)
	local gid = tile.gid
	if gid then
		parent[#parent + 1] = gid
	end
	local terrain = tile.terrain
	if terrain then
		terrain = { terrain:match("(%d*),(%d*),(%d*),(%d*)") }
		for i = 1, 4 do
			local t = tonumber(terrain[i])
			terrain[i] = t and (t + 1) or false
		end
		tile.terrain = terrain
	end
	return tile
end

function load.tileoffset(tileoffset, parent, dir)
	parent.tileoffsetx = tileoffset.x
	parent.tileoffsety = tileoffset.y
end

function load.grid(grid, parent, dir)
	parent.gridwidth = grid.width
	parent.gridheight = grid.height
	parent.gridorientation = grid.orientation
end

function load.image(image, parent, dir)
	local file = dir..image.source
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

local Tileset = {}
Tileset.__index = Tileset

function Tileset.areGidsInRange(tileset, mingid, maxgid)
	local firstgid = tileset.firstgid
	local tilecount = tileset.tilecount
	return firstgid <= mingid and maxgid < firstgid + tilecount
end

function load.tileset(tileset, parent, dir)
	setmetatable(tileset, Tileset)

	local source = tileset.source
	if source then
		local file = dir..source
		local exttileset = loaded[file]
		if not exttileset then
			exttileset = Tiled.load(file)
			loaded[file] = exttileset
		end
		tablex.update(tileset, exttileset)
	else
		local tilecount = tileset.tilecount or 0
		local columns = tileset.columns or 0
		local rows = floor(tilecount/columns)
		local tilewidth = tileset.tilewidth
		local tileheight = tileset.tileheight
		local image = tileset.image
		local imagewidth = image:getWidth()
		local imageheight = image:getHeight()
		for i = #tileset, 1, -1 do
			local tile = tileset[i]
			local tileid = tile.id + 1
			tile.id = tileid
			if tileid ~= i then
				tileset[tileid] = tile
				tileset[i] = nil
			end
		end
		local i, x, y = 1, 0, 0
		for r = 1, rows do
			for c = 1, columns do
				local tile = tileset[i] or {}
				tileset[i] = tile
				tile.id = i
				tile.tileset = tileset
				tile.quad = LG.newQuad(x, y, tilewidth, tileheight,
					imagewidth, imageheight)
				x = x + tilewidth
				i = i + 1
			end
			x = 0
			y = y + tileheight
		end

		for t = 1, #tileset do
			local tile = tileset[t]
			local animation = tile.animation
			if animation then
				local duration = 0
				for i = 1, #animation do
					local frame = animation[i]
					local tileid = frame.tileid + 1
					frame.tileid = tileid
					duration = duration + frame.duration
				end
				animation.duration = duration
			end
		end
	end

	if parent then
		if parent.tag == "map" then
			local tilesets = parent.tilesets or {}
			parent.tilesets = tilesets
			tilesets[#tilesets + 1] = tileset

			local tiles = parent.tiles or {}
			parent.tiles = tiles
			for i = 1, #tileset do
				local tile = tileset[i]
				tiles[#tiles + 1] = tile
			end
		elseif parent.tag == "template" then
			parent.tileset = tileset
		end
		return
	end

	return tileset
end

local function decode(output, datastring, encoding, compression)
	if encoding == "base64" then
		datastring = LD.decode("data", encoding, datastring)
	end
	if compression then
		datastring = LD.decompress("data", compression, datastring)
	end
	local pointer = ffi.cast("uint32_t*", datastring:getFFIPointer())
	local n = floor(datastring:getSize() / ffi.sizeof("uint32_t"))
	local mingid = huge
	local maxgid = 0
	for i = 0, n-1 do
		local gid = pointer[i]
		output[#output + 1] = gid
		if gid ~= 0 then
			mingid = min(gid, mingid)
			maxgid = max(gid, maxgid)
		end
	end
	output.mingid = mingid
	output.maxgid = maxgid
end

function load.chunk(chunk, data, dir)
	local datastring = chunk[1]
	chunk[1] = nil
	decode(chunk, datastring, data.encoding, data.compression)
	return chunk
end

function load.data(data, layer, dir)
	local datastring = data[1]
	if type(datastring) == "string" then
		decode(layer, datastring, data.encoding, data.compression)
		return layer[1]
	else
		layer.chunks = data
	end
end

function load.layer(layer, map, dir)
	local chunks = layer.chunks
	if chunks then
		for i = 1, #chunks do
			local chunk = chunks[i]
			layer[#layer + 1] = chunk
			load.layer(chunk, map, dir)
		end
		layer.chunks = nil
		return layer
	end

	local tiles = map.tiles
	local tileanimations = map.tileanimations or {}
	map.tileanimations = tileanimations

	local tileanimationframes = {}
	layer.tileanimationframes = tileanimationframes
	local tileset
	for i = 1, #layer do
		local gid = layer[i]
		local tile = tiles[gid]
		local animation = tile and tile.animation
		if animation then
			tileanimationframes[i] = 1
			tileanimations[gid] = animation
		end
	end

	local mingid = layer.mingid
	local maxgid = layer.maxgid
	local tileset
	local tilesets = map.tilesets
	for i = 1, #tilesets do
		local ts = tilesets[i]
		if Tileset.areGidsInRange(ts, mingid, maxgid) then
			tileset = ts
			break
		end
	end
	if not tileset then
		return layer
	end
	local tileoffsetx = tileset.tileoffsetx or 0
	local tileoffsety = tileset.tileoffsety or 0
	local tilewidth = tileset.tilewidth
	local tileheight = tileset.tileheight
	local width = layer.width
	local height = layer.height
	local maptilewidth = map.tilewidth
	local maptileheight = map.tileheight
	local spritebatchusage = layer.spritebatchusage or "dynamic"
	local spritebatch = LG.newSpriteBatch(tileset.image,
		width * height, spritebatchusage)
	local i, x, y = 1, 0, 0
	for r = 1, height do
		for c = 1, width do
			local gid = layer[i]
			local tile = tiles[gid]
			if tile then
				local animation = tile.animation
				if animation then
					tile = tileset[animation[1].tileid]
				end

				spritebatch:add(tile.quad, x, y, 0, 1, 1,
					-tileoffsetx,
					tileheight-tileoffsety)
			else
				spritebatch:add(0, 0, 0, 0, 0)
			end
			i = i + 1
			x = x + maptilewidth
		end
		x = 0
		y = y + maptileheight
	end
	layer.spritebatch = spritebatch
	return layer
end

function Map.setObjectGid(map, object, gid)
	local tiles = map.tiles
	local template = object.template
	if template then
		gid = gid or template.gid
		tiles = template.tileset
	end
	local tile = tiles and tiles[gid]
	local animationframe, animationmsecs
	if tile then
		local animation = tile.animation
		if animation then
			object.animationmsecs = 0
			object.animationframe = 1
		end
	end
	object.gid = gid
end

function Map.changeObjectGid(map, object, gid)
	if object.gid ~= gid then
		Map.setObjectGid(map, object, gid)
	end
end

function Map.setLayerGid(map, layer, c, r, gid)
	if type(layer[1]) ~= "number" then
		-- TODO: find chunk and change its tile
	end

	local width = layer.width
	local i = 1 + c + width*r
	layer[i] = gid

	local tiles = map.tiles
	local tile = tiles[gid]
	local animation = tile and tile.animation
	map.tileanimations[gid] = animation
	local f = animation and animation.globalframe
	if f then
		layer.tileanimationframes[i] = f
		tile = animation[f].tile
	end

	local tileset = layer.tileset
	local mingid = layer.mingid
	local maxgid = layer.maxgid
	if gid < mingid then
		mingid = gid
		layer.mingid = mingid
	end
	if mingid > maxgid then
		maxgid = gid
		layer.maxgid = maxgid
	end
	if not tileset:areGidsInRange(mingid, maxgid) then
		layer.spritebatch = nil
	end

	local spritebatch = layer.spritebatch
	if not spritebatch then
		return
	end

	local maptilewidth = map.tilewidth
	local maptileheight = map.tileheight
	local x, y = x*maptilewidth, y*maptileheight
	Map.setSpriteBatchTile(map, spritebatch, i, x, y, tile)
end

function Map.setSpriteBatchTile(map, spritebatch, i, x, y, tile)
	if tile then
		local tileset = tile.tileset
		local tileoffsetx = tileset.tileoffsetx or 0
		local tileoffsety = tileset.tileoffsety or 0
		local tileheight = tileset.tileheight
		spritebatch:set(i, tile.quad, x, y, 0, 1, 1,
			-tileoffsetx, tileheight-tileoffsety)
	else
		spritebatch:set(i, 0, 0, 0, 0, 0)
	end
end

function load.map(map, _, dir)
	tablex.update(map, Map)
	return map
end

local function loadRecursive(doc, parent, dir)
	if type(doc) == "string" then
		return doc
	end
	local node = doc.attr
	tablex.transform(function(v)
		local number = tonumber(v)
		if number then
			return number
		elseif v == "" then
			return nil
		elseif v == "false" then
			return false
		elseif v == "true" then
			return true
		end
		return v
	end, node)
	local tag = doc.tag
	node.tag = tag
	if node.visible == 0 then
		node.visible = false
	end
	local n = #doc
	for i = 1, n do
		node[#node + 1] = loadRecursive(doc[i], node, dir)
	end
	node = load[tag](node, parent, dir)
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

function Tiled.clearCache()
	loaded = {}
end

setmetatable(Tiled, {
	__call = function(Tiled, file)
		return Tiled.load(file)
	end
})

return Tiled
