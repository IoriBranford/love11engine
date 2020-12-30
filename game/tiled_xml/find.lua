local type = type
local find = {}

local _find_queue = {}
local function _find(node, condition, ...)
	if type(node) ~= "table" or type(condition) ~= "function" then
		return
	end

	local q1 = 1
	local qn = 1
	_find_queue[1] = node
	local found

	while q1 <= qn do
		node = _find_queue[q1]
		q1 = q1 + 1

		if condition(node, ...) then
			found = node
			break
		end

		for i = 1, #node do
			local child = node[i]
			if type(child) == "table" then
				qn = qn + 1
				_find_queue[qn] = child
			end
		end
	end

	for i = #_find_queue, 1, -1 do
		_find_queue[i] = nil
	end

	return found
end
find.custom = _find

local function named(node, name)
	return node.name == name
end

function find.named(node, name)
	return _find(node, named, name)
end

function find.nameRegex(node, pattern)
	return _find(node, function(node, pattern)
		local name = node.name
		return name and name:find(pattern)
	end, pattern)
end

local function layerNamed(node, name)
	return node.tag == "layer" and node.name == name
end

function find.layerNamed(node, name)
	return _find(node, layerNamed, name)
end

local function objectNamed(node, name)
	return node.tag == "object" and node.name == name
end

function find.objectNamed(node, name)
	return _find(node, objectNamed, name)
end

return find
