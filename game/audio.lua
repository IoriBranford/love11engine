local assets = require "assets"

local Audio = {}

local function newSource(filename, sourcetype)
	local sounddata = assets.get(filename, sourcetype)
	return sounddata:clone()
end
Audio.newSource = newSource

function Audio.play(filename, sourcetype)
	local source = newSource(filename, sourcetype or "static")
	if source then
		source:play()
	end
	return source
end

return Audio
