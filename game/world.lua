local bump = require "bump"
local unit = require "unit"

local world = {}

function world.load()
	world.physics_world = bump.newWorld()
	unit.load()
	world.units_added = {}
	world.units_expired = {}
	world.units_byid = {}
end

function world.quit()
	world.physics_world = nil
	world.units_added = nil
	world.units_expired = nil
	world.units_byid = nil
end

function world.createunit(cx, cy, template)
	local u = unit.create(cx, cy, template, world.physics_world)
	world.units_added[#world.units_added+1] = u
	return u
end

function world.getunit(id)
	return world.units_byid[id]
end

function world.expireunit(u)
	if type(u)=="number" then
		u = world.units_byid[u]
	end
	world.units_expired[#world.units_expired+1] = u
end

function world.fixedupdate()
	local physics_world = world.physics_world
	local units_byid = world.units_byid

	for id, u in pairs(units_byid) do
		u:move(physics_world)
	end

	for id, u in pairs(units_byid) do
		u:fixedupdate()
	end

	local expired = world.units_expired
	for i = #expired, 1, -1 do
		local u = expired[i]
		u:removefromworld(physics_world)
		units_byid[u.id] = nil
		expired[i] = nil
	end

	local added = world.units_added
	for i = 1, #added do
		local u = added[i]
		units_byid[u.id] = u
		u:addtoworld(physics_world)
	end
	for i = #added, 1, -1 do
		added[i] = nil
	end
end

function world.update(dt)
	for id, u in pairs(world.units_byid) do
		if u.update then
			u:update(dt)
		end
	end
end

function world.draw(lerp)
	local physics_world = world.physics_world
	for id, u in pairs(world.units_byid) do
		u:draw(lerp, physics_world)
	end
end

return world
