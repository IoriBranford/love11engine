local pi = math.pi
local type = type
local pairs = pairs
local setmetatable = setmetatable
local assets = require "assets"
local tablex = require "pl.tablex"
local Object = require "tiled.object"
local LM = love.math

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

	local scalex, scaley, scaled
	if gid >= 0x80000000 then
		scalex = true
		gid = gid - 0x80000000
	end
	if gid >= 0x40000000 then
		scaley = true
		gid = gid - 0x40000000
	end
	if gid >= 0x20000000 then
		scaled = true
		gid = gid - 0x20000000
	end

	local sx, sy, r = 1, 1, 0
	if scaled then
		r  = pi/2
		sx = -sx
	end
	if scalex then
		sx = -sx
	end
	if scaley then
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
	local y = maptileheight
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
	if tile then
		local animation = tile.animation
		if animation then
			object.animationmsecs = 0
			object.animationframe = 1
			tile = tile.tileset:getAnimationFrameTile(tile, 1)
		end
		local tileset = tile.tileset
		local tilewidth = tileset.tilewidth
		local tileheight = tileset.tileheight
		local width = object.width
		local height = object.height
		width = width or tilewidth
		height = height or tileheight
		flipx = flipx or 1
		flipy = flipy or 1
		object.scalex = flipx*width/tilewidth
		object.scaley = flipx*height/tileheight
		object.width = width
		object.height = height
	end

	object.tile = tile
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
	local tile, sx, sy, rot = getTileByGid(tiles, gid)
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
	local x = maptilewidth*c + tileset.tilewidth*(1-sx)/2
	local y = maptileheight*(r+1) + tileset.tileheight*(1-sy)/2
	Map.setSpriteBatchTile(map, spritebatch, i, tile, x, y, sx, sy, rot)
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
	return layersbyid, objectsbyid
end

function Map.initObjectManagement(map)
	map.layersbyid, map.objectsbyid = listObjectsById(map)
	map.destroyedobjectids = {}
end

local function newLayerId(map)
	local id = map.nextlayerid
	map.nextlayerid = id + 1
	return id
end

local function newObjectId(map)
	local id = map.nextobjectid
	map.nextobjectid = id + 1
	return id
end

local function newObject(map, parent)
	local id = newObjectId(map)
	local object = {
		tag = "object",
		id = id,
		x = 0,
		y = 0,
		rotation = 0,
		scalex = 1,
		scaley = 1,
		visible = true,
		parent = parent
	}
	setmetatable(object, Object)
	map.objectsbyid[id] = object
	if parent then
		parent[#parent+1] = object
	end
	return object
end
Map.newObject = newObject

function Map.newTemplateObject(map, parent, template)
	local object = newObject(map, parent)
	object:setTemplate(template)
	return object
end

function Map.newAsepriteObject(map, parent, aseprite, animation, anchorx, anchory)
	local object = newObject(map, parent)
	object:setAseprite(aseprite, animation, anchorx, anchory)
	return object
end

function Map.newTileObject(map, parent, tileset, tileid, scalex, scaley)
	if type(tileset)=="string" then
		tileset = map.tilesets[tileset] or assets.get(tileset)
	end
	if type(tileid)=="string" then
		tileid = tileset and tileset.namedtileids[tileid]
	end

	local tile = tileset and tileset[tileid]

	local object = newObject(map, parent)

	if tile then
		object.gid = tileset.firstgid + tileid
		setObjectTile(object, tile, scalex, scaley)
	else
		object.width = object.width or map.tilewidth
		object.height = object.height or map.tileheight
		object.linecolor = { 1, 0, 1, 1 }
	end

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
		object:onDestroy()
	end
end

local find = require "tiled.find"
local update = require "tiled.update"
local draw = require "tiled.draw"

function Map.find(map, condition, ...)
	return find[condition](map, ...)
end

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

function Map.setViewTransform(map, x, y, r, sx, sy, dx, dy, dr, dsx, dsy, lerp)
	x   	= x   	 or 0
	y   	= y   	 or 0
	r   	= r   	 or 0
	sx  	= sx  	 or 1
	sy  	= sy  	 or 1
	dx  	= dx  	 or 0
	dy  	= dy  	 or 0
	dr  	= dr  	 or 0
	dsx 	= dsx 	 or 0
	dsy 	= dsy 	 or 0
	lerp 	= lerp	 or 0
	local viewtransform = map.viewtransform or LM.newTransform()
	map.viewtransform = viewtransform
	viewtransform:reset()
	viewtransform:translate(x + dx*lerp, y + dy*lerp)
	viewtransform:rotate(r + dr*lerp)
	viewtransform:scale(sx, sy)
end

return Map
