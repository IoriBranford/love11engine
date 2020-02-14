local pi = math.pi
local pairs = pairs
local assets = require "assets"
local Object = require "tiled.object"

local Map = {}

local Staggers = {
	x = {
		odd = {
			x = 0, y = 0,
			cdx = .5, cdy = .5,
			rdx = 0, rdy = 1,
			scalecdx = 1, scalecdy = -1,
			scalerdx = 1, scalerdy = 1
		},
		even = {
			x = 0, y = .5,
			cdx = .5, cdy = -.5,
			rdx = 0, rdy = 1,
			scalecdx = 1, scalecdy = -1,
			scalerdx = 1, scalerdy = 1
		}
	},
	y = {
		odd = {
			x = 0, y = 0,
			cdx = 1, cdy = 0,
			rdx = .5, rdy = .5,
			scalecdx = 1, scalecdy = 1,
			scalerdx = -1, scalerdy = 1
		},
		even = {
			x = .5, y = 0,
			cdx = 1, cdy = 0,
			rdx = -.5, rdy = .5,
			scalecdx = 1, scalecdy = 1,
			scalerdx = -1, scalerdy = 1
		}
	}
}

local function getGidFlip(gid)
	if not gid then
		return
	end

	-- can't use real bitops because of their limitations in LuaJIT
	--
	-- "It's desirable to define semantics that work the same across all
	-- platforms. This dictates that all operations are based on the common
	-- denominator of *32 bit integers*."
	--
	-- "the Lua number type must be signed and may be limited to 32 bits.
	-- Defining the result type as an unsigned number would not be
	-- cross-platform safe. All bit operations are thus defined to return
	-- results in the range of signed 32 bit numbers (converted to the Lua
	-- number type)."

	local flipx, flipy, flipd
	if gid >= 0x80000000 then
		flipx = true
		gid = gid - 0x80000000
	end
	if gid >= 0x40000000 then
		flipy = true
		gid = gid - 0x40000000
	end
	if gid >= 0x20000000 then
		flipd = true
		gid = gid - 0x20000000
	end

	local sx, sy, r = 1, 1, 0
	if flipd then
		r  = pi/2
		sx = -sx
	end
	if flipx then
		sx = -sx
	end
	if flipy then
		sy = -sy
	end
	return gid, sx, sy, r
end
Map.getGidFlip = getGidFlip

local function getTileByGid(tiles, gid)
	local sx, sy, r
	gid, sx, sy, r = getGidFlip(gid)
	return tiles[gid], sx, sy, r
end

local function getTilesetTile(tilesets, tileset, tileid)
	local tileset = tilesets[tileset]
		or type(tileset)=="string" and assets.get(tileset)
	if not tileset then
		return
	end
	tileid = tileid or 1
	if type(tileid)=="string" then
		tileid = tileset.namedtiles[tileid]
	end
	return tileset[tileid]
end

function Map.getTileByGid(map, gid)
	return getTileByGid(map.tiles, gid)
end

function Map.forEachLayerTile(map, layer, func, ...)
	local maptilewidth = map.tilewidth
	local maptileheight = map.tileheight
	local hmaptilewidth = maptilewidth/2
	local hmaptileheight = maptileheight/2

	local i = 1
	local x = 0
	local y = 0
	local cdx, cdy = maptilewidth, 0
	local rdx, rdy = 0, maptileheight
	local scalecdx, scalecdy = 1, 1
	local scalerdx, scalerdy = 1, 1

	local width = layer.width or map.width
	local height = layer.height or map.height

	local orientation = map.orientation
	if orientation == "isometric" then
		x = (height - 1) * hmaptilewidth
		cdx, cdy = hmaptilewidth, hmaptileheight
		rdx, rdy = -hmaptilewidth, hmaptileheight
	elseif orientation ~= "orthogonal" then
		local staggeraxis = map.staggeraxis
		local staggerindex = map.staggerindex
		local stagger = Staggers[staggeraxis]
		stagger = stagger and stagger[staggerindex]
		if stagger then
			x = stagger.x * maptilewidth
			y = stagger.y * maptileheight
			cdx = stagger.cdx * maptilewidth
			cdy = stagger.cdy * maptileheight
			rdx = stagger.rdx * maptilewidth
			rdy = stagger.rdy * maptileheight
			scalecdx = stagger.scalecdx
			scalecdy = stagger.scalecdy
			scalerdx = stagger.scalerdx
			scalerdy = stagger.scalerdy
		end
	end

	local tiles = map.tiles
	for r = 1, height do
		local totalcdx = 0
		local totalcdy = 0
		for c = 1, width do
			local tile, sx, sy, r = getTileByGid(tiles, layer[i])
			func(layer, i, tile, x, y, sx, sy, r, ...)
			i = i + 1
			x = x + cdx
			y = y + cdy
			totalcdx = totalcdx + cdx
			totalcdy = totalcdy + cdy
			cdx = cdx*scalecdx
			cdy = cdy*scalecdy
		end
		x = x - totalcdx + rdx
		y = y - totalcdy + rdy
		rdx = rdx*scalerdx
		rdy = rdy*scalerdy
	end
end

