--- Ship
--@field group layer it originated from
--@field bodywidth default 32
--@field bodyheight default 32
--@field bodyshape
--@field bodyradius for circle shape
--@field bodycategory
--@field bodysensor
--@field explodeforce
--@field explodetime
--@field firebullet
--@field fireinterval
--@field health
--@field killsound
--@table Ship

local pi = math.pi
local cos = math.cos
local sin = math.sin
local abs = math.abs
local atan2 = math.atan2
local min = math.min
local sqrt = math.sqrt
local LJ = love.joystick
local LK = love.keyboard
local LM = love.math
local LP = love.physics
local audio = require "audio"
local find = require "tiled.find"
local tablex = require "pl.tablex"

local Ship = {}

local enemies

local function newHalo(ship, map)
	local polygon = ship.polygon
	if not polygon then
		return
	end
	local maxx, maxy = 0, 0
	for i = 1, #polygon-1, 2 do
		local x = polygon[i]
		local y = polygon[i+1]
		if abs(x) > abs(maxx) and abs(y) > abs(maxy) then
			maxx = x
			maxy = y
		end
	end
	local radius = sqrt(maxx*maxx + maxy*maxy)
	local halo = map:newObject(ship)
	ship.halo = halo
	halo.radius = radius
	local playerlink = map.playerlink
	halo.linecolor = playerlink and playerlink.linecolor
	halo.explodeforce = ship.explodeforce or 15
	halo.explodetime = ship.explodetime or .25
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
	return halo
end

local function makeThunder(polyline, numpoints, dx, dy)
	local dist = sqrt(dx*dx + dy*dy)
	local perpx, perpy = dy/dist, -dx/dist
	polyline[1] = 0
	polyline[2] = 0
	local n = 2*numpoints
	for i = 3, n-3, 2 do
		local rand = (LM.random()*2 - 1) * 8
		local t = i/n
		local x = dx*t + perpx*rand
		local y = dy*t + perpy*rand
		polyline[i  ] = x
		polyline[i+1] = y
	end
	polyline[n-1] = dx
	polyline[n  ] = dy
	return polyline
end
Ship.makeThunder = makeThunder

local function initShip(ship, newparent)
	local move = ship.move
	ship.move = Ship["move_"..move]
	ship.time = 0
	ship.timeleft = ship.lifetime
	ship.group = ship.parent
	ship:setParent(newparent)
end
Ship.init = initShip

local function newShip(map, template, x, y, move)
	local ship = map:newTemplateObject(enemies, template)
	ship.x = x
	ship.y = y
	ship.move = move or ship.move
	initShip(ship)
	return ship
end

local function explodeLines(object, map)
	local polygon, linecolor = object.polygon, object.linecolor
	if not polygon or not linecolor then
		return
	end
	local x, y, parent, force, lifetime = object.x, object.y,
		object.parent, object.explodeforce, object.explodetime
	local world = map.world
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
		shard.bodytype = "dynamic"
		shard.velx, shard.vely = force*cx, force*cy
		shard.velr = force*pi
	end
end

local function explodeTriangles(object, map)
	local polygon, fillcolor = object.polygon, object.fillcolor
	if not polygon or not fillcolor then
		return
	end
	local tris = object.triangles or LM.triangulate(polygon)
	local x, y, parent, force, lifetime = object.x, object.y,
		object.parent, object.explodeforce, object.explodetime
	local world = map.world
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
		shard.bodytype = "dynamic"
		shard.velx, shard.vely = force*cx, force*cy
		shard.velr = force*pi
	end
end

local function knockoutShip(ship, map)
	audio.play(ship.killsound)
	explodeLines(ship, map)
	explodeTriangles(ship, map)
end

local function killShip(ship, map)
	for i = #ship, 1, -1 do
		local child = ship[i]
		child:setParent(ship.parent)
		killShip(child, map)
	end
	audio.play(ship.killsound)
	explodeLines(ship, map)
	explodeTriangles(ship, map)
	map:destroyObject(ship.id)
end
Ship.kill = killShip

local function getPlayerLinkPosition(ship, player1, player2)
	if not player1 or not player2 then
		return
	end

	local ex, ey = ship.x, ship.y
	local p1x, p1y = player1.x, player1.y
	local p2x, p2y = player2.x, player2.y
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
	local radius = ship.radius or 16
	if rejsq > radius*radius then
		return
	end
	return pos
end

local function haloCrackle(halo)
	local radius = halo.radius
	local polygon = halo.polygon
	local numpoints = #polygon/2
	local angle = pi/2
	local dangle = 2*pi/numpoints
	for i = 1, #polygon-1, 2 do
		local x = cos(angle)
		local y = sin(angle)
		local rand = (LM.random()*2 - 1) * 8
		local r = radius + rand
		x = x*r
		y = y*r

		polygon[i] = x
		polygon[i+1] = y
		angle = angle + dangle
	end
