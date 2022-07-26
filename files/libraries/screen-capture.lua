-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local Vec2 = require("noita-api.vec2")

local ffi = require("ffi")

local ScreenCap = {}

local status, res = pcall(ffi.load, "mods/noita-mapcap/bin/capture-b/capture")
if not status then
	print(string.format("Error loading capture lib: %s", res))
	return
end

ffi.cdef([[
	typedef long LONG;
	typedef struct {
		LONG left;
		LONG top;
		LONG right;
		LONG bottom;
	} RECT;

	bool GetRect(RECT* rect);
	bool Capture(RECT* rect, int x, int y, int sx, int sy);
]])

---Takes a screenshot of the client area of this process' active window.
---@param topLeft Vec2 -- Screenshot rectangle's top left coordinate relative to the window's client area in screen pixels.
---@param bottomRight Vec2 -- Screenshot rectangle's bottom right coordinate relative to the window's client area in screen pixels. The pixel is not included in the screenshot area.
---@param topLeftOutput Vec2 -- The corresponding scaled world coordinates of the screenshot rectangles' top left corner.
---@param finalDimensions Vec2|nil -- The final dimensions that the screenshot will be resized to. If set to zero, no resize will happen.
---@return boolean
function ScreenCap.Capture(topLeft, bottomRight, topLeftOutput, finalDimensions)
	finalDimensions = finalDimensions or Vec2(0, 0)

	local rect = ffi.new("RECT", { math.floor(topLeft.x + 0.5), math.floor(topLeft.y + 0.5), math.floor(bottomRight.x + 0.5), math.floor(bottomRight.y + 0.5) })
	return res.Capture(rect, math.floor(topLeftOutput.x + 0.5), math.floor(topLeftOutput.y + 0.5), math.floor(finalDimensions.x + 0.5), math.floor(finalDimensions.y + 0.5))
end

---Returns the client rectangle of the "Main" window of this process in screen coordinates.
---@return any
function ScreenCap.GetRect()
	local rect = ffi.new("RECT")
	if not res.GetRect(rect) then
		return nil
	end

	return rect
end

return ScreenCap
