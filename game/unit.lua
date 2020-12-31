local unit = {}
unit.__index = unit

function unit.create(cx, cy, template, world)
	local w, h = 8, 8
	local facex, facey = 1, 0
	local move_dx, move_dy = 0, 0

	if template then
		--TODO
	end

	local x, y = cx - w/2, cy - h/2
	local move_x = x + move_dx
	local move_y = y + move_dy

	local u = setmetatable({
		face_x = facex,
		face_y = facey,
		aabb_x = x,
		aabb_y = y,
		aabb_w = w,
		aabb_h = h,
		move_x = move_x,
		move_y = move_y,
		move_dx = move_dx,
		move_dy = move_dy
	}, unit)
	if world then
		world:add(u, x, y, w, h)
	end
	return u
end

function unit:move(world)
	if not world:hasItem(self) then
		return
	end
	local move_x = self.aabb_x + self.move_dx
	local move_y = self.aabb_y + self.move_dy
	self.move_x, self.move_y = move_x, move_y
	self.aabb_x, self.aabb_y, self.aabb_collisions = world:move(self,
		move_x, move_y, self.aabb_filter)
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

return unit
