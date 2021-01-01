local assets = require "assets"
local ffi = require "ffi"

local tiled = {
	tileset = {},
	map = {},
	tilelayer = {},
	group = {},
	objectgroup = {},
}

local function parsergb(rgb)
	if not rgb then return end
	local r, g, b = rgb:match("#(..)(..)(..)")
	r = (tonumber(r,16)+1)/256
	g = (tonumber(g,16)+1)/256
	b = (tonumber(b,16)+1)/256
	return r,g,b
end

local function loadelement(e, cwd, root)
	if not e then return end
	local t = e.type
	if t then
		local mt = tiled[t]
		if type(mt) == "table" then
			for k,v in pairs(mt) do
				e[k] = v
			end
		end
		local load = tiled["load"..t]
		if type(load) == "function" then
			load(e, cwd, root)
		end
	end
	return e
end
tiled.loadelement = loadelement

local function drawlayers(self)
	local layers = self.layers
	for i = 1, #layers do
		local layer = layers[i]
		if layer.draw and layer.visible then
			layer:draw()
		end
	end
end

local function drawobjects(self)
	local objects = self.objects
	for i = 1, #objects do
		local object = objects[i]
		if object.draw and object.visible then
			object:draw(self)
		end
	end
end

tiled.map.draw = drawlayers
tiled.group.draw = drawlayers
tiled.objectgroup.draw = drawobjects

local function unflip(gid)
	local h, v = 1,1
	if gid > 0x080000000 then
		h = -h
		gid = gid - 0x080000000
	end
	if gid > 0x040000000 then
		v = -v
		gid = gid - 0x040000000
	end
	return gid, h, v
end

local function flip(gid, h, v)
	if h < 0 then
		gid = gid + 0x080000000
	end
	if v < 0 then
		gid = gid + 0x040000000
	end
	return gid
end

local function drawobjecttile(object)
	local tile = object.tile
	love.graphics.draw(tile.image, tile.quad, object.x, object.y,
		object.rotation, object.scalex, object.scaley,
		tile.objectoriginx, tile.objectoriginy)
end

local function drawlayertiles(tilelayer, c1, r1, cols, rows, data)
	local map = tilelayer.map
	local tiles = map.tileset
	local cellwidth = map.cellwidth
	local cellheight = map.cellheight
	local i = 1
	local y = (r1+1) * cellheight
	for r = 1, rows do
		local x = c1 * cellwidth
		for c = 1, cols do
			local gid, h, v = unflip(data[i])
			local tile = tiles[gid]
			if tile then
				local image = tile.image
				local quad = tile.quad
				love.graphics.draw(tile.image, tile.quad,
					x + tile.layeroffsetx,
					y + tile.layeroffsety,
					0, h, v,
					tile.layeroriginx,
					tile.layeroriginy)
			end
			i = i + 1
			x = x + cellwidth
		end
		y = y + cellheight
	end
end

function tiled.tilelayer:draw()
	local chunks = self.chunks
	if chunks then
		for i = 1, #chunks do
			local chunk = chunks[i]
			drawlayertiles(self, chunk.x, chunk.y, chunk.width, chunk.height, chunk.data)
		end
	else
		drawlayertiles(self, 0, 0, self.width, self.height, self.data)
	end
end

local function batchtiles(tilelayer, c1, r1, cols, rows, data)
	local batch = tilelayer.spritebatch
	local map = tilelayer.map
	local tiles = map.tileset
	local cellwidth = map.cellwidth
	local cellheight = map.cellheight
	--TODO
end

function drawlayerspritebatch(layer)
	love.graphics.draw(layer.spritebatch)
end

function tiled.tilelayer:makebatch(image)
	local tilecount = self.width*self.height
	local batch = love.graphics.newSpriteBatch(image, tilecount)
	for i = 1, tilecount do
		batch:add(0, 0, 0, 0, 0)
	end

	local chunks = self.chunks
	if chunks then
		for i = 1, #chunks do
			local chunk = chunks[i]
			batchtiles(self, chunk.x, chunk.y, chunk.width, chunk.height, chunk.data)
		end
	else
		batchtiles(self, 0, 0, self.width, self.height, self.data)
	end
	tilelayer.spritebatch = batch
	tilelayer.draw = drawlayerspritebatch
end

