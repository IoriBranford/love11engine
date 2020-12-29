--- Aseprite export settings
-- Output
--  JSON Data = true
--   Meta:
--    Layers = true if data format = Hash
--    Tags = true for animations
--   Item filename = {layer}:{frame1}

local Assets = require "assets"
local LG = love.graphics

local Aseprite = {}
Aseprite.__index = Aseprite

function Aseprite:newSpriteBatch(animation)
	local nlayers = #self.layers
	local spritebatch = LG.newSpriteBatch(self.image, nlayers, "dynamic")
	for i = 1, nlayers do
		spritebatch:add(0,0,0,0,0)
	end

	if self.animations[animation] then
		self:startSpriteBatchAnimation(spritebatch, animation)
	else
		self:setSpriteBatchFrame(spritebatch, 1)
	end
	return spritebatch
end

function Aseprite:startSpriteBatchAnimation(spritebatch, animation)
	animation = self.animations[animation]
	if animation then
		self:setSpriteBatchFrame(spritebatch, animation[1])
	end
end

function Aseprite:setSpriteBatchFrame(spritebatch, frame)
	local offsetx = self.offsetx
	local offsety = self.offsety
	frame = self[frame]
	for i = 1, #self.layers do
		local cel = frame[i]
		if cel then
			spritebatch:set(i, cel.quad, cel.x - offsetx, cel.y - offsety)
		else
			spritebatch:set(i, 0, 0, 0, 0, 0)
		end
	end
end

function Aseprite:animateSpriteBatch(spritebatch, animation, aniframe, msecs, dmsecs)
	local af = aniframe
	msecs = msecs + dmsecs
	animation = self.animations[animation]
	if not animation then
		return af, msecs
	end
	local duration = self[animation[af]].duration
	while msecs >= duration do
		msecs = msecs - duration
		af = (af == #animation) and 1 or (af + 1)
		duration = self[animation[af]].duration
	end
	if aniframe ~= af then
		self:setSpriteBatchFrame(spritebatch, animation[af])
	end
	return af, msecs
end

function Aseprite:setAnchor(anchorx, anchory)
	self.offsetx = anchorx*self.width
	self.offsety = anchory*self.height
end

local function load_cel(cel, filename, ase, layers, image)
	local layername, framei = filename:match("(.-):(%d+)")
	local layeri = layers[layername]
	if not layeri then
		layers[#layers+1] = { name = layername }
		layeri = #layers
		layers[layername] = layeri
	end

	framei = tonumber(framei)
	local frame = ase[framei]
	if not frame then
		frame = { duration = cel.duration }
		ase[framei] = frame
	end

	local rect = cel.frame
	local pos = cel.spriteSourceSize
	frame[layeri] = {
		x = pos.x,
		y = pos.y,
		quad = LG.newQuad(rect.x, rect.y, rect.w, rect.h,
				image:getWidth(), image:getHeight())
	}

	local size = cel.sourceSize
	ase.width = size.w
	ase.height = size.h
end

local function loadAseprite(doc, anchorx, anchory)
	local cels = doc.frames
	local meta = doc.meta
	local image = meta.image
	image = Assets.get(image)
	image:setFilter("nearest", "nearest")

	local layers = meta.layers
	if not cels[1] and not layers then
		return nil, "Aseprite "..image.." was exported with hash frames and no layer list. There is no way to ensure the correct layer order."
	end

	layers = layers or {}

	for i = 1, #layers do
		layers[layers[i].name] = i
	end

	local ase = {}
	if cels[1] then
		for i = 1, #cels do
			local cel = cels[i]
			load_cel(cel, cel.filename, ase, layers, image)
		end
	else
		for k,v in pairs(cels) do
			load_cel(v, k, ase, layers, image)
		end
	end

	local animations = meta.frameTags
	for i = 1, #animations do
		local animation = animations[i]
		animations[animation.name] = animation
		animation.from = animation.from + 1
		animation.to = animation.to + 1
		local direction = animation.direction
		if direction == "reverse" then
			for f = animation.to, animation.from do
				animation[#animation + 1] = f
			end
		else
			for f = animation.from, animation.to do
				animation[#animation + 1] = f
			end
			if direction == "pingpong" then
				for f = animation.to-1, animation.from+1 do
					animation[#animation + 1] = f
				end
			end
		end
	end
	for i = #animations, 1, -1 do
		animations[i] = nil
	end

	ase.image = image
	ase.layers = layers
	ase.animations = animations
	
	setmetatable(ase, Aseprite)
	anchorx = anchorx or 0
	anchory = anchory or 0
	ase:setAnchor(anchorx, anchory)
	return ase
end

return {
	load = loadAseprite
}
