local sqrt = math.sqrt
local pi = math.pi
local cos = math.cos
local sin = math.sin
local LG = love.graphics
local LE = love.event
local LJ = love.joystick
local LK = love.keyboard
local LM = love.math
local LP = love.physics

local Game = {}

local world
local players
local playerlink

function Game.start(map)
	world = LP.newWorld()
	local worldbody = LP.newBody(world)

	local worldobjects = map:find("named", "worldobjects")
	for i = 1, #worldobjects do
		local object = worldobjects[i]
		local x, y = object:getGlobalPosition()
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
		local shape = LP.newCircleShape(8)
		local fixture = LP.newFixture(body, shape)
	end

	playerlink = map:find("named", "playerlink")
	playerlink:setParent(players[1])
end

function Game.keypressed(map, key)
	if key == "escape" then
		LE.quit()
	end
end

local function readPlayerInput(player)
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

function Game.update(map)
	for i = 1, #players do
		readPlayerInput(players[i])
	end

	local lgw = LG.getWidth()
	local lgh = LG.getHeight()
	map:setViewTransform(-lgw/2, -lgh/2, 0, lgw/640, lgh/480)
end

local function updatePlayerGun(map, player, dt)
	local firewait = player.firewait or dt
	firewait = firewait - dt
	if firewait <= 0 then
		local bullet = map:newTemplateObject(player.parent, "playershot.tx")
		bullet.fillcolor = player.fillcolor
		bullet.linecolor = player.linecolor
		player:getGlobalTransform(bullet.transform)
		local body = bullet:addBody(world, "dynamic")
		local shape = LP.newRectangleShape(bullet.width, bullet.height)
		local fixture = LP.newFixture(body, shape)
		fixture:setSensor(true)
		local r = -pi/2 + body:getAngle()
		local speed = 1024
		local vx, vy = speed*cos(r), speed*sin(r)
		body:setLinearVelocity(vx, vy)
		firewait = firewait + 1/15
	end
	player.firewait = firewait
end

local function updateObjectLifetimes(map, dt)
	for id, object in pairs(map.objectsbyid) do
		local lifetime = object.lifetime
		if lifetime then
			lifetime = lifetime - dt
			object.lifetime = lifetime
			if lifetime <= 0 then
				map:destroyObject(id)
			end
		end
	end
end

function Game.fixedUpdate(map, dt)
	for i = 1, #players do
		updatePlayerGun(map, players[i], dt)
	end

	world:update(dt)
	for _, body in pairs(world:getBodies()) do
		local id = body:getUserData()
		local object = map:getObjectById(id)
		if object then
			object:updateFromBody()
		end
	end

	local player1 = players[1]
	local player2 = players[2]
	local x1, y1 = player1.body:getPosition()
	local x2, y2 = player2.body:getPosition()
	local dx, dy = x2-x1, y2-y1
	local dist = sqrt(dx*dx + dy*dy)
	local perpx, perpy = dy/dist, -dx/dist

	local polyline = playerlink.polyline
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

	updateObjectLifetimes(map, dt)
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
