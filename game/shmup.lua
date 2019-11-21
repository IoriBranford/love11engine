--- Shmup object
--@field team
--@field health
--@field x
--@field y
--@field bodytype
--@field init
--@field update
--@field beginContact
--@table ShmupObject

local Level = {
	instance = nil,
	nextenemytime = 2
}

local Bullet = {
	bodytype = "dynamic",
	lifetime = 1/3,
	width = 8,
	height = 16,
	velx = 0,
	vely = -16
}

function Bullet:init()
	local body = self:newBody()
	local shape = LP.newRectangleShape(self.width, self.height)
	local fixture = LP.newFixture(body, shape)
	fixture:setSensor(true)
end

function Bullet:fixedUpdate(fixeddt)
	local lifetime = self.lifetime
	lifetime = lifetime - fixeddt
	if lifetime <= 0 then
		self:setFree()
	end
	self.lifetime = lifetime
end

function Bullet:beginContact(other)
	if self.team == other.team then
	else
		self:setFree()
	end
end

local Player = {
	width = 16,
	height = 16,
	bodytype = "dynamic",
	firewait = 0
}

function Player:update()
	local body = self.body

	local keyUp = "up"
	local keyDown = "down"
	local keyLeft = "left"
	local keyRight = "right"
	local keyFire = "z"
	local keySlow = "lshift"
	local joyX = 1
	local joyY = 2
	local joyHat = 1
	local joyFire = 1
	local joySlow = 2
	local padX = "leftx"
	local padY = "lefty"
	local padUp = "dpup"
	local padDown = "dpdown"
	local padLeft = "dpleft"
	local padRight = "dpright"
	local padFire = "x"
	local padSlow = "a"
	local deadzonesq = 1/16
	local speedNormal = 180
	local speedSlow = 120

	local firing = LK.isDown(keyFire)
	local slowed = LK.isDown(keySlow)

	local inx, iny = 0, 0
	inx = inx - (LK.isDown(keyLeft)	and 1 or 0)
	inx = inx + (LK.isDown(keyRight)and 1 or 0)
	iny = iny - (LK.isDown(keyUp)	and 1 or 0)
	iny = iny + (LK.isDown(keyDown)	and 1 or 0)
	for _, joystick in pairs(LJ.getJoysticks()) do
		local ax, ay = 0, 0
		local bl, br, bu, bd
		if joystick:isGamepad() then
			firing = firing or joystick:isGamepadDown(padFire)
			slowed = slowed or joystick:isGamepadDown(padSlow)
			ax = joystick:getGamepadAxis(padX)
			ay = joystick:getGamepadAxis(padY)
			bl = joystick:isGamepadDown(padLeft)
			br = joystick:isGamepadDown(padRight)
			bu = joystick:isGamepadDown(padUp)
			bd = joystick:isGamepadDown(padDown)
		else
			firing = firing or joystick:isDown(joyFire)
			slowed = slowed or joystick:isDown(joySlow)
			ax = joystick:getAxis(joyX)
			ay = joystick:getAxis(joyY)
			local hat = joystick:getHat(joyHat)
			bl = hat:find("l")
			br = hat:find("r")
			bu = hat:find("u")
			bd = hat:find("d")
		end
		if ax*ax + ay*ay >= deadzonesq then
			inx = inx + ax
			iny = iny + ay
		end
		inx = inx - (bl and 1 or 0)
		inx = inx + (br and 1 or 0)
		iny = iny - (bu and 1 or 0)
		iny = iny + (bd and 1 or 0)
	end
	local insq = inx*inx + iny*iny
	if insq > 1 then
		local inmag = sqrt(insq)
		inx = inx / inmag
		iny = iny / inmag
	end

	local speed = slowed and speedSlow or speedNormal
	body:setLinearVelocity(inx*speed, iny*speed)

	self.firing = firing
end

function Player:fixedUpdate(fixeddt)
	if self.firing then
		local firewait = self.firewait
		if firewait <= 0 then
			local bullet = newObject(Bullet)
			bullet.x, bullet.y = body:getPosition()
			self.firewait = 1/10
		else
			self.firewait = firewait - fixeddt
		end
	else
		self.firewait = 0
	end
end

function Player:init()
	local body = self:newBody()
	local shape = LP.newRectangleShape(self.width, self.height)
	local fixture = LP.newFixture(body, shape)
end

function Player:beginContact(other)
	if self.team == other.team then
	else
		self:setFree()
		Level.instance.playerid = nil
	end
end

local Enemy = {
	width = 32,
	height = 16,
	bodytype = "dynamic",
	team = "Enemy",
	health = 5,
	firewait = .5,
	lifetime = 10
}

function Enemy:beginContact(other)
	if self.team == other.team then
	else
		local health = self.health
		health = health - 1
		self.health = health
		if health <= 0 then
			self:setFree()
		end
	end
end

function Enemy:init()
	local body = self:newBody()
	local shape = LP.newRectangleShape(self.width, self.height)
	local fixture = LP.newFixture(body, shape)
	fixture:setSensor(true)
end

function Enemy:fixedUpdate(fixeddt)
	local time = self.time or 0

	local velx
	if self.x > 120 then
		velx = -sin(pi*time)
	else
		velx = sin(pi*time)
	end
	self.body:setLinearVelocity(velx, 120)

	time = time + fixeddt
	self.time = time
	if time >= self.lifetime then
		self:setFree()
	end

	local firewait = self.firewait
	local playerid = Level.instance.playerid
	if firewait <= 0 and playerid then
		local player = getObject(playerid)
		local x, y = self.body:getPosition()
		local px, py = player.body:getPosition()
		local dx, dy = px - x, py - y
		local d = sqrt(dx*dx + dy*dy)

		local bullet = newObject(Bullet)
		bullet.x, bullet.y = self.body:getPosition()
		bullet.team = "Enemy"
		bullet.width = 4
		bullet.height = 4
		bullet.velx = 4*dx/d
		bullet.vely = 4*dy/d
		bullet.lifetime = 2

		self.firewait = Enemy.firewait
	else
		self.firewait = firewait - fixeddt
	end
end

function Level:fixedUpdate(fixeddt)
	local nextenemytime = self.nextenemytime
	nextenemytime = nextenemytime - fixeddt
	if nextenemytime <= 0 then
		nextenemytime = nextenemytime + Level.nextenemytime
		local enemy = newObject(Enemy)
		enemy.x = LM.random(2) == 1 and 180 or 60
		enemy.y = 0
	end
	self.nextenemytime = nextenemytime
	tiled.update(map, fixeddt)
end

function Level:init()
	local body = self:newBody()
	local shape = LP.newChainShape(true, 0, 0, 0, 320, 240, 320, 240, 0)
	local fixture = LP.newFixture(body, shape)
	fixture:setFriction(0)

	local player = newObject(Player)
	player.x, player.y = 120, 304
	self.playerid = player.id
end