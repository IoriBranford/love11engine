local bump = require "bump"

local unit = require "unit"

local world = {}

function world.load()
	world.physics_world = bump.newWorld()
	world.unit_nextid = 1
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
	u.id = world.unit_nextid
	world.unit_nextid = u.id + 1
	world.units_added[#world.units_added+1] = u
	return u
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
		if physics_world:hasItem(u) then
			physics_world:remove(u)
		end
		units_byid[u.id] = nil
		expired[i] = nil
	end

	local added = world.units_added
	for i = 1, #added do
		local u = added[i]
		units_byid[u.id] = u
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
	for id, u in pairs(world.units_byid) do
		local lerpdx = u.move_dx * lerp
		local lerpdy = u.move_dy * lerp
		local lerpx = u.aabb_x + lerpdx
		local lerpy = u.aabb_y + lerpdy

		local newx, newy = world.physics_world:check(u, lerpx, lerpy, u.aabb_filter)
		if newx ~= lerpx then
			lerpdx = 0
		end
		if newy ~= lerpy then
			lerpdy = 0
		end

		local texture, quad = u.sprite_texture, u.sprite_quad
		local x, y = u.sprite_x, u.sprite_y
		if texture and x and y then
			x = x + lerpdx
			y = y + lerpdy
			local r = u.sprite_rotation or 0
			local sx = u.sprite_scalex or 1
			local sy = u.sprite_scaley or 1
			local ox = u.sprite_originx or 0
			local oy = u.sprite_originy or 0
			if quad then
				love.graphics.draw(texture, quad, x, y,
					r, sx, sy, ox, oy)
			else
				love.graphics.draw(texture, x, y,
					r, sx, sy, ox, oy)
			end
		else
			x = u.aabb_x
			y = u.aabb_y
			local w = u.aabb_w
			local h = u.aabb_h
			x = x + lerpdx
			y = y + lerpdy
			love.graphics.rectangle("line", x, y, w, h)
			local cx, cy = x + w/2, y + h/2
			love.graphics.line(cx, cy, cx + u.face_x*16, cy + u.face_y*16)
		end
	end
end

return world
