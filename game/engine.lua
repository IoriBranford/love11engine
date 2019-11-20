require("pl.strict")
local pairs = pairs
local type = type
local select = select
local unpack = unpack
local collectgarbage = collectgarbage
local love = love
local min = math.min
local LE = love.event
local LT = love.timer
local LP = love.physics
local LG = love.graphics

local world
local objects = {}
local newobjects = {}
local freeobjects = {}
local objectstofree = {}
local objectsupdate = {}
local objectsfixedUpdate = {}
local nextid = 1
local reload = true

local Object = {}

local Engine = {
	fixedfps = 60
}
Engine.fixeddt = 1/Engine.fixedfps

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

function Engine.newObject(...)
	local object
	if #freeobjects > 0 then
		object = freeobjects[#freeobjects]
		freeobjects[#freeobjects] = nil
	else
		object = {}
	end

	for i = 1, select("#", Object, ...) do
		local template = select(i, Object, ...)
		for k,v in pairs(template) do
			object[k] = v
		end
	end

	local id = nextid
	nextid = nextid + 1
	object.id = id
	newobjects[#newobjects + 1] = object

	return object
end

function Engine.getObject(id)
	return objects[id]
end

function Engine.reload()
	reload = true
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
		local id = object.id
		objects[id] = object
		object:init()

		local update = object.update
		if update then
			objectsupdate[id] = true
		end

		local fixedUpdate = object.fixedUpdate
		if fixedUpdate then
			objectsfixedUpdate[id] = true
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
		if body then
			body:destroy()
		end

		objectsupdate[id] = nil
		objectsfixedUpdate[id] = nil
		objects[id] = nil
		objectstofree[id] = nil
		freeobjects[#freeobjects + 1] = object
	end
end

local function clearObjects()
	for id, _ in pairs(objects) do
		objects[id]:setFree()
	end
	freeObjects()

	world = LP.newWorld()
	world:setCallbacks(beginContact)
end

local function update(dt)
	for id, _ in pairs(objectsupdate) do
		objects[id]:update(dt)
	end
end

local function fixedUpdate(fixeddt)
	for id, _ in pairs(objectsfixedUpdate) do
		objects[id]:fixedUpdate(fixeddt)
	end
	initNewObjects()
	world:update(fixeddt)
	freeObjects()
end

function Engine.debugDrawBoundingBoxes(alpha)
	for _, body in pairs(world:getBodies()) do
		local vx, vy = body:getLinearVelocity()
		for _, fixture in pairs(body:getFixtures()) do
			local x1, y1, x2, y2 = fixture:getBoundingBox()
			local w, h = x2-x1, y2-y1
			x1 = x1 + vx*alpha
			y1 = y1 + vy*alpha
			LG.rectangle("line", x1, y1, w, h)
		end
	end
end

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
	if LT then LT.step() end

	local dt = 0
	local timeaccum = 0

	-- Main loop time.
	return function()
		if reload then
			clearObjects()
			if love.reload then love.reload() end
			collectgarbage()
			reload = false
			if LT then LT.step() end
		end

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

		update(dt)

		timeaccum = timeaccum + dt
		local fixeddt = Engine.fixeddt
		while timeaccum >= fixeddt do
			fixedUpdate(fixeddt)
			timeaccum = timeaccum - fixeddt
		end

		if LG and LG.isActive() then
			LG.origin()
			if love.draw then love.draw(timeaccum) end
			LG.present()
		end

		if LT then LT.sleep(0.001) end
		collectgarbage("step", 2)
	end
end

return Engine
