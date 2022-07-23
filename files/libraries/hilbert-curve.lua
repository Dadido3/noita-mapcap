-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

---@class HilbertLib
local Hilbert = {}

---Rotate/flip quadrant.
---@param n integer
---@param x integer
---@param y integer
---@param rx boolean
---@param ry boolean
---@return integer
---@return integer
local function hilbertRotate(n, x, y, rx, ry)
	if not ry then
		if rx then
			x = n - 1 - x
			y = n - 1 - y
		end

		x, y = y, x
	end
	return x, y
end

---Maps t in the range of [0, (2^potSize)^2-1] to a position on the hilbert curve with the side length of 2^potSize (Power of two size).
---@param t integer
---@param potSize integer
---@return integer
---@return integer
function Hilbert.Map(t, potSize)
	local size = math.pow(2, potSize)
	local x, y = 0, 0

	if t < 0 or t >= size * size then
		error("variable t is outside of the range")
	end

	for i = 0, potSize - 1, 1 do
		local iPOT = math.pow(2, i)
		local rx = bit.band(t, 2) == 2
		local ry = bit.band(t, 1) == 1
		if rx then
			ry = not ry
		end

		x, y = hilbertRotate(iPOT, x, y, rx, ry)

		if rx then
			x = x + iPOT
		end
		if ry then
			y = y + iPOT
		end

		t = math.floor(t / 4)
	end

	return x, y
end

return Hilbert
