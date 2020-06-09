local pairs = pairs
local type = type
local sqrt = math.sqrt
local atan2 = math.atan2
local cos = math.cos
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
	local parent = object.parent
	if parent then
		getGlobalTransform(parent, globaltransform)
	end
	globaltransform:translate(object.x or 0, object.y or 0)
	globaltransform:rotate(object.rotation or 0)
	globaltransform:scale(object.scalex or 1, object.scaley or 1)
	return globaltransform
end
Object.getGlobalTransform = getGlobalTransform

local setParent_global = LM.newTransform()
local setParent_parentglobal = LM.newTransform()

function Object.setParent(object, newparent)
	local oldparent = object.parent
	if newparent == oldparent then
		return
	end
	if oldparent then
		for i = 1, #oldparent do
			if oldparent[i] == object then
				table.remove(oldparent, i)
				break
			end
		end
	end

	local newtransform = getGlobalTransform(object, setParent_global:reset())

	if newparent then
		getGlobalTransform(newparent, setParent_parentglobal:reset())
		newtransform = setParent_parentglobal:inverse()
		newtransform:apply(setParent_global)
		newparent[#newparent+1] = object
	end

	local xx, yx, zx, x, xy, yy, zy, y = newtransform:getMatrix()
	object.x = x
	object.y = y
	object.rotation = atan2(xy, xx)
	object.scalex = sqrt(xx*xx + xy*xy)
	object.scaley = sqrt(yx*yx + yy*yy)
	object.parent = newparent
end

function Object.setTemplate(object, template)
	if type(template) == "string" then
		template = assets.get(template)
	end
	object.template = template
	local gid = object.gid or 0
	for k, v in pairs(template) do
		local t = type(v)
		if t == "lightuserdata" or t == "userdata" then

		elseif object[k] == nil then
			if type(v) == "table" then
				v = tablex.deepcopy(v)
			end
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
	local body = LP.newBody(world, object.x, object.y, bodytype)
	body:setAngle(object.rotation)
	body:setUserData(object.id)
	object.body = body
	return body
end

function Object.updateFromBody(object)
	local body = object.body
	if body then
		object.x, object.y = body:getPosition()
		object.rotation = body:getAngle()
	end
end

function Object.onDestroy(object)
	local parent = object.parent
	for i = 1, #object do
		local child = object[i]
		if child and child.setParent then
			child:setParent(parent)
		end
	end
	object:setParent()
	local body = object.body
	object.body = nil
	if body and not body:isDestroyed() then
		body:setUserData(nil)
		body:destroy()
	end
end

return Object
