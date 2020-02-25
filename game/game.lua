local sqrt = math.sqrt
local pi = math.pi
local cos = math.cos
local sin = math.sin
local abs = math.abs
local min = math.min
local atan2 = math.atan2
local LG = love.graphics
local LE = love.event
local LJ = love.joystick
local LK = love.keyboard
local LM = love.math
local LP = love.physics
local audio = require "audio"
local assets = require "assets"
local tablex = require "pl.tablex"

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
		local shape = LP.newRectangleShape(32, 32)
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
	local movestick = player.movestick or "left"
	local movekeys = player.movekeys or "a,d,w,s"
	local firetrigger = player.firetrigger or "left"
	local firekey = player.firekey or "space"
	local keyl, keyr, keyu, keyd = movekeys:match("(%w+),(%w+),(%w+),(%w+)")
	local ax, ay = 0, 0
	local fire = (LK.isDown(firekey) and 1 or 0)
	ax = ax - (LK.isDown(keyl) and 1 or 0)
	ax = ax + (LK.isDown(keyr) and 1 or 0)
	ay = ay - (LK.isDown(keyu) and 1 or 0)
	ay = ay + (LK.isDown(keyd) and 1 or 0)
	for _, joystick in pairs(LJ.getJoysticks()) do
		ax = ax + joystick:getGamepadAxis(movestick.."x")
		ay = ay + joystick:getGamepadAxis(movestick.."y")
		fire = fire + joystick:getGamepadAxis("trigger"..firetrigger)
	end
	player.fire = fire
	local alen = sqrt(ax*ax + ay+ay)
	if alen > 1 then
		ax = ax/alen
		ay = ay/alen
	end

	local speed = player.speed or 300
	player.body:setLinearVelocity(ax*speed, ay*speed)
end

local function explodeLines(map, object)
	local polygon, linecolor = object.polygon, object.linecolor
	if not polygon or not linecolor then
		return
	end
	local x, y, parent, force, lifetime = object.x, object.y,
		object.parent, object.explodeforce, object.explodetime
	for i = 1, #polygon-3, 2 do
		local x1 = polygon[i+0]
		local y1 = polygon[i+1]
		local x2 = polygon[i+2]
		local y2 = polygon[i+3]
		local cx = (x1+x2) / 2
		local cy = (y1+y2) / 2
		x1 = x1 - cx
		y1 = y1 - cy
		x2 = x2 - cx
		y2 = y2 - cy
		local shard = map:newObject(parent)
		shard.x = x + cx
		shard.y = y + cy
		shard.polyline = { x1, y1, x2, y2 }
		shard.linecolor = linecolor
		shard.timeleft = lifetime
		local body = shard:addBody(world, "dynamic")
		body:setLinearVelocity(force*cx, force*cy)
		body:setAngularVelocity(force*pi)
	end
end

local function explodeTriangles(map, object)
	local polygon, fillcolor = object.polygon, object.fillcolor
	if not polygon or not fillcolor then
		return
	end
	local tris = object.triangles or LM.triangulate(polygon)
	local x, y, parent, force, lifetime = object.x, object.y,
		object.parent, object.explodeforce, object.explodetime
	for i = 1, #tris do
		local tri = tris[i]
		local cx = (tri[1] + tri[3] + tri[5]) / 3
		local cy = (tri[2] + tri[4] + tri[6]) / 3
		tri = { tri[1]-cx, tri[2]-cy,
			tri[3]-cx, tri[4]-cy,
			tri[5]-cx, tri[6]-cy }

		local shard = map:newObject(parent)
		shard.x = x + cx
		shard.y = y + cy
		shard.polygon = tri
		shard.fillcolor = fillcolor
		shard.timeleft = lifetime
		local body = shard:addBody(world, "dynamic")
		body:setLinearVelocity(force*cx, force*cy)
		body:setAngularVelocity(force*pi)
	end
end

