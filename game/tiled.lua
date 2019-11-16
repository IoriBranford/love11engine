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
		local parsed = parser and parser(child)-- or child
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
		if tag == "ellipse" then
			object.ellipse = true
		elseif tag == "point" then
			object.point = true
		elseif tag == "polygon" then
			object.polygon = child.attr.points
		elseif tag == "polyline" then
			object.polyline = child.attr.points
		elseif parsed then
			object[tag] = parsed
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
margin='$margin' tilecount='$tilecount' columns='$columns'>
	<tileoffset x='$tileoffsetx' y='$tileoffsety'/>
	<grid orientation='$gridorient' width='$gridwidth' height='$gridheight'/>
</tileset>
	]]

	parseChildren(tileset, doc, function(tileset, tag, parsed)
		if tag == "tile" then
			local tileid = tonumber(parsed.id) or parsed.id
			tileset[tileid] = parsed
		else
			tileset[tag] = parsed
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

function Parsers.chunk(doc)
	return doc:match([[
<chunk x='$x' y='$y' width='$width' height='$height'>$data</chunk>
	]])
end

function Parsers.data(doc)
	local data = doc:match([[
<data encoding='$encoding' compression='$compression'/>
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
	local datadata = doc:match("<data>$1</data>")
	datadata = datadata and datadata[1]
	decodeData(data, datadata, encoding, compression)
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

function Parsers.group(doc)
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
				group[#group + 1] = parsed
			else
				group[tag] = parsed
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
	tbl = parseValue(doc.tag, tbl, dir)

	local tilesets = tbl.tilesets
	if tilesets then
		local tiles = {}
		tbl.tiles = tiles
		for i = 1, #tilesets do
			local tileset = tilesets[i]
			local source = tileset.source
			if source then
				local tsxfile = dir..source
				local exttileset = Tiled.load(tsxfile)
				if exttileset then
					tablex.update(tileset, exttileset)
				end
			end
			local image = tileset.image
			image:setFilter("nearest", "nearest")
			local imagewidth = 0
			local imageheight = 0
			if image then
				imagewidth = image:getWidth()
				imageheight = image:getHeight()
			end
			local tilecount = tileset.tilecount or 0
			local columns = tileset.columns or 0
			local rows = floor(tilecount/columns)
			local i, x, y = 0, 0, 0
			local gid = tileset.firstgid
			local tilewidth = tileset.tilewidth
			local tileheight = tileset.tileheight
			for r = 1, rows do
				for c = 1, columns do
					local tile = tileset[i] or {}
					tiles[gid] = tile
					tile.tileset = tileset
					tile.gid = gid
					tile.quad = LG.newQuad(x, y,
						tilewidth, tileheight,
						imagewidth, imageheight)
					x = x + tilewidth
					i = i + 1
					gid = gid + 1
				end
				x = 0
				y = y + tileheight
			end
		end
	end

	return tbl
end

local function draw(elem, mapelem)
	if elem.visible == false then
		return
	end

	local x = elem.x or 0
	local y = elem.y or 0
	local offsetx = elem.offsetx or 0
	local offsety = elem.offsety or 0
	local width = elem.width
	local height = elem.height
	local rotation = elem.rotation or 0
	local scalex, scaley = 1, 1
	local tilewidth
	local tileheight

	local gid = elem.gid
	local tile
	local tileset

	mapelem = mapelem or elem
	local tiles = mapelem.tiles

	if gid then
		tile = tiles[gid]
	end

	if tile then
		tileset = tile.tileset
		tilewidth = tileset.tilewidth
		tileheight = tileset.tileheight
		if width ~= tilewidth or height ~= tileheight then
			scalex = width / tilewidth
			scaley = height / tileheight
		end
	end

	LG.push("transform")
	LG.translate(x + offsetx, y + offsety)
	LG.rotate(rad(rotation))
	LG.scale(scalex, scaley)

	local data = elem.data

	if data then
		local maptilewidth = mapelem.tilewidth
		local maptileheight = mapelem.tileheight
		local i = 1
		local x, y = 0, 0
		for r = 1, height do
			for c = 1, width do
				local tile = tiles[data[i]]
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

	if tile then
		local tileoffsetx = tileset.tileoffsetx or 0
		local tileoffsety = tileset.tileoffsety or 0

		LG.draw(tileset.image, tile.quad, 0, 0, 0, 1, 1,
			-tileoffsetx, tileheight - tileoffsety)
	end

	for i = 1, #elem do
		draw(elem[i], mapelem)
	end

	LG.pop()
end
Tiled.draw = draw

function Tiled.unload()
	loaded = {}
end

return Tiled
