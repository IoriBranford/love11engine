local cocreate = coroutine.create
local coresume = coroutine.resume
local costatus = coroutine.status
local coyield = coroutine.yield

local Coroutines = {}

function Coroutines:add(id, f)
	self.newCoroutines[id] = cocreate(f)
end

function Coroutines:update(...)
	local coroutines = self.coroutines
	local newCoroutines = self.newCoroutines

	for id, co in pairs(coroutines) do
		coresume(co, id, ...)
		if costatus(co) == "dead" then
			coroutines[id] = nil
		end
	end

	for id, co in pairs(newCoroutines) do
		coroutines[id] = co
		newCoroutines[id] = nil
	end
end

function Coroutines:remove(id, signal, ...)
	local co = self.coroutines[id]
	if co and signal then
		coresume(co, id, signal, ...)
	end
	self.coroutines[id] = nil
	self.newCoroutines[id] = nil
end

return function()
	local coroutines = {
		coroutines = {},
		newCoroutines = {}
	}
	for k,f in pairs(Coroutines) do
		coroutines[k] = f
	end
	return coroutines
end
