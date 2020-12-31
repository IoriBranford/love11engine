local world = require "world"
local unit = require "unit"

local player = {}
local states = {
	playing = {},
	entering = { timeout = 30, timeoutstate = "playing" }
}

function player.create(x, y)
	local p = world.createunit(x, y)
	p.states = states
	p:enterstate("entering")
	return p
end

function states.entering:onenter()
	self.move_dy = -8
	self.face_x = 0
	self.face_y = -1
	self.firetimer = 0
	self.aabb_filter = function() end
end

function states.entering:think()
	if self.move_dy < 0 then
		self.move_dy = self.move_dy + 1
	end
end

function states.playing:onenter()
	self.aabb_filter = function(self, otherid)
		local other = world.getunit(otherid)
		if other then
			return "cross"
		end
		return "slide"
	end
end

function states.playing:update(dt)
	local move_dx, move_dy = 0, 0
	if love.keyboard.isDown("left"	) then move_dx = move_dx - 2 end
	if love.keyboard.isDown("right"	) then move_dx = move_dx + 2 end
	if love.keyboard.isDown("up"	) then move_dy = move_dy - 2 end
	if love.keyboard.isDown("down"	) then move_dy = move_dy + 2 end
	self.move_dx = move_dx
	self.move_dy = move_dy
end

function states.playing:think()
	if self.firetimer <= 0 and love.keyboard.isDown("space") then
		self.firetimer = 6
		local cx = self.aabb_x + self.aabb_w/2
		local cy = self.aabb_y + self.aabb_h/2
		local bullet = world.createunit(cx, cy)
		bullet.face_x = 0
		bullet.face_y = -1
		bullet.lifetime = 30
		bullet.move_dy = -8
		bullet.aabb_filter = function(self, otherid)
			return "cross"
		end
		function bullet:think()
			self.lifetime = self.lifetime - 1
			if self.lifetime <= 0 then
				world.expireunit(self)
			end
		end
	else
		self.firetimer = math.max(0, self.firetimer - 1)
	end
end

return player
