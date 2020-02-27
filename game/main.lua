local engine = require "engine"
local LE = love.event
local LFS = love.filesystem
local LJ = love.joystick
local LW = love.window

local config = {
	window_width = 480,
	window_height = 640,
	window_resizable = false,
	window_vsync = -1,
	window_maximize = false
}

function engine.init(args, baseandargs)
	local gamepadfile = "gamecontrollerdb.txt"
	if LFS.getInfo(gamepadfile) then
		LJ.loadGamepadMappings(gamepadfile)
	end

	local window_width = config.window_width
	local window_height = config.window_height
	local window_flags = {
		resizable = config.window_resizable,
		vsync = config.window_vsync
	}
	LW.setMode(window_width, window_height, window_flags)
	LW.setTitle(LFS.getIdentity())
	if config.window_maximize then
		LW.maximize()
	end
	LE.push("load", "shmup.tmx")
end
