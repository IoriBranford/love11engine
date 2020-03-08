local LA = love.audio
local LFS = love.filesystem
local LG = love.graphics
local json = require "json"
local pl_xml = require "pl.xml"

local Assets = {}

local cache = {}

local load = {}
setmetatable(load, {
	__index = function()
		return LFS.read
	end
})

function load.xml(filename)
	local text, err = load.file(filename)
	if text then
		return pl_xml.parse(text)
	end
	return text, err
end

function load.tmx(filename)
	local doc, err = load.xml(filename)
	if doc then
		local tiled = require "tiled"
		return tiled.load(doc, filename)
	end
	return doc, err
end

load.tsx = load.tmx
load.tx = load.tmx

function load.json(filename)
	local text, err = load.file(filename)
	if text then
		local ok, doc = pcall(json.decode, text)
		if not ok then
			return nil, doc
		end

		if doc.meta and doc.meta.app == "http://www.aseprite.org/" then
			local aseprite = require "aseprite"
			return aseprite.load(doc)
		end
		return doc
	end
	return text, err
end

function load.fnt(filename, ...)
	local ok, font = pcall(LG.newFont, filename, ...)
	if not ok then
		return nil, font
	end
	return font
end

load.ttf = load.fnt
load.otf = load.fnt

function load.defaultFont(filename, ...)
	return LG.newFont(...)
end

function load.png(filename, ...)
	local ok, image = pcall(LG.newImage, filename, ...)
	if not ok then
		return nil, image
	end
	return image
end

function load.lua(filename)
	local module, err = LFS.load(filename)
	if module then
		return module()
	end
	return module, err
end

local function load_audio_stream(filename)
	return LA.newSource(filename, "stream")
end

local function load_audio_guessSourceType(filename)
	local maxsize = 1048576
	local sourcetype = LFS.getInfo(filename).size >= maxsize and "stream"
								or "static"
	return LA.newSource(filename, sourcetype)
end

load.wav = load_audio_guessSourceType
load.ogg = load_audio_guessSourceType
load.xm = load_audio_stream
load.mod = load_audio_stream
load.s3m = load_audio_stream
load.it = load_audio_stream

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
		asset, err = load[ext](filename, ...)
		if err then
			print(filename..': '..err)
		end
		cache[assetname] = asset or false
	end
	return asset
end

return Assets
