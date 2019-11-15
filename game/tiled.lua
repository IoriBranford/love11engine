local pretty = require "pl.pretty"
local xml = require "pl.xml"
local tablex = require "pl.tablex"
local ffi = require "ffi"
local floor = math.floor
local love = love
local LD = love.data
local LFS = love.filesystem
local LG = love.graphics

local function dirname(fullpath)
	return fullpath:match'(.*/)[^/]*$'
end

local Tiled = {}

local Parsers = {}

local loaded = {}

function Parsers.properties(doc)
	return doc:match([[
<properties>
	{{<property name='$_' type='$type' value='$value'/>}}
</properties>
	]])
end

function Parsers.text(doc)
	return doc:match([[
<text fontfamily='$fontfamily' pixelsize='$pixelsize' wrap='$wrap'
color='$color' bold='$bold' italic='$italic' underline='$underline'
strikeout='$strikeout' kerning='$kerning' halign='$halign'
valign='$valign'>$text</text>
	]])
end

function parseChildren(tbl, doc, insert)
	insert = insert or function(tbl, tag, parsed)
		tbl[tag] = parsed
	end
	for child in doc:childtags() do
		local tag = child.tag
		local parser = Parsers[tag]
		local childtbl
		if parser then
			parsed = parser(child)
		end
		insert(tbl, tag, parsed)
	end
end

function Parsers.object(doc)
	local object = doc:match([[
<object id='$id' name='$name' type='$type' x='$x' y='$y'
width='$width' height='$height' rotation='$rotation' gid='$gid'
visible='$visible' template='$template'/>
	]])

	parseChildren(object, doc, function(object, tag, parsed)
		if parsed then
			object[tag] = parsed
		elseif tag == "ellipse" then
			object.ellipse = true
		elseif tag == "point" then
			object.point = true
		elseif tag == "polygon" then
			object.polygon = child.attr.points
		elseif tag == "polyline" then
			object.polyline = child.attr.points
		end
	end)

	return object
end

