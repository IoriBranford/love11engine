local find = {}

local function _find(node, condition, ...)
	if condition(node, ...) then
		return node
	end
	for i = 1, #node do
		local found = _find(node[i], condition, ...)
		if found then
			return found
		end
	end
end
find.custom = _find

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