end

local function move_thrown(ship, map, dt)
	haloCrackle(ship.halo)
end

local move_zap
local function zapShip(ship, map)
	if ship.move == move_zap then
		return
	end
	ship.timeleft = nil
	ship.nextmove = ship.move
	ship.move = move_zap
	ship.time = 0
	local body = ship.body
	ship.body:setLinearVelocity(0, 0)
	ship.body:setAngularVelocity(0)
	for _, fixture in pairs(body:getFixtures()) do
		fixture:setUserData("zap")
	end

	local playerlink = map.playerlink
	local x, y = body:getPosition()
	local color = playerlink and playerlink.linecolor
	ship.linecolor = color
	ship.fillcolor = color

	local thunder = map:newObject(map)
	thunder.x, thunder.y = x, y
	thunder.linecolor = color
	thunder.polyline = {}
	thunder.visible = false
	if playerlink then
		audio.play(playerlink.zapsound)
	end
	ship.thunder = thunder

	ship.halo = ship.halo or newHalo(ship, map)
end

move_zap = function(ship, map, dt)
	local world = map.world
	local zappedid = ship.zappedid

	haloCrackle(ship.halo)

	if not zappedid then
		local x, y = ship.body:getPosition()
		local nearestdsq = math.huge
		world:queryBoundingBox(ship.x - 640, ship.y - 480,
			ship.x + 640, ship.y + 480,
			function(fixture)
				local category = fixture:getUserData()
				if category ~= "enemy" and category ~= "enemyshot" then
					return true
				end
				local body = fixture:getBody()
				local id = body:getUserData()
				local x2, y2 = body:getPosition()
				local dx, dy = x2-x, y2-y
				local dsq = dx*dx + dy*dy
				if nearestdsq <= dsq then
					return true
				end
				nearestdsq = dsq
				zappedid = id
				return true
			end)
	end

	local zappedenemy = zappedid and map:getObjectById(zappedid)
	if zappedenemy then
		local x, y = ship.body:getPosition()
		local ex, ey = zappedenemy.body:getPosition()
		makeThunder(ship.thunder.polyline, 8, ex-x, ey-y)
		ship.thunder.visible = true
		if ship.time >= 5/60 then
			zapShip(zappedenemy, map)
		end
	else
		zappedid = nil
		ship.thunder.visible = false
	end

	ship.zappedid = zappedid

	if ship.time >= .5 then
		map:destroyObject(ship.thunder)
		killShip(ship, map)
	end
end

local function move_held(ship, map, dt)
	local player1 = map.players[1]
	local player2 = map.players[2]
	if not player1 or not player2 then
		killShip(ship, map)
		return
	end

	local ex, ey = ship.x, ship.y
	local p1x, p1y = player1.x, player1.y
	local p2x, p2y = player2.x, player2.y
	local dx, dy = p2x-p1x, p2y-p1y

	local playerlinkpos = ship.playerlinkpos
	if playerlinkpos < .1 then
		playerlinkpos = playerlinkpos + dt
	elseif playerlinkpos > .9 then
		playerlinkpos = playerlinkpos - dt
	end
	ship.playerlinkpos = playerlinkpos

	local destx = p1x + dx*playerlinkpos
	local desty = p1y + dy*playerlinkpos
	local vx = (destx - ex)*30
	local vy = (desty - ey)*30
	ship.body:setLinearVelocity(vx, vy)

	local angle = atan2(-dx, dy)
	ship.body:setAngle(angle)
	--local av = (destangle - angle)*30

	haloCrackle(ship.halo)

	local fire = player1.fire + player2.fire
	if fire >= 2 then
		zapShip(ship, map)
	end
end

local function move_defeated(ship, map, dt)
	local playerlinkpos = getPlayerLinkPosition(ship, map.players[1], map.players[2])

	if playerlinkpos then
		ship.move = move_held
		ship.playerlinkpos = playerlinkpos
		for _, fixture in pairs(ship.body:getFixtures()) do
			fixture:setUserData("held")
		end
		ship.body:setLinearVelocity(0, 0)
		ship.body:setAngularVelocity(0)
		ship.timeleft = 10
		local playerlink = map.playerlink
		ship.fillcolor = playerlink and playerlink.linecolor

		newHalo(ship, map)
	else
		ship.body:applyForce(0, 120)
	end
end