local function setObjectTile(object, tile, flipx, flipy)
	local animationframe, animationmsecs
	if tile then
		local animation = tile.animation
		if animation then
			object.animationmsecs = 0
			object.animationframe = 1
			tile = tile.tileset:getAnimationFrameTile(tile, 1)
		end
	end
	object.tile = tile
	object.flipx = flipx or 1
	object.flipy = flipy or 1
end

function Map.setObjectGid(map, object, gid)
	local tiles = object.tileset or map.tiles
	local tile, sx, sy = getTileByGid(tiles, gid)
	object.gid = gid
	setObjectTile(object, tile, sx, sy)
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
	local tile, sx, sy, r = getTileByGid(tiles, gid)
	local animation = tile and tile.animation
	map.layertileanimations[gid] = animation
	local f = animation and animation.globalframe
	if f then
		layer.tileanimationframes[i] = f
	end

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
	local tileset = layer.tileset
	if not tileset:areGidsInRange(mingid, maxgid) then
		layer.spritebatch = nil
	end

	local spritebatch = layer.spritebatch
	if not spritebatch then
		return
	end

	if f then
		tile = tileset:getAnimationFrameTile(tile, f)
	end

	local maptilewidth = map.tilewidth
	local maptileheight = map.tileheight
	local x, y = x*maptilewidth, y*maptileheight
	Map.setSpriteBatchTile(map, spritebatch, i, tile, x, y, sx, sy, r)
end

function Map.setSpriteBatchTile(map, spritebatch, i, tile, x, y, sx, sy, r)
	if tile then
		local tileset = tile.tileset
		local tileheight = tileset.tileheight
		local tileoffsetx = tileset.tileoffsetx
		local tileoffsety = tileset.tileoffsety
		r = r or 0
		sx = sx or 1
		sy = sy or 1
		spritebatch:set(i, tile.quad, x, y, r, sx, sy,
			tileoffsetx, tileoffsety)
	else
		spritebatch:set(i, 0, 0, 0, 0, 0)
	end
end

local function listObjectsById(layers, layersbyid, objectsbyid)
	layersbyid = layersbyid or {}
	objectsbyid = objectsbyid or {}
	for i = 1, #layers do
		local layer = layers[i]
		local layerid = layer.id
		if layerid then
			layersbyid[layerid] = layer
		end
		if layer.tag == "objectgroup" then
			for j = 1, #layer do
				local object = layer[j]
				objectsbyid[object.id] = object
			end
		elseif layer.tag == "group" then
			listObjectsById(layer, layersbyid, objectsbyid)
		end
	end
end

function Map.initObjectManagement(map)
	map.layersbyid, map.objectsbyid = listObjectsById(map)
	map.destroyedobjectids = {}
end

local function newLayerId(map)
	local id = map.newlayerid
	map.newlayerid = id + 1
	return id
end

local function newObjectId(map)
	local id = map.newobjectid
	map.newobjectid = id + 1
	return id
end

local function newObject(map, parent)
	local object = {
		tag = "object",
		parent = parent,
		id = newObjectId(),
		x = 0,
		y = 0,
		width = 0,
		height = 0,
		rotation = 0,
		visible = true
	}
	if parent then
		if parent.tag == "objectgroup" then
			parent[#parent+1] = object
		end
	end
	return object
end

function Map.newTemplateObject(map, parent, template)
	local object = newObject(map, parent)
	Object.setTemplate(object, template)
	return object
end

function Map.newAsepriteObject(map, parent, aseprite, animation, anchorx, anchory)
	local object = newObject(map, parent)
	Object.setAseprite(object, aseprite, animation, anchorx, anchory)
	return object
end

function Map.newTileObject(map, parent, tileset, tileid, flipx, flipy)
	local tile = getTilesetTile(map.tilesets, tileset, tileid)
	if not tile then
		return
	end
	local object = newObject(map, parent)
	object.gid = tileset.firstgid + tileid
	setObjectTile(object, tile, flipx, flipy)
	return object
end

function Map.getLayerById(map, id)
	return map.layersbyid[id]
end

function Map.getObjectById(map, id)
	return map.objectsbyid[id]
end

function Map.destroyObject(map, id)
	if type(id)=="table" then
		id = id.id
	end
	map.destroyedobjectids[id] = true
end

local function clearDestroyedObject(objectsbyid, id)
	local object = objectsbyid[id]
	objectsbyid[id] = nil
	if object then
		local parent = object.parent
		if parent then
			for i = 1, #parent do
				if parent[i] == object then
					table.remove(parent, i)
					break
				end
			end
		end
	end
end

local function doEvent(node, event, ...)
	local func = node[event]
	if func then
		return func(...)
	end
end

function Map.doEvent(map, event, ...)
	if doEvent(map, event, ...) then
		return
	end
	for l = 1, #map do
		local layer = map[l]
		if not doEvent(layer, event, ...) then
			if layer.tag == "objectgroup" then
				for o = 1, #layer do
					doEvent(layer[o], event, ...)
				end
			end
		end
	end
end

local update = require "tiled.update"
local draw = require "tiled.draw"

function Map.update(map, dt)
	local objectsbyid = map.objectsbyid
	local destroyedobjectids = map.destroyedobjectids
	for id, _ in pairs(destroyedobjectids) do
		clearDestroyedObject(objectsbyid, id)
		destroyedobjectids[id] = nil
	end
	update(map, dt)
end

function Map.draw(map, lerp)
	draw(map, lerp)
end

return Map
