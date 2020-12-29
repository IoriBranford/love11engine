local bump = require "bump"

local unit = {}

function unit.load()
	unit.world = bump.newWorld()
	unit.nextid = 1
	unit.added = {}
	unit.expired = {}
	unit.byid = {}
end

function unit.quit()
	unit.world = nil
	unit.added = nil
	unit.expired = nil
	unit.byid = nil
end

function unit.create(cx, cy, template)
	local id = unit.nextid
	unit.nextid = id + 1
	local w, h = 8, 8
	local x, y = cx - w/2, cy - h/2
	local u = {
		id = id,
		face_x = 1,
		face_y = 0,
		aabb_x = x,
		aabb_y = y,
		aabb_w = w,
		aabb_h = h,
		velocity_x = 0,
		velocity_y = 0
	}
	if template then
		local script = template.script
		script = script and assets.get(script)
		if script then
			local states = script.states
			local firststate = template.firststate
			if states and firststate then
				u.states = states
				unit.setstate(u, firststate)
			end
		end
	end
	unit.world:add(u, x, y, w, h)
	unit.added[#unit.added+1] = u
	return u
end

function unit.expire(u)
	if type(u)=="number" then
		u = unit.byid[u]
	end
	unit.expired[#unit.expired+1] = u
end

function unit.setstate(u, statename)
	local states = u.states
	if not states then
		return
	end

	local state = states[statename]
	if not state then
		unit.expire(u)
		return
	end

	local timeout = state.timeout
	local timeoutstate = state.timeoutstate
	u.state_timer = timeout and 0 or nil
	u.state_timeout = timeout
	u.state_timeoutstate = timeoutstate

	u.fixedupdate = state.fixedupdate
	u.update = state.update

	local onenter = state.onenter
	if type(onenter)=="function" then
		onenter(u)
	end
end

function unit.updatestate(u)
	local timer = u.state_timer
	if timer then
		local timeout = u.state_timeout
		timer = timer + 1
		u.state_timer = timer

		if timer >= timeout then
			local timeoutstate = u.state_timeoutstate
			unit.setstate(u, timeoutstate)
		end
	end
end

function unit.fixedupdateall()
	for id, u in pairs(unit.byid) do
		unit.updatestate(u)
		if u.fixedupdate then
			u:fixedupdate()
		end
	end

	local world = unit.world
	local expired = unit.expired
	for i = #expired, 1, -1 do
		local u = expired[i]
		if world:hasItem(u) then
			world:remove(u)
		end
		unit.byid[u.id] = nil
		expired[i] = nil
	end

	local added = unit.added
	for i = 1, #added do
		local u = added[i]
		unit.byid[u.id] = u
	end
	for i = #added, 1, -1 do
		added[i] = nil
	end
end

function unit.updateall(dt)
	for id, u in pairs(unit.byid) do
		if u.update then
			u:update(dt)
		end
	end
end

function unit.drawall(lerp)
	for id, u in pairs(unit.byid) do
		local lerpvelx = u.velocity_x * lerp
		local lerpvely = u.velocity_y * lerp
		local lerpx = u.aabb_x + lerpvelx
		local lerpy = u.aabb_y + lerpvely

		local newx, newy, colls, numcolls = unit.world:check(u,
			lerpx, lerpy, u.aabb_filter)
		if newx ~= lerpx then
			lerpvelx = 0
		end
		if newy ~= lerpy then
			lerpvely = 0
		end

		local texture, quad = u.sprite_texture, u.sprite_quad
		local x, y = u.sprite_x, u.sprite_y
		if texture and x and y then
			x = x + lerpvelx
			y = y + lerpvely
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
			x = x + lerpvelx
			y = y + lerpvely
			love.graphics.rectangle("line", x, y, w, h)
			local cx, cy = x + w/2, y + h/2
			love.graphics.line(cx, cy, cx + u.face_x*16, cy + u.face_y*16)
		end
	end
end

return unit
