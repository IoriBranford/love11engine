--- Universal moving object properties
--@field move function that decides object's move this frame
--@field time general-purpose auto-incrementing timer
--@field timeleft until despawn
--@table MovingObject

local sqrt = math.sqrt
local pi = math.pi
local min = math.min
local LG = love.graphics
local LE = love.event
local LM = love.math
local LP = love.physics
local assets = require "assets"
local Ship = assets.get("ship.lua")

local Game = {}

local world
local players
local enemies
local playerlink
local level

function Game.start(map)
	world = LP.newWorld()
	map.world = world
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
	setmetatable(players, { __mode = "v" })

	playerlink = map:find("named", "playerlink")
	playerlink:setParent(players[1])

	map.players = players
	map.playerlink = playerlink
end

local yield = coroutine.yield

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

	Ship.co_spawnWaves(map, dt)

	endGame(map, dt)
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
	local lgw = LG.getWidth()
	local lgh = LG.getHeight()
	local scale = min(lgw/640, lgh/480)
	map:setViewTransform(-640*scale/2, -lgh/2, 0, scale, scale)
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
			Ship.kill(players[1], map)
			Ship.kill(players[2], map)
			players[2] = nil
			players[1] = nil
		end
		local enemy = map:getObjectById(enemyid)
		Ship.kill(enemy, map)
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
		Ship.damage(enemy, map)
		local bullet = map:getObjectById(playershotid)
		newBulletSpark(map, bullet, contact)
		Ship.kill(bullet, map)
		return
	end
	thrownid, enemyid = tagsMatch(f1, f2, "thrown", "enemy")
	if thrownid and enemyid then
		local enemy = map:getObjectById(enemyid)
		Ship.damage(enemy, map)

		local thrown = map:getObjectById(thrownid)
		newBulletSpark(map, thrown, contact)
		--explodeTriangles(map, thrown)
		thrown.lifetime = .25
		thrown.body:setLinearVelocity(0, 0)
		thrown.body:setAngularVelocity(15*pi)
		return
	end
end

function Game.fixedUpdate(map, dt)
	if level and coroutine.status(level) ~= "dead" then
		local ok, err = coroutine.resume(level, map, dt)
		if not ok then
			error(err)
		end
	end

	local player1 = map.players[1]
	local player2 = map.players[2]
	if player1 and player2 then
		local x1, y1 = player1.x, player1.y
		local x2, y2 = player2.x, player2.y
		local polyline = playerlink.polyline
		Ship.makeThunder(polyline, #polyline/2, x2-x1, y2-y1)
	end

	for _, body in pairs(world:getBodies()) do
		local id = body:getUserData()
		local object = map:getObjectById(id)
		if object then
			local move = object.move
			if type(move)=="function" then
				move(object, map, dt)
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
