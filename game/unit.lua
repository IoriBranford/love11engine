local unit = {
	nextid = 1
}
unit.__index = unit

function unit.load(nextid)
	unit.nextid = nextid or 1
end

function unit.create(cx, cy, template)
	local id = unit.nextid
	unit.nextid = id + 1
	local w, h = 8, 8
	local facex, facey = 1, 0
	local move_dx, move_dy = 0, 0

	if template then
		--TODO
	end

	local x, y = cx - w/2, cy - h/2
	local moved_x = x + move_dx
	local moved_y = y + move_dy

	local u = {
		id = id,
		face_x = facex,
		face_y = facey,
		aabb_x = x,
		aabb_y = y,
		aabb_w = w,
		aabb_h = h,
		moved_x = moved_x,
		moved_y = moved_y,
		move_dx = move_dx,
		move_dy = move_dy
	}
	setmetatable(u, unit)
	return u
end

function unit:addtoworld(world)
	world:add(self.id, self.aabb_x, self.aabb_y, self.aabb_w, self.aabb_h)
end

function unit:removefromworld(world)
	local id = self.id
	if world:hasItem(id) then
		world:remove(id)
	end
end

function unit:move(world)
	if not world:hasItem(self.id) then
		return
	end
	local moved_x = self.aabb_x + self.move_dx
	local moved_y = self.aabb_y + self.move_dy
	self.moved_x, self.moved_y = moved_x, moved_y
	self.aabb_x, self.aabb_y, self.aabb_collisions = world:move(self.id,
		moved_x, moved_y, self.aabb_filter)
end

function unit:enterstate(statename)
	local states = self.states
	if not states then
		return
	end
	local state = states[statename]
	if not state then
		return
	end
	local timeout = state.timeout
	local timeoutstate = state.timeoutstate
	self.state_timer = timeout and 0 or nil
	self.state_timeout = timeout
	self.state_timeoutstate = timeoutstate

	self.think = state.think
	self.update = state.update

	local onenter = state.onenter
	if type(onenter)=="function" then
		onenter(self)
	end
end

function unit:fixedupdate()
	local timer = self.state_timer
	if timer then
		local timeout = self.state_timeout
		timer = timer + 1
		self.state_timer = timer

		if timer >= timeout then
			local timeoutstate = self.state_timeoutstate
			self:enterstate(timeoutstate)
		end
	end
	if self.think then
		self:think()
	end
end

function unit:draw(lerp, world)
	local lerpdx = self.move_dx * lerp
	local lerpdy = self.move_dy * lerp
	local lerpx = self.aabb_x + lerpdx
	local lerpy = self.aabb_y + lerpdy

	local newx, newy = world:check(self.id, lerpx, lerpy, self.aabb_filter)
	if newx ~= lerpx then
		lerpdx = 0
	end
	if newy ~= lerpy then
		lerpdy = 0
	end

	local texture, quad = self.sprite_texture, self.sprite_quad
	local x, y = self.sprite_x, self.sprite_y
	if texture and x and y then
		x = x + lerpdx
		y = y + lerpdy
		local r = self.sprite_rotation or 0
		local sx = self.sprite_scalex or 1
		local sy = self.sprite_scaley or 1
		local ox = self.sprite_originx or 0
		local oy = self.sprite_originy or 0
		if quad then
			love.graphics.draw(texture, quad, x, y,
				r, sx, sy, ox, oy)
		else
			love.graphics.draw(texture, x, y,
				r, sx, sy, ox, oy)
		end
	else
		x = self.aabb_x
		y = self.aabb_y
		local w = self.aabb_w
		local h = self.aabb_h
		x = x + lerpdx
		y = y + lerpdy
		love.graphics.rectangle("line", x, y, w, h)
		local cx, cy = x + w/2, y + h/2
		love.graphics.line(cx, cy, cx + self.face_x*16, cy + self.face_y*16)
	end
end
return unit
