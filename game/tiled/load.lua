-- TODO:
-- wangsets
-- iso, hex, staggered orientation

local assets = require "assets"
local pretty = require "pl.pretty"
local tablex = require "pl.tablex"
local ffi = require "ffi"
local floor = math.floor
local max = math.max
local min = math.min
local rad = math.rad
local huge = math.huge
local type = type
local pairs = pairs
local tonumber = tonumber
local love = love
local LD = love.data
local LG = love.graphics
local LM = love.math

local Map = require "tiled.map"
local Object = require "tiled.object"

local load = {}
setmetatable(load, {
	__index = function()
		return function(node)
			return node
		end
	end
})

local function parseColor(colorstring)
	local a, r, g, b
	if #colorstring == 9 then
		a, r, g, b = colorstring:match("#(..)(..)(..)(..)")
	elseif #colorstring == 7 then
		r, g, b = colorstring:match("#(..)(..)(..)")
	end
	return  (1+tonumber(r, 16))/256,
		(1+tonumber(g, 16))/256,
		(1+tonumber(b, 16))/256,
		a and (1+tonumber(a, 16))/256
end

---
-- Before:
-- <PARENT>
--  <properties>
--   <property name="NAME1" type="TYPE1" value="VALUE1"/>
--   <property name="NAME2" type="TYPE2" value="VALUE2"/>
--   ...
--  </properties>
-- </PARENT>
--
-- After:
-- {
--  tag = PARENT,
--  NAME1 = "VALUE1",
--  NAME2 = "VALUE2",
--  ...
-- }
function load.properties(properties, parent, dir)
	for i = #properties, 1, -1 do
		local property = properties[i]
		local value = property.value or property.default
		if value then
			local ptype = property.type
			local pname = property.name
			if ptype == "file" then
				value = dir..value
			elseif ptype == "color" then
				value = { parseColor(value) }
			end
			parent[pname] = value
		end
		properties[i] = nil
	end
end

---
-- Before:
--  <objecttype>
--   <property name="NAME1" type="TYPE1" default="VALUE1"/>
--   <property name="NAME2" type="TYPE2" default="VALUE2"/>
--   ...
--  </objecttype>
--
-- After:
-- {
--  tag = objecttype,
--  NAME1 = "VALUE1",
--  NAME2 = "VALUE2",
--  ...
-- }
function load.objecttype(objecttype, objecttypes, dir)
	load.properties(objecttype, objecttype, dir)
	objecttypes[objecttype.name] = objecttype
	objecttype.name = nil
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

---
-- Before:
-- <object>
--  <polygon points="1,2 3,4"\>
-- </object>
--
-- After:
-- {
--  tag = "object",
--  polygon = { 1, 2, 3, 4 }
-- }
function load.polygon(polygon, object, dir)
	object.polygon = parsePoints(polygon.points)
end

---
-- Before:
-- <object>
--  <polyline points="1,2 3,4"\>
-- </object>
--
-- After:
-- {
--  tag = "object",
--  polyline = { 1, 2, 3, 4 }
-- }
function load.polyline(polyline, object, dir)
	object.polyline = parsePoints(polyline.points)
end

function load.text(text, object, dir)
	text.string = text[1]
	text[1] = nil
	local fontfamily = text.fontfamily
	local pixelsize = text.pixelsize or 16
	local file = dir..fontfamily
	if text.bold then
		file = file.." Bold"
	end
	if text.italic then
		file = file.." Italic"
	end
	if text.underline then
		file = file.." Underline"
	end
	local fnt = file..pixelsize..".fnt"
	local ttf = file..".ttf"
	local font = assets.get(fnt) or assets.get(ttf, pixelsize)
		or assets.get(".defaultFont", pixelsize)
	font:setFilter("nearest", "nearest")
	text.font = font
	return text
end

