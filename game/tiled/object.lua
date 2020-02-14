local pairs = pairs
local assets = require "assets"
local tablex = require "pl.tablex"

local Object = {}

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

return Object
