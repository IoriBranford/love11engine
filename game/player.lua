local unit = require "unit"

local player = {
	states = {
		playing = {},
		entering = { timeout = 30, timeoutstate = "playing" }
	}
}

function player.create(x, y)
	local p = unit.create(x, y)
	p.states = player.states
	unit.setstate(p, "entering")
	return p
end

function player.states.entering:onenter()
	self.velocity_y = -8
	self.face_x = 0
	self.face_y = -1
	self.firetimer = 0
	self.aabb_filter = function(self, other)
		return "cross"
	end
end

function player.states.entering:fixedupdate()
	if self.velocity_y < 0 then
		self.velocity_y = self.velocity_y + 1
	end
	local newx, newy, colls, numcolls = unit.world:move(self,
		self.aabb_x + self.velocity_x,
		self.aabb_y + self.velocity_y,
		self.aabb_filter)
	self.aabb_x = newx
	self.aabb_y = newy
end

function player.states.playing:onenter()
	self.aabb_filter = function(self, other)
		if other.team == "boundary" then
			return "slide"
		end
		return "cross"
	end
end

function player.states.playing:update(dt)
	local velocity_x, velocity_y = 0, 0
	if love.keyboard.isDown("left"	) then velocity_x = velocity_x - 2 end
	if love.keyboard.isDown("right"	) then velocity_x = velocity_x + 2 end
	if love.keyboard.isDown("up"	) then velocity_y = velocity_y - 2 end
	if love.keyboard.isDown("down"	) then velocity_y = velocity_y + 2 end
	self.velocity_x = velocity_x
	self.velocity_y = velocity_y
end

function player.states.playing:fixedupdate()
	local newx, newy, colls, numcolls = unit.world:move(self,
		self.aabb_x + self.velocity_x,
		self.aabb_y + self.velocity_y,
		self.aabb_filter)
	self.aabb_x = newx
	self.aabb_y = newy
	if self.firetimer <= 0 and love.keyboard.isDown("space") then
		self.firetimer = 6
		local cx = newx + self.aabb_w/2
		local cy = newy + self.aabb_h/2
		local bullet = unit.create(cx, cy)
		bullet.face_x = 0
		bullet.face_y = -1
		bullet.lifetime = 30
		bullet.velocity_y = -8
		function bullet:fixedupdate()
			local newx, newy, colls, numcolls = unit.world:move(self,
				self.aabb_x + self.velocity_x,
				self.aabb_y + self.velocity_y,
				function(self, other)
					return "cross"
				end)
			self.aabb_x = newx
			self.aabb_y = newy
			self.lifetime = self.lifetime - 1
			if self.lifetime <= 0 then
				unit.expire(self)
			end
		end
	else
		self.firetimer = math.max(0, self.firetimer - 1)
	end
end

return player
