local sqrt = math.sqrt
local pi = math.pi
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local LG = love.graphics
local LE = love.event
local LJ = love.joystick
local LK = love.keyboard
local LM = love.math
local LP = love.physics
local audio = require "audio"

local Game = {}

local world
local players
local enemies
local playerlink
local level

function Game.start(map)
	world = LP.newWorld()
	local worldbody = LP.newBody(world)

	local worldobjects = map:find("named", "worldobjects")
	for i = 1, #worldobjects do
		local object = worldobjects[i]
		local x, y = object.x, object.y
		local width, height = object.width, object.height
		local shape = LP.newRectangleShape(x + width/2, y + height/2,
			width, height)
		local fixture = LP.newFixture(worldbody, shape)
		fixture:setFriction(0)
	end

	players = {
		map:find("named", "player_left"),
		map:find("named", "player_right"),
	}

	for i = 1, #players do
		local player = players[i]
		local body = player:addBody(world, "dynamic")
		body:setFixedRotation(true)
		local shape = LP.newRectangleShape(24, 24)
		local fixture = LP.newFixture(body, shape)
		fixture:setUserData("player")
	end

	playerlink = map:find("named", "playerlink")
	playerlink:setParent(players[1])

	enemies = map:find("named", "enemies")
end

local function readPlayerInput(player)
	if player.visible == false then
		return
	end
	local controlstick = player.controlstick or "left"
	local controlkeys = player.controlkeys or "adws"
	local ax, ay = 0, 0
	ax = ax - (LK.isDown(controlkeys:sub(1, 1)) and 1 or 0)
	ax = ax + (LK.isDown(controlkeys:sub(2, 2)) and 1 or 0)
	ay = ay - (LK.isDown(controlkeys:sub(3, 3)) and 1 or 0)
	ay = ay + (LK.isDown(controlkeys:sub(4, 4)) and 1 or 0)
	for _, joystick in pairs(LJ.getJoysticks()) do
		ax = ax + joystick:getGamepadAxis(controlstick.."x")
		ay = ay + joystick:getGamepadAxis(controlstick.."y")
	end
	local alen = sqrt(ax*ax + ay+ay)
	if alen > 1 then
		ax = ax/alen
		ay = ay/alen
	end

	local speed = player.speed or 300
	player.body:setLinearVelocity(ax*speed, ay*speed)
end

local function killShip(map, ship)
	audio.play(ship.killsound)
	map:destroyObject(ship.id)
	if ship.polygon then
		local tris = LM.triangulate(ship.polygon)
		for i = 1, #tris do
			local tri = tris[i]
			local cx = (tri[1] + tri[3] + tri[5]) / 3
			local cy = (tri[2] + tri[4] + tri[6]) / 3
			for j = 1,5,2 do
				tri[j] = tri[j] - cx
				tri[j+1] = tri[j+1] - cy
			end
			local shard = map:newObject(ship.parent)
			shard.x = ship.x + cx
			shard.y = ship.y + cy
			shard.polygon = tri
			shard.linecolor = ship.linecolor
			shard.fillcolor = ship.fillcolor
			shard.timeleft = 1
			local body = shard:addBody(world, "dynamic")
			body:setLinearVelocity(16*cx, 16*cy)
			body:setAngularVelocity(4*pi)
		end
	end
end

function Game.keypressed(map, key)
	if key == "f2" then
		LE.push("load", map.filename)
	end
end

function Game.update(map)
	for i = 1, #players do
		readPlayerInput(players[i])
	end

	local lgw = LG.getWidth()
	local lgh = LG.getHeight()
	map:setViewTransform(-lgw/2, -lgh/2, 0, lgw/640, lgh/480)
end

local function updatePlayerGun(map, player, dt)
	if player.visible == false then
		return
	end
	local firewait = player.firewait or dt
	firewait = firewait - dt
	if firewait <= 0 then
		local bullet = map:newTemplateObject(player.parent, "playershot.tx")
		bullet.fillcolor = player.fillcolor
		bullet.linecolor = player.linecolor
		bullet.x = player.x
		bullet.y = player.y
		bullet.rotation = player.rotation
		local body = bullet:addBody(world, "dynamic")
		local shape = LP.newRectangleShape(0, 16, 16, 32)
		local fixture = LP.newFixture(body, shape)
		fixture:setUserData("playershot")
		fixture:setSensor(true)
		local r = -pi/2 + body:getAngle()
		local speed = 1024
		local vx, vy = speed*cos(r), speed*sin(r)
		body:setLinearVelocity(vx, vy)
		firewait = firewait + 1/15
	end
	player.firewait = firewait
end

local yield = coroutine.yield

local function co_wait(t)
	while t > 0 do
		local map, dt = yield()
		t = t - dt
	end
end

local Moves = {}

