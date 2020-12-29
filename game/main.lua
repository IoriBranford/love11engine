require "xmath"
local prefs = require "prefs"
local mainloop = require "mainloop"
local LE = love.event
local LFS = love.filesystem
local LJ = love.joystick
local LW = love.window

function mainloop.start(args, baseandargs)
	local gamepadfile = "gamecontrollerdb.txt"
	if LFS.getInfo(gamepadfile) then
		LJ.loadGamepadMappings(gamepadfile)
	end

	local window_width = prefs.window_width
	local window_height = prefs.window_height
	local window_flags = {
		fullscreen = prefs.window_fullscreen,
		resizable = prefs.window_resizable,
		vsync = prefs.window_vsync
	}
	LW.setMode(window_width, window_height, window_flags)
	LW.setTitle(LFS.getIdentity())
	if prefs.window_maximize then
		LW.maximize()
	end
	LE.push("nextphase", "shmup")
end
