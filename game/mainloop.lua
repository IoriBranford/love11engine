local assets = require "assets"

local mainloop = {
	fixedupdaterate = 60,
	fixedupdatelimit = 1
}

local phase = {}
local fixedupdatecounter = 0

local function changephase(nextphase, args)
	if phase.quit then
		phase.quit()
	end
	phase = nil
	collectgarbage()

	phase = require(nextphase)
	if phase.load then
		phase.load(args)
	end
	collectgarbage()

	fixedupdatecounter = 0
	if love.timer then love.timer.step() end
end

function love.run()
	if mainloop.start then
		mainloop.start(love.arg.parseGameArguments(arg), arg)
		collectgarbage()
	end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			local nextphase, nextphaseargs
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if phase.quit then
						phase.quit()
					end
					assets.clear()
					phase = nil
					return a or 0
				elseif name == "nextphase" then
					nextphase = a
					nextphaseargs = {b,c,d,e,f}
				elseif type(phase[name])=="function" then
					phase[name](a,b,c,d,e,f)
				end
			end
			if nextphase then
				changephase(nextphase, nextphaseargs)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

		if phase then
			if phase.fixedupdate then
				fixedupdatecounter = fixedupdatecounter
					+ dt*mainloop.fixedupdaterate
				local n, f = math.modf(fixedupdatecounter)
				n = math.min(n, mainloop.fixedupdatelimit)
				fixedupdatecounter = f
				for i = 1, n do
					phase.fixedupdate()
					collectgarbage("step", 1)
				end
			end

			if phase.update then
				phase.update(dt)
				collectgarbage("step", 1)
			end
		end

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())

			if phase and phase.draw then
				phase.draw(fixedupdatecounter)
				collectgarbage("step", 1)
			end

			love.graphics.present()
		end

		if love.timer then love.timer.sleep(0.001) end
	end
end

return mainloop
