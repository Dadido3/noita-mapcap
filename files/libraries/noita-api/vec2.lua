-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Just 2D vector stuff. Mainly for Noita.

-- State: Some stuff is untested.

---Metatable of the Vec2 object that is returned by this lib.
---This will only contain a __call field pointing to the constructor.
---@class Vec2Meta
local libMetaTable = {}

---@class Vec2
---@field [1] number
---@field [2] number
---@field x number
---@field y number
local Vec2 = setmetatable({}, libMetaTable)

-----------------
-- Constructor --
-----------------

---Creates a new vector.
---
---	Vec2()           -- Returns a vector with zeroed coordinates.
---	Vec2(v)          -- Returns a copy of the given Vec2 object.
---	Vec2("1.2, 3.4") -- Returns a vector with x = 1.2 and y = 3.4.
---	Vec2(1.2, 3.4)   -- Returns a vector with x = 1.2 and y = 3.4.
---@param ... any
---@return Vec2
function libMetaTable:__call(...)
	local n = select("#", ...)
	if n == 0 then
		return setmetatable({ 0, 0 }, Vec2) -- Zero initialized vector.
	elseif n == 1 then
		local param = select(1, ...)
		if type(param) == "string" then
			local vector = {}
			for field in string.gmatch(param, "[^,%s]+") do
				table.insert(vector, tonumber(field))
			end
			assert(#vector == 2, string.format("parsed vector contains an invalid number of fields: %d, expected %d", #vector, 2))
			return setmetatable(vector, Vec2) -- Vector initialized with the given coordinates.
		elseif getmetatable(param) == Vec2 then
			return Vec2(param[1], param[2])
		end
		error(string.format("unsupported argument type %q", type(param)))
	elseif n == 2 then
		assert(type(select(1, ...)) == "number", string.format("first argument has type %q, expects %q", type(select(1, ...)), "number"))
		assert(type(select(2, ...)) == "number", string.format("first argument has type %q, expects %q", type(select(2, ...)), "number"))
		return setmetatable({ ... }, Vec2) -- Vector initialized with the given coordinates.
	end

	error(string.format("called Vec2 constructor with %d argument(s)", n))
end

-----------------
-- Metamethods --
-----------------

---Handle special fields, like x and y.
---@param key any
---@return any
function Vec2:__index(key)
	if type(key) == "number" then return rawget(self, key) end
	if key == "x" then return rawget(self, 1) end
	if key == "y" then return rawget(self, 2) end
	return rawget(Vec2, key)
end

---Handle special fields, like x and y.
---@param key any
function Vec2:__newindex(key, value)
	if type(key) == "number" then return rawset(self, key, value) end
	if key == "x" then rawset(self, 1, value) end
	if key == "y" then rawset(self, 2, value) end
	-- There should no way to manipulate any other keys of the object or its metatable.
end

---Returns a string representation of this vector.
---This supports a round-trip via Vec2(tostring(v)) without loss of information.
---@return string
function Vec2:__tostring()
	return string.format("%.16g, %.16g", self[1], self[2])
end

----------------------------
-- Mathematic metamethods --
----------------------------

---Returns a new vector that is the sum v1 + v2.
---
---This will not mutate any vector.
---@param v1 Vec2
---@param v2 Vec2
---@return Vec2
function Vec2.__add(v1, v2)
	assert(getmetatable(v1) == Vec2 and getmetatable(v2) == Vec2, "wrong argument types. Expected two Vec2 objects")
	return Vec2(v1[1] + v2[1], v1[2] + v2[2])
end

---Returns a new vector that is the difference v1 - v2.
---
---This will not mutate any vector.
---@param v1 Vec2
---@param v2 Vec2
---@return Vec2
function Vec2.__sub(v1, v2)
	assert(getmetatable(v1) == Vec2 and getmetatable(v2) == Vec2, "wrong argument types. Expected two Vec2 objects")
	return Vec2(v1[1] - v2[1], v1[2] - v2[2])
end

---Returns a new vector that is the multiplication of a vector with a scalar.
---
---This will not mutate any value.
---@param a number|Vec2
---@param b number|Vec2
---@return Vec2
function Vec2.__mul(a, b)
	if type(a) == "number" and getmetatable(b) == Vec2 then
		return Vec2(b[1] * a, b[2] * a)
	elseif getmetatable(a) == Vec2 and type(b) == "number" then
		return Vec2(a[1] * b, a[2] * b)
	end

	error(string.format("invalid combination of argument types for multiplication: %q and %q", type(a), type(b)))
end

---Returns a new vector that is the division of a vector by a scalar.
---
---This will not mutate any value.
---@param v Vec2
---@param s number
---@return Vec2
function Vec2.__div(v, s)
	if getmetatable(v) == Vec2 and type(s) == "number" then
		return Vec2(v[1] / s, v[2] / s)
	end

	error(string.format("invalid combination of argument types for division: %q and %q", type(v), type(s)))
end

---Returns the negated vector.
---
---This will not mutate any value.
---@return Vec2
function Vec2:__unm()
	return Vec2(-self[1], -self[2])
end

---Returns whether the two vectors are equal.
---Will return false if one of the values is not a vector.
---@param v1 Vec2
---@param v2 Vec2
---@return boolean
function Vec2.__eq(v1, v2)
	if getmetatable(v1) ~= Vec2 or getmetatable(v2) ~= Vec2 then return false end
	return v1[1] == v2[1] and v1[2] == v2[2]
end

-------------
-- Methods --
-------------

---Adds v to the vector.
---
---This mutates self.
---@param v Vec2
function Vec2:Add(v)
	assert(getmetatable(v) == Vec2, string.format("wrong argument type %q, expected Vec2 object", type(v)))
	self[1], self[2] = self[1] + v[1], self[2] + v[2]
end

---Subtracts v from the vector.
---
---This mutates self.
---@param v Vec2
function Vec2:Sub(v)
	assert(getmetatable(v) == Vec2, string.format("wrong argument type %q, expected Vec2 object", type(v)))
	self[1], self[2] = self[1] - v[1], self[2] - v[2]
end

---Multiplies self with the given scalar.
---
---This mutates self.
---@param s number
function Vec2:Mul(s)
	assert(type(s) == "number", string.format("wrong argument type %q, expected number", type(s)))
	self[1], self[2] = self[1] * s, self[2] * s
end

---Divides self by the given scalar.
---
---This mutates self.
---@param s number
function Vec2:Div(s)
	assert(type(s) == "number", string.format("wrong argument type %q, expected number", type(s)))
	self[1], self[2] = self[1] / s, self[2] / s
end

---Returns a copy of self.
---@return Vec2
function Vec2:Copy()
	return Vec2(self)
end

---Returns the vector fields as parameters.
---@return number
---@return number
function Vec2:Unpack()
	return self[1], self[2]
end

---Sets the vector fields to the given coordinates.
---@param x number
---@param y number
function Vec2:Set(x, y)
	assert(type(x) == "number", string.format("wrong argument type %q, expected number", type(x)))
	assert(type(y) == "number", string.format("wrong argument type %q, expected number", type(y)))
	self[1], self[2] = x, y
end

---Returns the squared length of the vector.
---@return number
function Vec2:LengthSqr()
	return self[1] ^ 2 + self[2] ^ 2
end

---Returns the length of the vector.
---@return number
function Vec2:Length()
	return math.sqrt(self:LengthSqr())
end

---Returns the squared distance of self to the given vector.
---@param v Vec2
function Vec2:DistanceSqr(v)
	return (v - self):LengthSqr()
end

---Returns the distance of self to the given vector.
---@param v Vec2
function Vec2:Distance(v)
	return (v - self):Length()
end

---Sets the length of the vector to 1.
---
---This mutates self.
function Vec2:Normalize()
	local len = self:Length()
	self:Div(len)
end

---Returns a copy of the vector with its length set to 1.
---@return Vec2
function Vec2:Normalized()
	local len = self:Length()
	return self / len
end

---Compares this vector to the given one.
---@param v Vec2
---@param tolerance number -- Tolerance per field.
---@return boolean
function Vec2:EqualTo(v, tolerance)
	if math.abs(v[1] - self[1]) > tolerance then return false end
	if math.abs(v[2] - self[2]) > tolerance then return false end
	return true
end

-------------------------
-- JSON Implementation --
-------------------------

---MarshalJSON implements the JSON marshaler interface.
---@return string
function Vec2:MarshalJSON()
	return string.format("[%.16g, %.16g]", self[1], self[2]) -- Encode as JSON array. -- TODO: Handle NaN, +Inf, -Inf, ... correctly
end

return Vec2