local function newEnemy(map, template, x, y)
	local enemy = map:newTemplateObject(enemies, template)
	enemy.x = x
	enemy.y = y
	enemy.time = 0
	enemy.move = Moves[enemy.move]
	local body = enemy:addBody(world, "dynamic")
	local shape = LP.newRectangleShape(32, 32)
	local fixture = LP.newFixture(body, shape)
	fixture:setUserData("enemy")
	fixture:setSensor(true)
	return enemy
end

function Moves.sin(enemy)
	enemy.body:setLinearVelocity(320*cos(enemy.time*pi), 120)
end

function Moves.cos(enemy)
	enemy.body:setLinearVelocity(-320*sin(enemy.time*pi), 120)
end

local function co_level(map, dt)
	local leftx = 240
	local rightx = 320+240
	local top = -32
	co_wait(1)
	for i = 1, 20 do
		newEnemy(map, "enemy1.tx", leftx, top)
		newEnemy(map, "enemy1.tx", rightx, top)
		co_wait(0.5)
	end
end

local function tagsMatch(f1, f2, t1, t2)
	local tag1, tag2 = f1:getUserData(), f2:getUserData()
	local id1, id2 = f1:getBody():getUserData(), f2:getBody():getUserData()
	if tag1 == t1 and tag2 == t2 then
		return id1, id2
	elseif tag1 == t2 and tag2 == t1 then
		return id2, id1
	end
end

local function handleCollision(map, contact)
	local f1, f2 = contact:getFixtures()
	local playerid, enemyid = tagsMatch(f1, f2, "player", "enemy")
	if playerid and enemyid then
		playerlink.visible = false
		killShip(map, players[1])
		killShip(map, players[2])
		players[2] = nil
		players[1] = nil
		local enemy = map:getObjectById(enemyid)
		killShip(map, enemy)
	end
	local playershotid, enemyid = tagsMatch(f1, f2, "playershot", "enemy")
	if playershotid and enemyid then
		local enemy = map:getObjectById(enemyid)
		killShip(map, enemy)
		local bullet = map:getObjectById(playershotid)
		local spark = map:newTemplateObject(bullet.parent, "hitspark.tx")
		spark.fillcolor = bullet.fillcolor
		spark.x = bullet.x
		spark.y = bullet.y
		spark.rotation = bullet.rotation
		local body = spark:addBody(world, "dynamic")
		map:destroyObject(playershotid)
	end
end

function Game.fixedUpdate(map, dt)
	for i = 1, #players do
		updatePlayerGun(map, players[i], dt)
	end

	local player1 = players[1]
	local player2 = players[2]
	if player1 and player2 then
		local x1, y1 = player1.body:getPosition()
		local x2, y2 = player2.body:getPosition()
		local dx, dy = x2-x1, y2-y1
		local dist = sqrt(dx*dx + dy*dy)
		local perpx, perpy = dy/dist, -dx/dist

		local polyline = playerlink.polyline
		polyline[1] = 0
		polyline[2] = 0
		for i = 3, #polyline-3, 2 do
			local rand = (LM.random()*2 - 1) * 8
			local t = i/#polyline
			local x = dx*t + perpx*rand
			local y = dy*t + perpy*rand
			polyline[i  ] = x
			polyline[i+1] = y
		end
		polyline[#polyline-1] = dx
		polyline[#polyline  ] = dy
	end

	level = level or coroutine.create(co_level)
	if coroutine.status(level) ~= "dead" then
		local ok, err = coroutine.resume(level, map, dt)
		if not ok then
			error(err)
		end
	end

	for _, body in pairs(world:getBodies()) do
		local id = body:getUserData()
		local object = map:getObjectById(id)
		if object then
			local move = object.move
			if type(move)=="function" then
				move(object, dt)
			end
			local time = object.time
			if time then
				object.time = time + dt
			end
		end
	end

	world:update(dt)

	for _, contact in pairs(world:getContacts()) do
		if contact:isTouching() then
			handleCollision(map, contact)
		end
	end

	for _, body in pairs(world:getBodies()) do
		local id = body:getUserData()
		local object = map:getObjectById(id)
		if object then
			object:updateFromBody()

			local timeleft = object.timeleft
			if timeleft then
				timeleft = timeleft - dt
				object.timeleft = timeleft
				if timeleft <= 0 then
					map:destroyObject(id)
				end
			end
		end
	end
end

local function debugDrawBoundingBoxes(world, lerp)
	for _, body in pairs(world:getBodies()) do
		local vx, vy = body:getLinearVelocity()
		for _, fixture in pairs(body:getFixtures()) do
			local x1, y1, x2, y2 = fixture:getBoundingBox()
			local w, h = x2-x1, y2-y1
			x1 = x1 + vx*lerp
			y1 = y1 + vy*lerp
			LG.rectangle("line", x1, y1, w, h)
		end
	end
end

--function Game.drawOver(map, lerp)
--	debugDrawBoundingBoxes(world, lerp)
--end

return Game