function Parsers.objectgroup(doc)
	local objectgroup = doc:match([[
<objectgroup id='$id' name='$name' color='$color' x='$x' y='$y' width='$width'
height='$height' opacity='$opacity' visible='$visible' offsetx='$offsetx'
offsety='$offsety' draworder='$draworder'/>
]])
	parseChildren(objectgroup, doc, function(objectgroup, tag, parsed)
		if parsed then
			if tag == "object" then
				objectgroup[#objectgroup+1] = parsed
			else
				objectgroup[tag] = parsed
			end
		end
	end)
	return objectgroup
end

function Parsers.image(doc)
	return doc:match([[
<image format='$format' id='$id' source='$source'
trans='$trans' width='$width' height='$height'/>
]])
end

function Parsers.animation(doc)
	return doc:match([[
	<animation>
		{{<frame tileid='$tileid' duration='$duration'/>}}
	</animation>
	]])
end

function Parsers.tile(doc)
	local tile = doc:match([[
<tile id='$id' type='$type' terrain='$terrain' probability='$probability'/>
	]])
	parseChildren(tile, doc)
	return tile
end
		-- ]]..Properties..[[
-- ]]..Properties..Image..ObjectGroup..[[

--function Parsers.terrain(doc)
--	local terrain = doc:match([[ <terrain name='$name' tile='$tile'/> ]])
--	parse_children(terrain, doc)
--	return terrain
--end
--
--function Parsers.terraintypes(doc)
--	local terraintypes = doc:match[[
--<terraintypes>
--	{{<terrain name='$name' tile='$tile'/>}}
--</terraintypes>
--	]]
--	parse_children(terraintypes, doc)
--	return terraintypes
--end
-- ]]..Properties..[[

function Parsers.tileset(doc)
	local tileset = doc:match[[
<tileset firstgid='$firstgid' source='$source' name='$name'
tilewidth='$tilewidth' tileheight='$tileheight' spacing='$spacing'
margin='$margin' tilecount='$tilecount' columns='$columns'/>
	]]

	parseChildren(tileset, doc, function(tileset, tag, parsed)
		if parsed then
			if tag == "tile" then
				tileset[#tileset + 1] = parsed
			else
				tileset[tag] = parsed
			end
		elseif tag == "tileoffset" then
			tileset.tileoffsetx = child.attr.x
			tileset.tileoffsety = child.attr.y
		elseif tag == "grid" then
			tileset.gridorient = child.attr.orientation
			tileset.gridwidth = child.attr.width
			tileset.gridheight = child.attr.height
		end
	end)
	return tileset
end

function Parsers.layer(doc)
	local layer = doc:match([[
<layer id='$id' name='$name' x='$x' y='$y' width='$width' height='$height'
opacity='$opacity' visible='$visible' offsetx='$offsetx' offsety='$offsety'/>
	]])
	parseChildren(layer, doc)
	return layer
end

local function decodeData(gids, data, encoding, compression)
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
	return gids
end

function Parsers.chunk(doc)
	return doc:match([[
<chunk x='$x' y='$y' width='$width' height='$height'>$data</chunk>
	]])
end

function Parsers.data(doc)
	local data = doc:match([[
<data encoding='$encoding' compression='$compression'>$data</data>
	]])
	local encoding = data.encoding
	local compression = data.compression
	parseChildren(data, doc, function(data, tag, parsed)
		if parsed then
			if tag == "chunk" then
				data[#data + 1] = parsed
				decodeData(parsed, parsed.data,
					encoding, compression)
				parsed.data = nil
			else
				data[tag] = parsed
			end
		end
	end)
	decodeData(data, data.data, encoding, compression)
	data.data = nil
	return data
end

function Parsers.imagelayer(doc)
	local layer = doc:match([[
<imagelayer id='$id' name='$name' offsetx='$offsetx' offsety='$offsety'
x='$x' y='$y' opacity='$opacity' visible='$visible'/>
	]])
	parseChildren(layer, doc)
	return layer
end

function Parsers.group()
	local group = doc:match([[
<group id='$id' name='$name' offsetx='$offsetx' offsety='$offsety'
opacity='$opacity' visible='$visible'/>
	]])
	parseChildren(group, doc, function(group, tag, parsed)
		if parsed then
			if tag == "layer"
			or tag == "objectgroup"
			or tag == "imagelayer"
			or tag == "group"
			then
				map[#map + 1] = parsed
			else
				map[tag] = parsed
			end
		end
	end)
	return group
end

function Parsers.map(doc)
	local map = doc:match([[
<map version='$version' tiledversion='$tiledversion' orientation='$orientation'
renderorder='$renderorder' width='$width' height='$height'
tilewidth='$tilewidth' tileheight='$tileheight' hexsidelength='$hexsidelength'
staggeraxis='$staggeraxis' staggerindex='$staggerindex'
backgroundcolor='$backgroundcolor' nextlayerid='$nextlayerid'
nextobjectid='$nextobjectid'/>
	]])

	local tilesets = {}
	map.tilesets = tilesets
	parseChildren(map, doc, function(map, tag, parsed)
		if parsed then
			if tag == "layer"
			or tag == "objectgroup"
			or tag == "imagelayer"
			or tag == "group"
			then
				map[#map + 1] = parsed
			elseif tag == "tileset" then
				tilesets[#tilesets + 1] = parsed
			else
				map[tag] = parsed
			end
		end
	end)
	return map
end

function Parsers.objecttypes(doc)
	local objecttypes = doc:match([[
<objecttypes>
{{<objecttype name="$_">
{{<property name="$_" type="$type" default="$default"/>}}
 </objecttype>}}
</objecttypes>
	]])
	for tname, properties in pairs(objecttypes) do
		for pname, property in pairs(properties) do
			properties[pname] = property.default
		end
	end
	return objecttypes
end

local function parseValue(key, value, dir)
	local number = tonumber(value)
	if number then
		return number
	elseif value == "" then
		return nil
	elseif value == "false" then
		return false
	elseif value == "true" then
		return true
	end

	if type(value)=="table" then
		if key == "image" then
			local file = dir..value.source
			return loaded[file] or (LFS.getInfo(file) and LG.newImage(file))
		end

		local properties = value.properties
		if properties then
			for k, v in pairs(properties) do
				value[k] = parseValue(k, v.value, dir)
			end
		end
		value.properties = nil

		for k, v in pairs(value) do
			value[k] = parseValue(k, v, dir)
		end

		if not next(value) then
			return nil
		end
	end
	return value
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

	local dir = dirname(file) or ""
	local parser = Parsers[doc.tag]
	local tbl = parser and parser(doc)

	local tilesets = tbl.tilesets
	if tilesets then
		for i = 1, #tilesets do
			local exttileset = tilesets[i]
			local source = exttileset.source
			if source then
				local tsxfile = dir..source
				local tileset = Tiled.load(tsxfile)
				if tileset then
					tablex.update(exttileset, tileset)
				end
			end
		end
	end

	return parseValue(doc.tag, tbl, dir)
end

function Tiled.unload()
	loaded = {}
end

return Tiled
