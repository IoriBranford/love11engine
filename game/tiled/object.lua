local pairs = pairs
local type = type
local atan2 = math.atan2
local assets = require "assets"
local tablex = require "pl.tablex"
local LM = love.math
local LP = love.physics

local Object = {}
Object.__index = Object

local function getGlobalTransform(object, globaltransform)
	if not object then
		return
	end
	globaltransform = globaltransform or LM.newTransform()
	local parent = object.parent
	if parent then
		getGlobalTransform(parent, globaltransform)
	end
	local transform = object.transform
	if transform then
		globaltransform:apply(transform)
	end
	return globaltransform
end
Object.getGlobalTransform = getGlobalTransform

local function getGlobalPosition(object, x, y)
	x = x or 0
	y = y or 0
	if not object then
		return x, y
	end
	local transform = object.transform
	if transform then
		x, y = transform:inverseTransformPoint(x, y)
	end
	local parent = object.parent
	if parent then
		return getGlobalPosition(parent, x, y)
	end
	return x, y
end
Object.getGlobalPosition = getGlobalPosition

local setParent_global = LM.newTransform()
local setParent_parentglobal = LM.newTransform()

function Object.setParent(object, parent)
	local oldparent = object.parent
	if oldparent then
		for i = 1, #oldparent do
			if oldparent[i] == object then
				table.remove(oldparent, i)
				break
			end
		end
	end

	local transform = object.transform or LM.newTransform()
	object.transform = transform
	local newtransform = getGlobalTransform(object, setParent_global:reset())

	if parent then
		getGlobalTransform(parent, setParent_parentglobal:reset())
		newtransform = setParent_parentglobal:inverse()
		newtransform:apply(setParent_global)
		parent[#parent+1] = object
	end

	transform:setMatrix(newtransform:getMatrix())
	object.parent = parent
end

function Object.setTemplate(object, template)
	if type(template) == "string" then
		template = assets.get(template)
	end
	object.template = template
	local gid = object.gid or 0
	for k, v in pairs(template) do
		if object[k] == nil then
			object[k] = v
		end
	end

	-- template instance's gid may override the template's gid
	-- with different flip flags
	-- (Tiled bug: if template's tileset is not also in the map,
	-- overriding gid is 0)
	if gid > 0 then
		object.gid = gid
		object.tileset = nil
	end
end

function Object.setAseprite(object, aseprite, animation, anchorx, anchory)
	if type(aseprite) == "string" then
		aseprite = assets.get(aseprite)
	end
	anchorx = anchorx or 0
	anchory = anchory or 0
	object.aseprite = aseprite
	aseprite:setAnchor(anchorx, anchory)
	object.spritebatch = aseprite:newSpriteBatch(animation)
	object.animation = animation
	object.animationmsecs = 0
	object.animationframe = 1
end

function Object.addBody(object, world, bodytype)
	local parent = object.parent
	if parent then
		local px, py = getGlobalPosition(parent)
		if px ~= 0 or py ~= 0 then
			print("Warning: parent transform will not apply to physics body")
		end
	end

	local transform = getGlobalTransform(object)
	local xx, yx, zx, x, xy, yy, zy, y = transform:getMatrix()
	local r = atan2(xy, xx)
	local body = LP.newBody(world, x, y, bodytype)
	body:setAngle(r)
	body:setUserData(object.id)
	object.body = body
	object:updateFromBody()
	return body
end

function Object.updateFromBody(object)
	local body = object.body
	if body then
		local x, y = body:getPosition()
		local r = body:getAngle()
		local transform = object.transform or LM.newTransform()
		object.transform = transform
		transform:setTransformation(x, y, r)
	end
end

function Object.onDestroy(object)
	object:setParent()
	local body = object.body
	if body then
		body:setUserData(nil)
		body:destroy()
	end
end

return Object