function load.template(template, _, dir)
	local object = template[#template]
	local tilesets = template.tilesets
	if tilesets then
		object.tileset = tilesets[1]
	end
	return object
end

function load.object(object, parent, dir)
	setmetatable(object, Object)
	local template = object.template
	if template then
		Object.setTemplate(object, dir..template)
	end
	local aseprite = object.aseprite
	if aseprite then
		Object.setAseprite(object, aseprite,
			object.animation,
			object.anchorx,
			object.anchory)
	end
	return object
end

function load.objectgroup(objectgroup, parent, dir)
	if parent.tag == "map" then
		for i = 1, #objectgroup do
			local object = objectgroup[i]
			local gid = object.gid
			if gid then
				Map.setObjectGid(parent, object, gid)
			end
		end
	end
	return objectgroup
end

local Animation = {}
Animation.__index = Animation

function Animation.getNewFrameAndMsecs(animation, f, msecs, dmsecs)
	local duration = animation[f].duration
	while msecs >= duration do
		msecs = msecs - duration
		f = (f == #animation) and 1 or (f + 1)
		duration = animation[f].duration
	end
	return f, msecs + dmsecs
end

function Animation.animateTile(animation, animatedtile, f, msecs, dmsecs)
	f, msecs = animation:getNewFrameAndMsecs(f, msecs, dmsecs)
	local tileset = animatedtile.tileset
	return tileset:getAnimationFrameTile(animatedtile, f), f, msecs
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

function load.tileoffset(tileoffset, tileset, dir)
	tileset.tileoffsetx = -tileoffset.x
	tileset.tileoffsety = tileset.tileheight-tileoffset.y
end

function load.grid(grid, parent, dir)
	parent.gridwidth = grid.width
	parent.gridheight = grid.height
	parent.gridorientation = grid.orientation
end

function load.image(image, parent, dir)
	local file = dir..image.source
	local image = assets.get(file)
	if image then
		image:setFilter("nearest", "nearest")
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

function Tileset.getAnimationFrameTile(tileset, animatedtile, f)
	local animation = animatedtile.animation
	return animation and tileset[animation[f].tileid] or animatedtile
end

function load.tileset(tileset, parent, dir)
	setmetatable(tileset, Tileset)

	local source = tileset.source
	if source then
		local file = dir..source
		local exttileset = assets.get(file)
		tablex.update(tileset, exttileset)
	else
		local tilecount = tileset.tilecount or 0
		local columns = tileset.columns or 0
		local rows = floor(tilecount/columns)
		local tilewidth = tileset.tilewidth
		local tileheight = tileset.tileheight
		tileset.tileoffsetx = tileset.tileoffsetx or 0
		tileset.tileoffsety = tileset.tileoffsety or tileheight
		local imagewidth = tilewidth
		local imageheight = tileheight
		local image = tileset.image
		if image then
			imagewidth = image:getWidth()
			imageheight = image:getHeight()
		end
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
				tile.quad = image and LG.newQuad(x, y,
					tilewidth, tileheight,
					imagewidth, imageheight)
				x = x + tilewidth
				i = i + 1
			end
			x = 0
			y = y + tileheight
		end

		local namedtileids = {}
		tileset.namedtileids = namedtileids
		for t = 1, #tileset do
			local tile = tileset[t]
			local tilename = tile.tilename
			if tilename then
				namedtileids[tilename] = t
			end
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

	if type(parent) == "table" then
		local tilesets = parent.tilesets or {}
		parent.tilesets = tilesets
		tilesets[#tilesets + 1] = tileset
		tilesets[tileset.name] = tileset

		local tiles = parent.tiles or {}
		parent.tiles = tiles
		for i = 1, #tileset do
			local tile = tileset[i]
			tiles[#tiles + 1] = tile
		end
		return
	end

	return tileset
end

local function decode_csv(output, datastring)
	local mingid = huge
	local maxgid = 0
	for gid in datastring:gmatch("%d+") do
		output[#output+1] = tonumber(gid)
		if gid ~= 0 then
			mingid = min(gid, mingid)
			maxgid = max(gid, maxgid)
		end
	end
	output.mingid = mingid
	output.maxgid = maxgid
end

local function decode(output, datastring, encoding, compression)
	if encoding == "csv" then
		decode_csv(output, datastring)
		return
	elseif encoding == "base64" then
		datastring = LD.decode("data", encoding, datastring)
		if compression then
			datastring = LD.decompress("data", compression,
							datastring)
		end
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
	return output
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

---
-- Before:
--
-- <layer>
--  <data encoding=ENCODING compression=COMPRESSION>
--   DATA STRING
--  </data>
-- </layer>
--
-- After:
-- {
--  tag = "layer",
--  [1],[2]... = DATA,
--  mingid,
--  maxgid,
--  spritebatch
-- }

local function addLayerTileSprite(layer, i, tile, x, y, sx, sy, r, spritebatch)
	if tile then
		local animation = tile.animation
		local tileset = tile.tileset
		if animation then
			tile = tileset:getAnimationFrameTile(tile, 1)
		end

		local tileoffsetx = tileset.tileoffsetx
		local tileoffsety = tileset.tileoffsety
		spritebatch:add(tile.quad, x, y, r, sx, sy,
			tileoffsetx, tileoffsety)
	else
		spritebatch:add(0, 0, 0, 0, 0)
	end
end

function load.layer(layer, map, dir)
	local chunks = layer.chunks
	local maptilewidth = map.tilewidth
	local maptileheight = map.tileheight
	local maptilescale = map.tilescale
		or LM.newTransform(0, 0, 0, maptilewidth, maptileheight)
	map.tilescale = maptilescale
	if chunks then
		for i = 1, #chunks do
			local chunk = chunks[i]
			layer[#layer + 1] = chunk
			load.layer(chunk, map, dir)
			chunk.x = chunk.x*maptilewidth
			chunk.y = chunk.y*maptileheight
		end
		layer.chunks = nil
		return layer
	end

	local tiles = map.tiles or {}
	map.tiles = tiles
	local layertileanimations = map.layertileanimations or {}
	map.layertileanimations = layertileanimations

	local tileanimationframes = {}
	layer.tileanimationframes = tileanimationframes
	local getGidFlip = Map.getGidFlip
	for i = 1, #layer do
		local gid = getGidFlip(layer[i])
		local tile = tiles[gid]
		local animation = tile and tile.animation
		if animation then
			tileanimationframes[i] = 1
			layertileanimations[gid] = animation
		end
	end

	local mingid = layer.mingid
	local maxgid = layer.maxgid
	local tileset
	local tilesets = map.tilesets or {}
	map.tilesets = tilesets
	for i = 1, #tilesets do
		local ts = tilesets[i]
		if Tileset.areGidsInRange(ts, mingid, maxgid) then
			tileset = ts
			break
		end
	end
	if not tileset or not tileset.image then
		return layer
	end
	local width = layer.width
	local height = layer.height
	local spritebatchusage = layer.spritebatchusage or "dynamic"
	local spritebatch = LG.newSpriteBatch(tileset.image,
		width * height, spritebatchusage)
	layer.spritebatch = spritebatch
	Map.forEachLayerTile(map, layer, addLayerTileSprite, spritebatch)
	return layer
end

function load.map(map, filename, dir)
	tablex.update(map, Map)
	map.tiles = map.tiles or {}
	map.tilesets = map.tilesets or {}
	map.layertileanimations = map.layertileanimations or {}
	local backgroundcolor = map.backgroundcolor
	map.backgroundcolor = backgroundcolor and { parseColor(backgroundcolor) }
	map:initObjectManagement()
	return map
end

function load.editorsettings(editorsettings, map, dir)
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
	if not dir then
		dir = parent:match('(.*/)[^/]*$') or ""
		node.filename = parent
	end
	if type(parent) == "table" then
		node.parent = parent
	end
	local n = #doc
	for i = 1, n do
		node[#node + 1] = loadRecursive(doc[i], node, dir)
	end
	node = load[tag](node, parent, dir)

	if type(node) == "table" then
		-- layer types use offsetx/offsety, anything else uses x/y
		local x = node.offsetx or node.x
		local y = node.offsety or node.y
		local rotation = rad(node.rotation or 0)
		node.offsetx = nil
		node.offsety = nil
		node.x = x
		node.y = y
		node.rotation = rotation
	end
	return node
end

return loadRecursive
