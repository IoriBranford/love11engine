local pairs = pairs
local floor = math.floor

local update = {}
setmetatable(update, {
	__index = function()
		return function()
		end
	end
})

function update.map(map, _, _, dmsecs)
	for gid, animation in pairs(map.layertileanimations) do
		local f = animation.globalframe
		local msecs = animation.globalmsecs
		f, msecs = animation:getNewFrameAndMsecs(f, msecs, dmsecs)
		animation.globalframechanged = f ~= animation.globalframe
		animation.globalframe, animation.globalmsecs = f, msecs
	end
end

function update.layer(layer, _, map, dmsecs)
	if type(layer[1]) ~= "number" then
		return
	end
	local tileanimationframes = layer.tileanimationframes
	local tiles = map.tiles
	for i, f in pairs(tileanimationframes) do
		local gid = layer[i]
		local tile = tiles[gid]
		local animation = tile.animation
		tileanimationframes[i] = animation.globalframe
	end

	local spritebatch = layer.spritebatch
	if not spritebatch then
		return true
	end

	for i, f in pairs(tileanimationframes) do
		local gid = layer[i]
		local tile = tiles[gid]
		local animation = tile.animation
		if animation.globalframechanged then
			tile = tile.tileset:getAnimationFrameTile(tile, f)
			local maptilewidth = map.tilewidth
			local maptileheight = map.tileheight
			local width = layer.width
			local i0 = i - 1
			local x = i0 % width
			local y = floor(i0 / width)
			x, y = x*maptilewidth, y*maptileheight
			map:setSpriteBatchTile(spritebatch, i, x, y, tile)
		end
	end
	return true
end
update.chunk = update.layer

function update.object(object, objectgroup, map, dmsecs)
	local tiles = object.tileset or map.tiles
	local gid = object.gid
	local animatedtile = tiles[gid]
	local animation = animatedtile and animatedtile.animation
	if animation then
		local f = object.animationframe
		local msecs = object.animationmsecs
		local f2
		f2, msecs = animation:getNewFrameAndMsecs(f, msecs, dmsecs)
		if f ~= f2 then
			f = f2
			local tileset = animatedtile.tileset
			object.tile = tileset:getAnimationFrameTile(animatedtile, f)
		end
		object.animationframe, object.animationmsecs = f, msecs
	end
	return true
end

local function updateRecursive(node, parent, map, dmsecs)
	if not update[node.tag](node, parent, map, dmsecs) then
		for i = 1, #node do
			updateRecursive(node[i], node, map, dmsecs)
		end
	end
end

return function(map, dmsecs)
	updateRecursive(map, nil, map, dmsecs)
end