local function knockoutShip(map, ship)
	audio.play(ship.killsound)
	explodeLines(map, ship)
	explodeTriangles(map, ship)
end

local function killShip(map, ship)
	for i = 1, #ship do
		local child = ship[i]
		child:setParent(ship.parent)
		killShip(map, child)
	end
	audio.play(ship.killsound)
	explodeLines(map, ship)
	explodeTriangles(map, ship)
	map:destroyObject(ship.id)
end

local function fireBullet_XY(map, ship, template, vx, vy, angle)
	local bullet = map:newTemplateObject(ship, template)
	bullet.fillcolor = tablex.copy(ship.fillcolor)
	bullet.linecolor = tablex.copy(ship.linecolor)
	bullet:setParent(ship.parent)
	local body = bullet:addBody(world, "dynamic")
	local radius = 16
	local polygon = bullet.polygon
	if polygon then
		local rsq = 0
		for i = 1, #polygon - 1, 2 do
			local x = polygon[i]
			local y = polygon[i+1]
			rsq = rsq + x*x + y*y
		end
		radius = sqrt(rsq/(#polygon/2))
	end
	local shape = LP.newCircleShape(radius)
	local fixture = LP.newFixture(body, shape)
	fixture:setUserData(bullet.collisiontag)
	fixture:setSensor(true)
	body:setAngle(angle or atan2(vy, vx))
	body:setLinearVelocity(vx, vy)
end

local function fireBullet_SpeedAngle(map, ship, template, speed, angle)
	fireBullet_XY(map, ship, template, speed*cos(angle), speed*sin(angle), angle)
end

local function updatePlayerGun(map, player, dt)
	if player.visible == false then
		return
	end
	local firewait = player.firewait or dt
	firewait = firewait - dt
	if firewait <= 0 then
		fireBullet_SpeedAngle(map, player, "playershot.tx", 16*60, -pi/2)
		firewait = firewait + 1/10
	end
	player.firewait = firewait
end

local Moves = {}
local Attacks = {}

local function newEnemy(map, template, x, y, move, attack)
	local enemy = map:newTemplateObject(enemies, template)
	enemy.x = x
	enemy.y = y
	enemy.time = 0
	local move = move or enemy.move
	enemy.move = Moves[move]
	local attack = attack or enemy.attack
	enemy.attack = Attacks[attack]
	local body = enemy:addBody(world, "dynamic")
	local shape = LP.newRectangleShape(32, 32)
	local fixture = LP.newFixture(body, shape)
	fixture:setUserData("enemy")
	fixture:setSensor(true)
	return enemy
end

local function getPlayerLinkPosition(enemy)
	local player1 = players[1]
	local player2 = players[2]
	if not player1 or not player2 then
		return
	end

	local ex, ey = enemy.body:getPosition()
	local p1x, p1y = player1.body:getPosition()
	local p2x, p2y = player2.body:getPosition()
	local dx, dy = p2x-p1x, p2y-p1y
	local p1ex, p1ey = ex - p1x, ey - p1y
	local dot = dx*p1ex + dy*p1ey
	local playersdistsq = dx*dx + dy*dy
	if dot < 0 or dot > playersdistsq then
		return
	end

	local pos = dot/playersdistsq
	local projx = dx*pos
	local projy = dy*pos
	local rejx = p1ex - projx
	local rejy = p1ey - projy
	local rejsq = rejx*rejx + rejy*rejy
	if rejsq > 32*32 then
		return
	end
	return pos
end

local function haloCrackle(halo, fire)
	local radius = halo.radius
	local polygon = halo.polygon
	local numpoints = #polygon/2
	local angle = pi/2
	local dangle = 2*pi/numpoints
	local aiming = fire >= 1 and fire < 2
	for i = 1, #polygon-1, 2 do
		local x = cos(angle)
		local y = sin(angle)
		if aiming and y >= 1 then
			y = y * 2
		end

		local rand = (LM.random()*2 - 1) * 8
		local r = radius + rand
		x = x*r
		y = y*r

		polygon[i] = x
		polygon[i+1] = y
		angle = angle + dangle
	end
end

function Moves.held(enemy, map, dt)
	local player1 = players[1]
	local player2 = players[2]
	if not player1 or not player2 then
		killShip(map, enemy)
		return
	end

	local ex, ey = enemy.body:getPosition()
	local p1x, p1y = player1.body:getPosition()
	local p2x, p2y = player2.body:getPosition()
	local dx, dy = p2x-p1x, p2y-p1y

	local playerlinkpos = enemy.playerlinkpos
	if playerlinkpos < .1 then
		playerlinkpos = playerlinkpos + dt
	elseif playerlinkpos > .9 then
		playerlinkpos = playerlinkpos - dt
	end
	enemy.playerlinkpos = playerlinkpos

	local destx = p1x + dx*playerlinkpos
	local desty = p1y + dy*playerlinkpos
	local vx = (destx - ex)*30
	local vy = (desty - ey)*30
	enemy.body:setLinearVelocity(vx, vy)

	local angle = atan2(-dx, dy)
	enemy.body:setAngle(angle)
	--local av = (destangle - angle)*30

	local fire = player1.fire + player2.fire
	haloCrackle(enemy.halo, fire)

	if fire >= 2 then
		audio.play(enemy.throwsound)
		enemy.move = Moves.thrown
		for _, fixture in pairs(enemy.body:getFixtures()) do
			fixture:setUserData("thrown")
		end
		enemy.timeleft = 1
		enemy.body:setLinearVelocity(960*cos(angle), 960*sin(angle))
	end
end

function Moves.thrown(enemy, map, dt)
	haloCrackle(enemy.halo, 0)
end

function Moves.defeated(enemy, map, dt)
	local playerlinkpos = getPlayerLinkPosition(enemy)

	if playerlinkpos then
		enemy.move = Moves.held
		enemy.playerlinkpos = playerlinkpos
		for _, fixture in pairs(enemy.body:getFixtures()) do
			fixture:setUserData("held")
		end
		enemy.body:setLinearVelocity(0, 0)
		enemy.body:setAngularVelocity(0)
		enemy.timeleft = 10
		enemy.fillcolor = playerlink.linecolor

		local maxx, maxy = 0, 0
		local polygon = enemy.polygon
		for i = 1, #polygon-1, 2 do
			local x = polygon[i]
			local y = polygon[i+1]
			if abs(x) > abs(maxx) and abs(y) > abs(maxy) then
				maxx = x
				maxy = y
			end
		end
		local radius = sqrt(maxx*maxx + maxy*maxy)
		local halo = map:newObject(enemy)
		enemy.halo = halo
		halo.radius = radius
		halo.linecolor = playerlink.linecolor
		halo.explodeforce = enemy.explodeforce or 15
		halo.explodetime = enemy.explodetime or .25
		local angle = 0
		local numpoints = 16
		local dangle = 2*pi/numpoints
		polygon = {}
		halo.polygon = polygon
		for i = 1, numpoints do
			polygon[#polygon+1] = radius*cos(angle)
			polygon[#polygon+1] = radius*sin(angle)
			angle = angle + dangle
		end
	else
		enemy.body:applyForce(0, 120)
	end
end

function Moves.sin(enemy, map, dt)
	enemy.body:setLinearVelocity(320*cos(enemy.time*pi), 120)
end

function Moves.cos(enemy, map, dt)
	enemy.body:setLinearVelocity(-320*sin(enemy.time*pi), 120)
end

function Moves.dipY(enemy)
	enemy.body:setLinearVelocity(0, 480*(1-enemy.time))
end

function Moves.dipY_slow(enemy)
	enemy.body:setLinearVelocity(0, 360 - 180*enemy.time)
end

function Moves.dipX(enemy)
	local x, y = enemy.body:getPosition()
	local vx = 480*(1-enemy.time)
	if x >= 320 then
		vx = -vx
	end
	enemy.body:setLinearVelocity(vx, 0)
end

local function getAimedPlayer(x)
	return x >= 320 and players[2] or players[1]
end

function Attacks.face(enemy, map, dt)
	local x, y = enemy.body:getPosition()
	local player = getAimedPlayer(x)
	if not player then
		return
	end
	local angle = atan2(player.y - y, player.x - x)
	enemy.body:setAngle(angle)
	return angle
end

function Attacks.singleAimed(enemy, map, dt)
	local angle = Attacks.face(enemy, map, dt)
	if not angle then
		return
	end

	local interval = enemy.fireinterval or 1
	local firetime = enemy.firetime or interval
	firetime = firetime - dt
	if firetime <= 0 then
		fireBullet_SpeedAngle(map, enemy, "enemyshot.tx", 360, angle)
		firetime = firetime + interval
	end
	enemy.firetime = firetime
end

local yield = coroutine.yield

local function co_wait(t)
	while t > 0 do
		local map, dt = yield()
		t = t - dt
	end
end

local function endGame(map, dt)
	level = coroutine.create(function(map, dt)
		local music = map.music
		if music then
			local minvolume, maxvolume = music:getVolumeLimits()
			local musicvolume = maxvolume
			while musicvolume > minvolume do
				musicvolume = musicvolume - dt
				if musicvolume < minvolume then
					musicvolume = minvolume
				end
				music:setVolume(musicvolume)
				map, dt = yield()
			end
			music:stop()
		end

		local restart = map:find("named", "restart")
		if restart then
			restart.visible = true
		end
	end)
end

local function co_level(map, dt)
	local music = assets.get(map.music, "stream")
	if music then
		music:play()
		map.music = music
	end

	local x, y

	co_wait(1)
	x = 320/5
	for i = 1, 4 do
		newEnemy(map, "enemy1.tx", 320+x, 0, "dipY")
		newEnemy(map, "enemy1.tx", 320-x, 0, "dipY")
		x = x + 320/5
		co_wait(0.25)
	end
	co_wait(1.5)
	newEnemy(map, "enemy2.tx", 320+64, 0, "dipY_slow", "singleAimed")
	newEnemy(map, "enemy2.tx", 320-64, 0, "dipY_slow", "singleAimed")
	y = 240/5
	for i = 1, 4 do
		newEnemy(map, "enemy1.tx",   0, y, "dipX")
		newEnemy(map, "enemy1.tx", 640, y, "dipX")
		y = y + 240/5
		co_wait(0.25)
	end
	co_wait(1.5)

	while #enemies > 0 do
		map, dt = yield()
	end

	endGame(map, dt)
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

local function defeatEnemy(map, enemy)
	if enemy.move == Moves.defeated then
		return
	end
	knockoutShip(map, enemy)
	local body = enemy.body
	if enemy.x < 320 then
		body:setLinearVelocity(120, 0)
		body:setAngularVelocity(pi)
	else
		body:setLinearVelocity(-120, 0)
		body:setAngularVelocity(-pi)
	end
	for _, fixture in pairs(body:getFixtures()) do
		fixture:setUserData("defeated")
	end
	enemy.time = 0
	enemy.linecolor = nil
	local fillcolor = enemy.fillcolor
	enemy.fillcolor = {
		fillcolor[1]/2,
		fillcolor[2]/2,
		fillcolor[3]/2
	}
	enemy.move = Moves.defeated
	enemy.attack = nil
	if #players > 0 then
		enemy:setParent(players[1].parent)
	end
end

local function damageEnemy(map, ship)
	local health = ship.health or 1
	if health then
		health = health-1
		ship.health = health
		if health <= 0 then
			defeatEnemy(map, ship)
		end
	end
end

local function newBulletSpark(map, bullet, contact)
	local spark = map:newTemplateObject(bullet, "hitspark.tx")
	spark.fillcolor = bullet.fillcolor
	local x, y = contact:getPositions()
	spark.x = x or 0
	spark.y = y or 0
	spark:setParent(bullet.parent)
	spark:addBody(world, "dynamic")
end

local function handleCollision(map, contact)
	local f1, f2 = contact:getFixtures()
	local playerid, playershotid, enemyid, enemyshotid, thrownid
	playerid, enemyid = tagsMatch(f1, f2, "player", "enemy")
	if not playerid then
		playerid, enemyid = tagsMatch(f1, f2, "player", "enemyshot")
	end
	if playerid and enemyid then
		playerlink.visible = false
		if #players > 0 then
			killShip(map, players[1])
			killShip(map, players[2])
			players[2] = nil
			players[1] = nil
		end
		local enemy = map:getObjectById(enemyid)
		killShip(map, enemy)
		endGame(map)
		return
	end
	playershotid, enemyid = tagsMatch(f1, f2, "playershot", "enemy")
	if not playershotid then
		playershotid, enemyid = tagsMatch(f1, f2, "held", "enemy")
	end
	if not playershotid then
		playershotid, enemyid = tagsMatch(f1, f2, "held", "enemyshot")
	end
	if playershotid and enemyid then
		local enemy = map:getObjectById(enemyid)
		damageEnemy(map, enemy)
		local bullet = map:getObjectById(playershotid)
		newBulletSpark(map, bullet, contact)
		killShip(map, bullet)
		return
	end
	thrownid, enemyid = tagsMatch(f1, f2, "thrown", "enemy")
	if thrownid and enemyid then
		local enemy = map:getObjectById(enemyid)
		damageEnemy(map, enemy)

		local thrown = map:getObjectById(thrownid)
		newBulletSpark(map, thrown, contact)
		explodeTriangles(map, thrown)
		thrown.lifetime = .25
		thrown.body:setLinearVelocity(0, 0)
		thrown.body:setAngularVelocity(15*pi)
		return
	end
end

local function startGame(map)
	if not level then
		local intro = map:find("named", "intro")
		if intro then
			intro.visible = false
		end
		level = coroutine.create(co_level)
	end
end

function Game.keypressed(map, key)
	if key == "f2" then
		LE.push("load", map.filename)
	elseif key == "escape" then
		LE.quit()
	else
		for i = 1, #players do
			if key == players[i].firekey then
				startGame(map)
			end
		end
	end
end

function Game.gamepadaxis(map, gamepad, axis, value)
	if axis:find("trigger") and value >= 1 then
		startGame(map)
	end
end

function Game.gamepadpressed(map, gamepad, button)
	if button == "back" and gamepad:isGamepadDown("start")
	or button == "start" and gamepad:isGamepadDown("back")
	then
		LE.push("load", map.filename)
	elseif button == "guide" then
		LG.captureScreenshot("shot"..os.time()..".png")
	end
end

function Game.update(map)
	if level then
		for i = 1, #players do
			readPlayerInput(players[i])
		end
	end

	local lgw = LG.getWidth()
	local lgh = LG.getHeight()
	local scale = min(lgw/640, lgh/480)
	map:setViewTransform(-640*scale/2, -lgh/2, 0, scale, scale)
end

function Game.fixedUpdate(map, dt)
	if level then
		for i = 1, #players do
			updatePlayerGun(map, players[i], dt)
		end
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

	if level and coroutine.status(level) ~= "dead" then
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
				move(object, map, dt)
			end
			local attack = object.attack
			if type(attack)=="function" then
				attack(object, map, dt)
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
					for i = 1, #object do
						map:destroyObject(object[i].id)
					end
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

function Game.drawOver(map, lerp)
	--debugDrawBoundingBoxes(world, lerp)
end

return Game
