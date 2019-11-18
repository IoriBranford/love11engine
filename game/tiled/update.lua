local pairs = pairs
local floor = math.floor

local update = {}
setmetatable(update, {
	__index = function()
		return function()
		end
	end
})

function update.map(map, _, _, dt)
	for gid, animation in pairs(map.tileanimations) do
		local f = animation.globalframe
		local msecs = animation.globalmsecs
		f, msecs = animation:getUpdate(f, msecs, dt)
		animation.globalframechanged = f ~= animation.globalframe
		animation.globalframe, animation.globalmsecs = f, msecs
	end
end

function update.layer(layer, _, map, dt)
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
			tile = tile.tileset[animation[f].tileid]
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

function update.object(object, objectgroup, map, dt)
	local gid = object.gid
	local tiles = map.tiles
	local template = object.template
	if template then
		gid = gid or template.gid
		tiles = template.tileset
	end
	local tile = tiles and tiles[gid]
	local animation = tile and tile.animation
	if animation then
		local f = object.animationframe
		local msecs = object.animationmsecs
		f, msecs = animation:getUpdate(f, msecs, dt)
		object.animationframe, object.animationmsecs = f, msecs
	end
	return true
end

local function updateRecursive(node, parent, map, dt)
	if not update[node.tag](node, parent, map, dt) then
		for i = 1, #node do
			updateRecursive(node[i], node, map, dt)
		end
	end
end

return function(map, dt)
	updateRecursive(map, nil, map, dt)
end
