local pairs = pairs
local type = type
local unpack = unpack
local collectgarbage = collectgarbage
local floor = math.floor
local love = love
local LE = love.event
local LT = love.timer
local LP = love.physics
local LG = love.graphics

local world
local objects = {}
local newobjects = {}
local freeobjects = {}
local objectstofree = {}
local objectsthink = {}
local nextid = 1

local Object = {}

function Object:init()
end

function Object:beginContact()
end

function Object:newBody()
	local body = self.body
	if body then
		body:destroy()
	end
	body = LP.newBody(world, self.x, self.y, self.bodytype)
	body:setFixedRotation(true)
	body:setUserData(self.id)
	local velx = self.velx or 0
	local vely = self.vely or 0
	body:setLinearVelocity(velx, vely)
	self.body = body
	return body
end

function Object:setFree(free)
	objectstofree[self.id] = free or true
end

local Engine = {}

function Engine.newObject(template)
	local object
	if #freeobjects > 0 then
		object = freeobjects[#freeobjects]
		freeobjects[#freeobjects] = nil
	else
		object = { id = nextid }
		nextid = nextid + 1
	end

	for k,v in pairs(Object) do
		object[k] = v
	end

	if template then
		for k,v in pairs(template) do
			object[k] = v
		end
	end

	local id = object.id
	objects[id] = object
	newobjects[#newobjects + 1] = object

	return object
end

function Engine.getObject(id)
	return objects[id]
end

local function beginContact(f1, f2, contact)
	local b1 = f1:getBody()
	local b2 = f2:getBody()
	local id1 = b1:getUserData()
	local id2 = b2:getUserData()
	local object1 = objects[id1]
	local object2 = objects[id2]
	object1:beginContact(object2)
	object2:beginContact(object1)
end

local function initNewObjects()
	local i = 1
	while i <= #newobjects do
		local object = newobjects[i]
		object:init()

		local id = object.id
		local think = object.think
		if think then
			objectsthink[id] = true
			think(object)
		end

		i = i + 1
	end

	for i = #newobjects, 1, -1 do
		newobjects[i] = nil
	end
end

local function freeObjects()
	for id, _ in pairs(objectstofree) do
		local object = objects[id]
		local body = object.body
		for k, _ in pairs(object) do
			object[k] = nil
		end
		object.id = id
		if body then
			body:destroy()
		end

		objectsthink[id] = nil
		objects[id] = nil
		objectstofree[id] = nil
		freeobjects[#freeobjects + 1] = object
	end
end

local function clearObjects()
	for id, _ in pairs(objects) do
		object:markFree()
	end
	freeObjects()

	world = LP.newWorld()
	world:setCallbacks(beginContact)
end

local function update()
	for id, _ in pairs(objectsthink) do
		objects[id]:think()
	end
	initNewObjects()
	world:update(1)
	freeObjects()
end

local function drawBoxes(fraction)
	LG.setLineStyle("rough")
	LG.getFont():setFilter("nearest", "nearest")
	LG.scale(2)
	for _, body in pairs(world:getBodies()) do
		local vx, vy = body:getLinearVelocity()
		for _, fixture in pairs(body:getFixtures()) do
			local x1, y1, x2, y2 = fixture:getBoundingBox()
			local w, h = x2-x1, y2-y1
			x1 = x1 + vx*fraction
			y1 = y1 + vy*fraction
			LG.rectangle("line", x1, y1, w, h)
		end
	end
end

function love.run()
	clearObjects()

	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if LT then LT.step() end

	local worldfps = 60
	local dt = 0
	local timeaccum = 0
	local drawingstats = {}

	-- Main loop time.
	return function()
		-- Process events.
		if LE then
			LE.pump()
			for name, a,b,c,d,e,f in LE.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		if LT then dt = LT.step() end

		timeaccum = timeaccum + dt
		local fixeddt = 1/worldfps
		while timeaccum >= fixeddt do
			update()
			timeaccum = timeaccum - fixeddt
		end

		if LG and LG.isActive() then
			LG.origin()
			LG.clear(LG.getBackgroundColor())

			drawBoxes(timeaccum*worldfps)

			LG.origin()
			local font = LG.getFont()
			local fps = LT.getFPS()
			local lgw = LG.getWidth()
			local mem = floor(collectgarbage("count"))
			LG.printf(fps.." fps", 0, 0, lgw, "right")
			LG.printf(mem.." kb", 0, font:getHeight(), lgw, "right")
			LG.present()
		end

		if LT then LT.sleep(0.001) end
		collectgarbage("step", 2)
	end
end

return Engine
