local sort = table.sort

local objectswithupdate = {}
local objectswithdraw = {}
local sortedobjectswithupdate = {}
local sortedobjectswithdraw = {}
local objectstoadd = {}
local objectstoremove = {}

local function compareupdate(object1, object2)
	local prio1 = object1.updatepriority or math.huge
	local prio2 = object2.updatepriority or math.huge
	return prio1 < prio2
end

local function comparedraw(object1, object2)
	local prio1 = object1.drawpriority or math.huge
	local prio2 = object2.drawpriority or math.huge
	return prio1 < prio2
end

function addObject(object)
	objectstoadd[object] = true
end

function removeObject(object)
	objectstoremove[object] = true
end

local function sortObjects(sorted, objects, compare)
	local i = 1
	for object, _ in pairs(objects) do
		sorted[i] = object
		i = i + 1
	end
	for j = #sorted, i, -1 do
		sorted[j] = nil
	end
	sort(sorted, compare)
end

function updateObjects(...)
	sortObjects(sortedobjectswithupdate, objectswithupdate, compareupdate)
	for i = 1, #sortedobjectswithupdate do
		sortedobjectswithupdate[i]:update(...)
	end

	for object, _ in pairs(objectstoadd) do
		if object.update then
			objectswithupdate[object] = true
		end
		if object.draw then
			objectswithdraw[object] = true
		end
		objectstoadd[object] = nil
	end

	for object, _ in pairs(objectstoremove) do
		objectswithupdate[object] = nil
		objectswithdraw[object] = nil
		objectstoremove[object] = nil
	end
end

function drawObjects(...)
	sortObjects(sortedobjectswithdraw, objectswithdraw, comparedraw)
	for i = 1, #sortedobjectswithdraw do
		sortedobjectswithdraw[i]:draw(...)
	end
end

function clearObjects()
	objectswithupdate = {}
	objectswithdraw = {}
	sortedobjectswithupdate = {}
	sortedobjectswithdraw = {}
	objectstoadd = {}
	objectstoremove = {}
end
