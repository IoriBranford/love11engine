local type = type
local find = {}

local function _find(node, condition, ...)
	if type(node) ~= "table" or type(condition) ~= "function" then
		return
	end
	if condition(node, ...) then
		return node
	end
	for i = 1, #node do
		local child = node[i]
		if type(child) == "table" then
			if condition(child, ...) then
				return child
			end
		end
	end
	for i = 1, #node do
		local child = node[i]
		local found = _find(child, condition, ...)
		if found then
			return found
		end
	end
end
find.custom = _find

local function named(node, name)
	return node.name == name
end

function find.named(node, name)
	return _find(node, named, name)
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
