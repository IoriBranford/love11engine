local pairs = pairs
local type = type
local atan2 = math.atan2
local assets = require "assets"
local tablex = require "pl.tablex"
local LM = love.math
local LP = love.physics

local Object = {}
Object.__index = Object

local function getGlobalTransform(object)
	local parent = object.parent
	local transform = object.transform
	if not parent then
		return transform and transform:clone() or LM.newTransform()
	end
	local globaltransform = getGlobalTransform(parent)
	return transform and globaltransform:apply(transform) or globaltransform
end
Object.getGlobalTransform = getGlobalTransform

local function getGlobalPosition(object, x, y)
	x = x or 0
	y = y or 0
	local parent = object.parent
	if parent then
		x, y = getGlobalPosition(parent, x, y)
	end
	local transform = object.transform
	if transform then
		x, y = transform:transformPoint(x, y)
	end
	return x, y
end
Object.getGlobalPosition = getGlobalPosition

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
	local newtransform = getGlobalTransform(object)
	if parent then
		newtransform = getGlobalTransform(parent):inverse():apply(newtransform)
		parent[#parent+1] = object
	end
	object.parent = parent
	object.transform = newtransform
end

function Object.setTemplate(object, template)
	if type(template) == "string" then
		template = assets.get(template)
	end
	object.template = template
	local gid = object.gid or 0
	tablex.update(object, template)
	local templateproperties = template.properties
	if templateproperties then
		local properties = object.properties or {}
		object.properties = properties
		for k, v in pairs(templateproperties) do
			if properties[k] == nil then
				properties[k] = v
			end
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
