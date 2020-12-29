function math.dot(x, y, a, b)
	return x*a + y*b
end

function math.det(x, y, a, b)
	return x*b - a*y
end

function math.hypotsq(x, y)
	return (x*x + y*y)
end

--- Make divisible by power of 2
local function pot(n, precision)
	precision = precision or 32768
	return n < 0 and math.ceil(n*precision)/precision or math.floor(n*precision)/precision
end
math.pot = pot

local sqrt = math.sqrt
function math.sqrt(n)
	return pot(sqrt(n))
end

function math.hypot(x, y)
	return math.sqrt(x*x + y*y)
end