local function defeatShip(ship, map)
	if ship.move == move_defeated then
		return
	end
	knockoutShip(ship, map)
	local body = ship.body
	if ship.x < 320 then
		body:setLinearVelocity(120, 0)
		body:setAngularVelocity(pi)
	else
		body:setLinearVelocity(-120, 0)
		body:setAngularVelocity(-pi)
	end
	for _, fixture in pairs(body:getFixtures()) do
		fixture:setUserData("defeated")
	end
	ship.time = 0
	ship.linecolor = nil
	local fillcolor = ship.fillcolor
	if fillcolor then
		ship.fillcolor = {
			fillcolor[1]/2,
			fillcolor[2]/2,
			fillcolor[3]/2
		}
	end
	ship.move = move_defeated
	if #map.players > 0 then
		ship:setParent(map.players[1].parent)
	end
	return ship
end
Ship.defeat = defeatShip

local function lineStartsAt(node, x, y)
	local polyline = node.polyline
	if not polyline then
		return false
	end
	local rotation = node.rotation
	local cosr = cos(rotation)
	local sinr = sin(rotation)
	local x1 = polyline[1]
	local y1 = polyline[2]
	x1, y1 = x1*cosr - y1*sinr, x1*sinr + y1*cosr
	local dx = (x1 + node.x - x)
	local dy = (y1 + node.y - y)
	return abs(dx) < 1 and abs(dy) < 1
end

local function getAimedPlayer(x, p1, p2)
	return x >= 320 and p2 or p1
end

local function face(ship, map, dt)
	local x, y = ship.x, ship.y
	local player = getAimedPlayer(x, map.players[1], map.players[2])
	if not player then
		return
	end
	local angle = atan2(player.y - y, player.x - x)
	ship.body:setAngle(angle)
	return angle
end

local function fireBullet_XY(map, ship, template, vx, vy, angle)
	local bullet = map:newTemplateObject(ship, template)
	bullet.fillcolor = tablex.copy(ship.fillcolor)
	bullet.linecolor = tablex.copy(ship.linecolor)
	bullet.timeleft = bullet.lifetime
	bullet:setParent(ship.parent)
	bullet.rotation = angle or atan2(vy, vx)
	bullet.velx, bullet.vely = vx, vy
end

local function fireBullet_SpeedAngle(map, ship, template, speed, angle)
	fireBullet_XY(map, ship, template, speed*cos(angle), speed*sin(angle), angle)
end

local function enemyFire(ship, map, dt)
	local angle = face(ship, map, dt)
	if not angle then
		return
	end

	local firebullet = ship.firebullet
	if not firebullet then
		return
	end

	local interval = ship.fireinterval or 1
	local firetime = ship.firetime or interval
	firetime = firetime - dt
	if firetime <= 0 then
		fireBullet_SpeedAngle(map, ship, firebullet, 360, angle)
		firetime = firetime + interval
	end
	ship.firetime = firetime
end

function Ship.move_beziercurve(ship, map, dt)
	local x, y = ship.x, ship.y
	local path = map.objectsbyid[ship.beziercurveid]
	if not path then
		path = find.custom(ship.group, lineStartsAt, x, y)
		if not path then
			return
		end
		ship.beziercurveid = path.id
	end
	local polyline = path.polyline
	if not polyline then
		return
	end
	local curve = path.beziercurve
	if not curve then
		curve = LM.newBezierCurve(polyline)
		curve:rotate(path.rotation)
		curve:translate(path.x, path.y)
		path.beziercurve = curve
	end
	local pathtime = ship.beziercurvetime or 1
	local t = min(ship.time/pathtime, 1)
	local px, py = curve:evaluate(t)
	local vx, vy = (px-x)/dt, (py-y)/dt
	ship.body:setLinearVelocity(vx, vy)
	enemyFire(ship, map, dt)
	if t >= 1 then
		map:destroyObject(ship.id)
		map:destroyObject(ship.beziercurveid)
	end
end

function Ship.move_player(ship, map, dt)
	if ship.visible == false then
		return
	end
	local movestick = ship.movestick or "left"
	local movekeys = ship.movekeys or "a,d,w,s"
	local firetrigger = ship.firetrigger or "left"
	local firekey = ship.firekey or "space"
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
	ship.fire = fire
	local alen = sqrt(ax*ax + ay+ay)
	if alen > 1 then
		ax = ax/alen
		ay = ay/alen
	end

	local speed = ship.speed or 300
	ship.body:setLinearVelocity(ax*speed, ay*speed)

	local firewait = ship.firewait or dt
	firewait = firewait - dt
	if firewait <= 0 then
		fireBullet_SpeedAngle(map, ship, "playershot.tx", 16*60, -pi/2)
		firewait = firewait + 1/10
	end
	ship.firewait = firewait
end

function Ship.damage(ship, map, damage)
	local health = ship.health or 1
	damage = damage or 1
	if health then
		health = health-damage
		ship.health = health
		if health <= 0 then
			return defeatShip(ship, map)
		end
	end
end

return Ship
