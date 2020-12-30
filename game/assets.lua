local LA = love.audio
local LFS = love.filesystem
local LG = love.graphics

local Assets = {}

local cache = {}

local loaders = {}
setmetatable(loaders, {
	__index = function()
		return LFS.read
	end
})

function loaders.xml(filename)
	local text, err = loaders.file(filename)
	if not text then
		return text, err
	end

	local slaxdom = require "slaxdom"
	local doc = slaxdom:dom(text)
	return doc
end
--[[
function loaders.tmx(filename)
	local doc, err = loaders.xml(filename)
	if not doc then
		return doc, err
	end

	local cwd = filename:match("(.*/)") or ""
	local tiled = require "tiled"
	tiled.parsedocument(doc, cwd)
end
loaders.tsx = loaders.tmx
loaders.tx = loaders.tmx
]]
function loaders.json(filename)
	local text, err = loaders.file(filename)
	if text then
		local json = require "json"
		local ok, doc = pcall(json.decode, text)
		if not ok then
			return nil, doc
		end

		local cwd = filename:match("(.*/)") or ""
		if doc.meta and doc.meta.app == "http://www.aseprite.org/" then
			local aseprite = require "aseprite"
			return aseprite.load(doc, cwd)
		end
		if doc.tiledversion or doc.type == "template" then
			local tiled = require "tiled"
			return tiled.loadelement(doc, cwd)
		end
		return doc
	end
	return text, err
end

function loaders.fnt(filename, ...)
	local ok, font = pcall(LG.newFont, filename, ...)
	if not ok then
		return nil, font
	end
	return font
end

loaders.ttf = loaders.fnt
loaders.otf = loaders.fnt

function loaders.defaultFont(filename, ...)
	return LG.newFont(...)
end

function loaders.png(filename, ...)
	local ok, image = pcall(LG.newImage, filename, ...)
	if not ok then
		return nil, image
	end
	return image
end

function loaders.lua(filename)
	local code, err = LFS.load(filename)
	if code then
		return code()
	end
	return code, err
end

local function load_audio_stream(filename)
	return LA.newSource(filename, "stream")
end

local function load_audio(filename, sourcetype)
	if not sourcetype then
		local maxsize = 1048576
		sourcetype = LFS.getInfo(filename).size >= maxsize
			and "stream" or "static"
	end
	return LA.newSource(filename, sourcetype)
end

loaders.wav = load_audio
loaders.ogg = load_audio
loaders.xm = load_audio_stream
loaders.mod = load_audio_stream
loaders.s3m = load_audio_stream
loaders.it = load_audio_stream

local function assetName(filename, ...)
	local assetname = filename
	for i = 1, select('#', ...) do
		assetname = assetname.."&"..tostring(select(i, ...))
	end
	return assetname
end

function Assets.free(filename, ...)
	cache[assetName(filename, ...)] = nil
end

function Assets.clear()
	for assetname, _ in pairs(cache) do
		cache[assetname] = nil
	end
end

function Assets.canPreload(filename)
	local ext = filename:match('%.(%w-)$')
	return ext and ext ~= "tmx"
end

function Assets.get(filename, ...)
	if not filename then
		return
	end
	local assetname = assetName(filename, ...)
	local asset = cache[assetname]
	if asset == nil then
		local ext = filename:match('%.(%w-)$') or "file"
		local err
		asset, err = loaders[ext](filename, ...)
		if err then
			print(filename..': '..err)
		end
		cache[assetname] = asset or false
		--DEBUG
		--if asset then print(assetname) end
	end
	return asset
end

function Assets.put(assetname, asset)
	cache[assetname] = asset
end

return Assets