local function decode_csv(output, datastring)
	local mingid = math.huge
	local maxgid = 0
	for gid in datastring:gmatch("%d+") do
		output[#output+1] = tonumber(gid)
		if gid ~= 0 then
			mingid = math.min(gid, mingid)
			maxgid = math.max(gid, maxgid)
		end
	end
	output.mingid = mingid
	output.maxgid = maxgid
	return output
end

local function decode(output, datastring, encoding, compression)
	if encoding == "csv" then
		return decode_csv(output, datastring)
	elseif encoding == "base64" then
		datastring = love.data.decode("data", encoding, datastring)
		if compression then
			datastring = love.data.decompress("data", compression,
							datastring)
		end
	end
	local pointer = ffi.cast("uint32_t*", datastring:getFFIPointer())
	local n = math.floor(datastring:getSize() / ffi.sizeof("uint32_t"))
	local mingid = math.huge
	local maxgid = 0
	for i = 0, n-1 do
		local gid = pointer[i]
		output[#output + 1] = gid
		if gid ~= 0 then
			mingid = math.min(gid, mingid)
			maxgid = math.max(gid, maxgid)
		end
	end
	output.mingid = mingid
	output.maxgid = maxgid
	return output
end

local function loadproperties(properties, cwd)
	if not properties then return end
	for i = #properties, 1, -1 do
		local property = properties[i]
		local name = property.name
		properties[name] = property
		properties[i] = nil
		local t = property.type
		if t == "file" then
			property.value = cwd..property.value
		end
	end
end

local function loadtext(text, cwd)
	text.color = { parsergb(text.color) }
	local fontfamily = text.fontfamily
	local pixelsize = text.pixelsize or 16
	text.pixelsize = pixelsize
	local file = cwd..fontfamily
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
	local otf = file..".otf"
	text.font = love.filesystem.getInfo(fnt) and assets.get(fnt)
		or love.filesystem.getInfo(ttf) and assets.get(ttf, pixelsize)
		or love.filesystem.getInfo(otf) and assets.get(otf, pixelsize)
		or assets.get(".defaultFont", pixelsize)
end

local function drawobjecttext(object)
	local text = object.text
	local wrap = text.wrap
	local width = object.width
	local halign = text.halign
	local valign = text.valign
	local font = text.font
	local y = 0
	local str = text.text
	if valign then
		local height = object.height
		local _, lines = font:getWrap(str, wrap and width or 1048576)
		local textheight = font:getHeight()*#lines
		y = height - textheight
		if valign == "center" then
			y = y/2
		end
	end
	love.graphics.printf(str, font, object.x, object.y + y, wrap and width, halign)
end

local function initobjectdraw(object)
	local gid = object.gid
	local text = object.text
	if gid then
		gid, object.scalex, object.scaley = unflip(gid)
		local tile = object.tileset[gid]
		object.tile = tile
		object.gid = gid
		object.scalex = object.scalex * object.width/tile.width
		object.scaley = object.scaley * object.height/tile.height
		object.draw = drawobjecttile
	elseif text then
		loadtext(text, cwd)
		object.draw = drawobjecttext
	end
end

local function initobjectfromtemplate(object, template)
	object.template = template
	template = assets.get(template)

	local templateobject = template.object
	local templateproperties = templateobject.properties
	local properties = object.properties
	if templateproperties then
		properties = properties or {}
		for k,v in pairs(templateproperties) do
			if properties[k] == nil then
				properties[k] = v
			end
		end
	end
	for k,v in pairs(templateobject) do
		if object[k] == nil then
			object[k] = v
		end
	end
	object.properties = properties
	initobjectdraw(object)
end

local function loadobject(object, cwd, root)
	loadproperties(object.properties, cwd)
	local rotation = object.rotation
	object.rotation = rotation and math.rad(rotation)
	local template = object.template
	if template then
		template = cwd..template
		initobjectfromtemplate(object, template)
	else
		object.tileset = root.tileset
		initobjectdraw(object)
	end
end

local function loadobjectgroup(objectgroup, cwd, root)
	loadproperties(objectgroup.properties, cwd)
	if root and root.type == "map" then
		objectgroup.map = root
	end
	local objects = objectgroup.objects
	for i = 1, #objects do
		local object = objects[i]
		object.group = objectgroup
		loadobject(object, cwd, root)
	end
end
tiled.loadobjectgroup = loadobjectgroup

function tiled.loadtilelayer(tilelayer, cwd, root)
	loadproperties(tilelayer.properties, cwd)
	local encoding, compression = tilelayer.encoding, tilelayer.compression

	local chunks = tilelayer.chunks
	if chunks then
		for i = 1, #chunks do
			local chunk = chunks[i]
			chunk.data = decode({}, chunk.data, encoding, compression)
		end
	else
		local data = tilelayer.data
		tilelayer.data = decode({}, data, encoding, compression)
	end

	if root and root.type == "map" then
		tilelayer.map = root
	end
end

function tiled.loadimagelayer(imagelayer, cwd)
	loadproperties(imagelayer.properties, cwd)
	imagelayer.image = cwd..imagelayer.image
	assets.get(imagelayer.image)
end

function tiled.loadgroup(group, cwd, root)
	loadproperties(group.properties, cwd)
	local layers = group.layers
	for i = 1, #layers do
		loadelement(layers[i], cwd, root)
	end
end

local alignmentorigins = {
	topleft = {0, 0},
	top = {.5, 0},
	topright = {1, 0},
	bottomleft = {0, 1},
	bottom = {.5, 1},
	bottomright = {1, 1},
	left = {0, .5},
	center = {.5, .5},
	right = {1, .5}
}

local function loadtileset(tileset, cwd)
	if not tileset then return end
	local source = tileset.source
	if source then
		source = cwd..source
		tileset.source = source
		return assets.get(source)
	end

	loadproperties(tileset.properties, cwd)
	local tilewidth = tileset.tilewidth
	local tileheight = tileset.tileheight
	local tilewidthhalf = tilewidth/2
	local tileheighthalf = tileheight/2
	local alignment = tileset.objectalignment or "bottomleft"
	alignment = alignmentorigins[alignment]
	local alignx = alignment[1]
	local aligny = alignment[2]
	local tileoffsetx = 0
	local tileoffsety = 0
	local tileoffset = tileset.tileoffset
	if tileoffset then
		tileoffsetx = tileoffset.x
		tileoffsety = tileoffset.y
	end
	local layeroffsetx = tileoffsetx + tilewidthhalf
	local layeroffsety = tileoffsety - tileheighthalf
	local objectoriginx = -tileoffsetx + alignx * tilewidth
	local objectoriginy = -tileoffsety + aligny * tileheight

	tileset.image = cwd..tileset.image
	local image = assets.get(tileset.image)
	assert(image, "Error loading tileset image "..tileset.image)
	local tiles = tileset.tiles
	if tiles then
		for i = 1, #tiles do
			local tile = tiles[i]
			tileset[tile.id+1] = tile
			loadproperties(tile.properties, cwd)
			loadelement(tile.objectgroup, cwd)
		end
	end

	local tilecount = tileset.tilecount
	local columns = tileset.columns
	local rows = math.floor(tilecount/columns)
	--TODO margin and spacing
	local i = 1
	for y = 0, (rows-1) * tileheight, tileheight do
		for x = 0, (columns-1) * tilewidth, tilewidth do
			local tile = tileset[i] or {}
			tileset[i] = tile
			tile.layeroriginx = tilewidthhalf
			tile.layeroriginy = tileheighthalf
			tile.layeroffsetx = layeroffsetx
			tile.layeroffsety = layeroffsety
			tile.objectoriginx = objectoriginx
			tile.objectoriginy = objectoriginy
			tile.width = tilewidth
			tile.height = tileheight
			tile.image = image
			tile.quad = love.graphics.newQuad(x, y, tilewidth, tileheight, image)
			i = i + 1
		end
	end
	return tileset
end
tiled.loadtileset = loadtileset

function tiled.loadtemplate(template, cwd)
	template.tileset = loadtileset(template.tileset, cwd)
	loadobject(template.object, cwd, template)
end

function tiled.loadmap(map, cwd)
	map.columns = map.width
	map.rows = map.height
	map.cellwidth = map.tilewidth
	map.cellheight = map.tileheight
	map.width = map.tilewidth * map.width
	map.height = map.tileheight * map.height
	map.backgroundcolor = { parsergb(map.backgroundcolor) }

	loadproperties(map.properties, cwd)

	local maptileset = {}
	map.tileset = maptileset
	local tilesets = map.tilesets
	for i = 1, #tilesets do
		local tileset = loadtileset(tilesets[i], cwd, map)
		tilesets[i] = tileset
		for t = 1, #tileset do
			maptileset[#maptileset+1] = tileset[t]
		end
	end
	--TODO make atlas

	local layers = map.layers
	for i = 1, #layers do
		local layer = layers[i]
		loadelement(layer, cwd, map)
	end
end

return tiled
