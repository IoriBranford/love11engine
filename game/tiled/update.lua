local pairs = pairs
local floor = math.floor

local update = {}
local function update_default(node, parent, root, dt)
	local body = node.body
	if body then
		node.x, node.y = body:getPosition()
		node.rotation = body:getAngle()
		node.dx, node.dy = body:getLinearVelocity()
		node.drotation = body:getAngularVelocity()
	end
end
setmetatable(update, {
	__index = function()
		return update_default
	end
})

function update.map(map, _, _, dt)
	update_default(map, _, _, dt)
	for gid, animation in pairs(map.layertileanimations) do
		local f = animation.globalframe
		local msecs = animation.globalmsecs
		f, msecs = animation:getNewFrameAndMsecs(f, msecs, dt*1000)
		animation.globalframechanged = f ~= animation.globalframe
		animation.globalframe, animation.globalmsecs = f, msecs
	end
end

function update.layer(layer, _, map, dt)
	update_default(layer, _, map, dt)
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
--[[
function update.asepritebatch(asepritebatch, parent, map, dt)
	local animation = asepritebatch.animation
	local aseprite = asepritebatch.aseprite
	local spritebatch = asepritebatch.spritebatch
	if animation then
		local f = asepritebatch.animationframe
		local msecs = asepritebatch.animationmsecs
		f, msecs = aseprite:animateSpriteBatch(spritebatch,
				animation, f, msecs, dt*1000)
		asepritebatch.animationframe = f
		asepritebatch.animationmsecs = msecs
	end
end
]]
function update.object(object, objectgroup, map, dt)
	update_default(object, objectgroup, map, dt)
	local tiles = object.tileset or map.tiles
	local gid = object.gid
	local animatedtile = tiles[gid]
	local animation = object.animation or animatedtile and animatedtile.animation
	if animation then
		local f = object.animationframe
		local msecs = object.animationmsecs

		local aseprite = object.aseprite
		if aseprite then
			local spritebatch = object.spritebatch
			f, msecs = aseprite:animateSpriteBatch(spritebatch,
				animation, f, msecs, dt*1000)
		else
			local tile
			tile, f, msecs = animation:animateTile(animatedtile, f,
							msecs, dt*1000)
			object.tile = tile
		end
		object.animationframe = f
		object.animationmsecs = msecs
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
