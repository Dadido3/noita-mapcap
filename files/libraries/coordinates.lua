-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Pixel perfect viewport coordinates transformation (world <-> window) for Noita.

-- For it to work, you have to:
-- - Put Coords:ReadResolutions() inside of the OnMagicNumbersAndWorldSeedInitialized() hook.

-- Some general information on how Noita does that stuff internally:
-- - The base for all calculations is the window rectangle (window client area).
-- - Inside the window there is the internal rectangle that is fit to be fully contained and centered inside the window.
-- - Inside the internal rectangle there is the virtual rectangle that is aligned to the top, and scaled to fit horizontally.
-- - Everything outside the internal rectangle is black.
-- - Everything outside the virtual rectangle is not rendered correctly.
-- - A positive virtual offset moves the rendered world to the top left.
-- - GameGetCameraBounds returned coordinates are off by a few pixels, also it doesn't have sub pixel precision.
-- - The mouse cursor coordinates in the dev build use the wrong rounding method (They are rounded towards zero, instead of being rounded towards negative infinity).
-- - Integer world coordinates map exactly to pixel borders.
-- - The default image ratios of the virtual and internal rectangles don't exactly match, which causes a small line of not correctly rendered pixels at the bottom window.
-- - The GRID_RENDER_BORDER magic number adds the given amount of world pixels to the virtual rectangle's width. This happens after fitting, so a positive value will make it wider than the internal rectangle. The virtual rectangle will always be aligned to start at the left side of the internal rectangle, though.
-- - The virtual offset needs to be [-GRID_RENDER_BORDER, 0] for the viewport center to be exactly centered to the window or virtual rectangle.

--------------------------
-- Load library modules --
--------------------------

local CameraAPI = require("noita-api.camera")
local NXML = require("luanxml.nxml")
local Utils = require("noita-api.utils")
local Vec2 = require("noita-api.vec2")

----------
-- Code --
----------

---@class Coords
---@field InternalResolution Vec2 -- Size of the internal rectangle in window pixels.
---@field WindowResolution Vec2 -- Size of the window client area in window pixels.
---@field VirtualResolution Vec2 -- Size of the virtual rectangle in world/virtual pixels.
---@field VirtualOffset Vec2 -- Offset of the virtual rectangle in world/virtual pixels.
---@field VirtualBorder number -- The magic number "GRID_RENDER_BORDER" in world/virtual pixels.
---@field FullscreenMode integer -- The fullscreen mode the game is in. 0 is windowed.
local Coords = {
	InternalResolution = Vec2(0, 0),
	WindowResolution = Vec2(0, 0),
	VirtualResolution = Vec2(0, 0),
	VirtualOffset = Vec2(0, 0),
	VirtualBorder = 0,
	FullscreenMode = 0,
}

---Reads and updates the internal, window and virtual resolutions from Noita's config files and API.
---@return any error
function Coords:ReadResolutions()
	local filename = Utils.GetSpecialDirectory("save-shared") .. "config.xml"

	local f, err = io.open(filename, "r")
	if not f then return err end

	local xml = NXML.parse(f:read("*a"))

	self.WindowResolution = Vec2(tonumber(xml.attr["window_w"]), tonumber(xml.attr["window_h"]))
	self.InternalResolution = Vec2(tonumber(xml.attr["internal_size_w"]), tonumber(xml.attr["internal_size_h"]))
	self.VirtualResolution = Vec2(tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")), tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y")))
	self.VirtualOffset = Vec2(tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_OFFSET_X")), tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_OFFSET_Y")))
	self.VirtualBorder = tonumber(MagicNumbersGetValue("GRID_RENDER_BORDER")) or 0
	self.FullscreenMode = tonumber(xml.attr["fullscreen"]) or 0

	f:close()
	return nil
end

---Returns the size of the internal rectangle in window/screen coordinates.
---The internal rect is always uniformly scaled to fit inside the window rectangle.
---@return Vec2
function Coords:InternalRectSize()
	return self.InternalResolution * math.min(self.WindowResolution.x / self.InternalResolution.x, self.WindowResolution.y / self.InternalResolution.y)
end

---Returns the window coordinates of the internal rectangle in window/screen coordinates.
---This rectangle is centered and scaled to fit exactly into the window rectangle.
---@return Vec2 topLeft
---@return Vec2 bottomRight -- These coordinates are outside of the rectangle.
function Coords:InternalRect()
	local internalRectSize = self:InternalRectSize()

	-- Center rectangle and return corner points.

	---@type Vec2
	local halfDifference = (self.WindowResolution - internalRectSize) / 2
	return halfDifference, internalRectSize + halfDifference
end

---Returns the virtual rectangle coordinates in window/screen coordinates.
---This is the rectangle that has all chunks and terrain rendered correctly.
---The rectangle may be larger than the screen, though.
---@return Vec2 topLeft
---@return Vec2 bottomRight -- These coordinates are outside of the rectangle.
function Coords:VirtualRect()
	local internalTopLeft, internalBottomRight = self:InternalRect()

	return internalTopLeft, internalTopLeft + self.VirtualResolution * self:PixelScale()
end

---Returns the rectangle that contains valid rendered terrain and chunks.
---This is cropped to the internal rectangle, and can be used to determine the usable area of window screenshots.
---@return Vec2 topLeft
---@return Vec2 bottomRight -- These coordinates are outside of the rectangle.
function Coords:ValidRenderingRect()
	local internalTopLeft, internalBottomRight = self:InternalRect()
	local virtualTopLeft, virtualBottomRight = self:VirtualRect()

	return virtualTopLeft, Vec2(math.min(virtualBottomRight.x, internalBottomRight.x), math.min(virtualBottomRight.y, internalBottomRight.y))
end

---Returns the ratio of window pixels per world pixels.
---As pixels are always square, this returns just a single number.
---@return number
function Coords:PixelScale()
	local internalRectSize = self:InternalRectSize()

	-- The virtual rectangle is always scaled to fit horizontally.
	return internalRectSize.x / self.VirtualResolution.x
end

---Converts the given virtual/world coordinates into window/screen coordinates.
---@param world Vec2 -- World coordinate, origin is near the cave entrance.
---@param viewportCenter Vec2|nil -- Result of `GameGetCameraPos()`. Will be queried automatically if set to nil.
---@return Vec2 window
function Coords:ToWindow(world, viewportCenter)
	viewportCenter = viewportCenter or CameraAPI.GetPos()

	local internalTopLeft, internalBottomRight = self:InternalRect()
	local pixelScale = self:PixelScale()

	return internalTopLeft + (self.VirtualResolution / 2 + world - viewportCenter + Vec2(self.VirtualBorder, 0) + self.VirtualOffset) * pixelScale
end

---Converts the given window coordinates into world/virtual coordinates.
---@param window Vec2 -- In screen pixels, origin is at the top left of the window client area.
---@param viewportCenter Vec2|nil -- Result of `GameGetCameraPos()`. Will be queried automatically if set to nil.
---@return Vec2 world
function Coords:ToWorld(window, viewportCenter)
	viewportCenter = viewportCenter or CameraAPI.GetPos()

	local internalTopLeft, internalBottomRight = self:InternalRect()
	local pixelScale = self:PixelScale()

	return viewportCenter - self.VirtualResolution / 2 + (window - internalTopLeft) / pixelScale - Vec2(self.VirtualBorder, 0) - self.VirtualOffset
end

-------------
-- Testing --
-------------

---Values to test the coordinate transformations.
---
--- Configuration (`...\save_shared\config.xml`) parameters:
--- - `backbuffer_width`, `backbuffer_height`: The resolution for the final pixel shader, or something like that. Lowering this will not change the coordinate system, but make everything look more pixelated. The backbuffer size should be set at least to the internal resolution, Noita sets it to the window resolution.
--- - `internal_size_w`, `internal_size_h`: The rectangle that all window content will be displayed in. If the window ratio is different than the internal size ratio, there will be black bars either at the top and bottom, or left and right.
--- - `window_w`, `window_h`: The window client area size in pixels, duh.
---
--- Magic numbers (`.\mods\noita-mapcap\files\magic_numbers.xml`):
--- - `VIRTUAL_RESOLUTION_X`, `VIRTUAL_RESOLUTION_X`: The resolution of the rendered world.
--- - `VIRTUAL_RESOLUTION_OFFSET_X`, `VIRTUAL_RESOLUTION_OFFSET_Y`: Offset of the world/virtual coordinate system, has to be set to `-2, 0` to map pixel perfect to the screen.
---
--- Table contents:
---
--- - `InternalRes`, `WindowRes`, `VirtualRes`, `VirtualBorder` -- are the settings from the above mentioned config files.
--- - `WindowTopLeft` contains the resulting world coordinates of the window's top left pixel with GameSetCameraPos(0, 0).
--- - `WindowCenter` contains the resulting world coordinates of the window's center pixel with GameSetCameraPos(0, 0).
--- - `RenderedTopLeft`, `RenderedBottomRight` describe the rectangle in world coordinates that contains correctly rendered chunks. Everything outside this rectangle may either just be a blank background image or completely black.
local testTable = {
	{ InternalRes = Vec2(1024, 1024), WindowRes = Vec2(1024, 1024), VirtualRes = Vec2(1024, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-512, -512), WindowCenter = Vec2(0, 0), RenderedTopLeft = Vec2(-512, -512), RenderedBottomRight = Vec2(512, 512) },
	{ InternalRes = Vec2(1024, 1024), WindowRes = Vec2(1024, 1024), VirtualRes = Vec2(512, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-256, -512), WindowCenter = Vec2(0, -256), RenderedTopLeft = Vec2(-256, -512), RenderedBottomRight = Vec2(256, 0) },
	{ InternalRes = Vec2(1024, 1024), WindowRes = Vec2(1024, 1024), VirtualRes = Vec2(1024, 512), VirtualBorder = 2, WindowTopLeft = Vec2(-512, -256), WindowCenter = Vec2(0, 256), RenderedTopLeft = Vec2(-512, -256), RenderedBottomRight = Vec2(512, 256) },
	{ InternalRes = Vec2(512, 1024), WindowRes = Vec2(1024, 1024), VirtualRes = Vec2(1024, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-1024, -512), WindowCenter = Vec2(0, 512), RenderedTopLeft = Vec2(-512, -512), RenderedBottomRight = Vec2(512, 512) },
	{ InternalRes = Vec2(1024, 512), WindowRes = Vec2(1024, 1024), VirtualRes = Vec2(1024, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-512, -768), WindowCenter = Vec2(0, -256), RenderedTopLeft = Vec2(-512, -512), RenderedBottomRight = Vec2(512, 0) },
	{ InternalRes = Vec2(1024, 1024), WindowRes = Vec2(1024, 2048), VirtualRes = Vec2(1024, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-512, -1024), WindowCenter = Vec2(0, 0), RenderedTopLeft = Vec2(-512, -512), RenderedBottomRight = Vec2(512, 512) },
	{ InternalRes = Vec2(1024, 1024), WindowRes = Vec2(2048, 1024), VirtualRes = Vec2(1024, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-1024, -512), WindowCenter = Vec2(0, 0), RenderedTopLeft = Vec2(-512, -512), RenderedBottomRight = Vec2(512, 512) },
	{ InternalRes = Vec2(1024, 512), WindowRes = Vec2(1024, 512), VirtualRes = Vec2(1024, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-512, -512), WindowCenter = Vec2(0, -256), RenderedTopLeft = Vec2(-512, -512), RenderedBottomRight = Vec2(512, 0) },
	{ InternalRes = Vec2(2048, 1024), WindowRes = Vec2(2048, 1024), VirtualRes = Vec2(1024, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-512, -512), WindowCenter = Vec2(0, -256), RenderedTopLeft = Vec2(-512, -512), RenderedBottomRight = Vec2(512, 0) },
	{ InternalRes = Vec2(2048, 1024), WindowRes = Vec2(2048, 1024), VirtualRes = Vec2(2048, 1024), VirtualBorder = 2, WindowTopLeft = Vec2(-1024, -512), WindowCenter = Vec2(0, 0), RenderedTopLeft = Vec2(-1024, -512), RenderedBottomRight = Vec2(1024, 512) },
	{ InternalRes = Vec2(2048, 1024), WindowRes = Vec2(2048, 1024), VirtualRes = Vec2(512, 2048), VirtualBorder = 2, WindowTopLeft = Vec2(-256, -1024), WindowCenter = Vec2(0, -896), RenderedTopLeft = Vec2(-256, -1024), RenderedBottomRight = Vec2(256, -768) },
	{ InternalRes = Vec2(2048, 1024), WindowRes = Vec2(2048, 1024), VirtualRes = Vec2(1024, 16), VirtualBorder = 2, WindowTopLeft = Vec2(-512, -8), WindowCenter = Vec2(0, 248), RenderedTopLeft = Vec2(-512, -8), RenderedBottomRight = Vec2(512, 8) },
	{ InternalRes = Vec2(1024, 1024), WindowRes = Vec2(1024, 1024), VirtualRes = Vec2(32, 16), VirtualBorder = 2, WindowTopLeft = Vec2(-16, -8), WindowCenter = Vec2(0, 8), RenderedTopLeft = Vec2(-16, -8), RenderedBottomRight = Vec2(16, 8) },
	{ InternalRes = Vec2(1280, 720), WindowRes = Vec2(1920, 1080), VirtualRes = Vec2(427, 242), VirtualBorder = 2, WindowTopLeft = Vec2(-213.5, -121), WindowCenter = Vec2(0, -0.90625), RenderedTopLeft = Vec2(-213.5, -121), RenderedBottomRight = Vec2(213.5, 119.1875) },
	{ InternalRes = Vec2(1280, 720), WindowRes = Vec2(1920, 1200), VirtualRes = Vec2(427, 242), VirtualBorder = 2, WindowTopLeft = Vec2(-213.5, -134.34375), WindowCenter = Vec2(0, -0.90625), RenderedTopLeft = Vec2(-213.5, -121), RenderedBottomRight = Vec2(213.5, 119.1875) },
	{ InternalRes = Vec2(1280, 720), WindowRes = Vec2(2048, 1080), VirtualRes = Vec2(427, 242), VirtualBorder = 2, WindowTopLeft = Vec2(-227.73333, -121), WindowCenter = Vec2(0, -0.90625), RenderedTopLeft = Vec2(-213.5, -121), RenderedBottomRight = Vec2(213.5, 119.1875) },
}

---Tests all possible test cases.
---Throws an error in case any test fails.
local function testToWindow()
	for i, v in ipairs(testTable) do
		Coords.InternalResolution, Coords.WindowResolution, Coords.VirtualResolution, Coords.VirtualBorder = v.InternalRes, v.WindowRes, v.VirtualRes, v.VirtualBorder

		---@type Vec2
		local viewportCenter = Vec2(0, 0)

		---@type Vec2, Vec2
		local world, expected = v.WindowTopLeft, Vec2(0, 0)
		local window = Coords:ToWindow(world, viewportCenter)
		assert(window:EqualTo(expected, 0.001), string.format("test case %d: Coords:ToWindow(%q) failed. Got %q, expected %q", i, tostring(world), tostring(window), tostring(expected)))

		---@type Vec2, Vec2
		local world, expected = v.WindowCenter, v.WindowRes / 2
		local window = Coords:ToWindow(world, viewportCenter)
		assert(window:EqualTo(expected, 0.001), string.format("test case %d: Coords:ToWindow(%q) failed. Got %q, expected %q", i, tostring(world), tostring(window), tostring(expected)))
	end
end

---Tests all possible test cases.
---Throws an error in case any test fails.
local function testToWorld()
	for i, v in ipairs(testTable) do
		Coords.InternalResolution, Coords.WindowResolution, Coords.VirtualResolution, Coords.VirtualBorder = v.InternalRes, v.WindowRes, v.VirtualRes, v.VirtualBorder

		---@type Vec2
		local viewportCenter = Vec2(0, 0)

		---@type Vec2, Vec2
		local window, expected = Vec2(0, 0), v.WindowTopLeft
		local world = Coords:ToWorld(window, viewportCenter)
		assert(world:EqualTo(expected, 0.001), string.format("test case %d: Coords:ToWorld(%q) failed. Got %q, expected %q", i, tostring(window), tostring(world), tostring(expected)))

		---@type Vec2, Vec2
		local window, expected = v.WindowRes / 2, v.WindowCenter
		local world = Coords:ToWorld(window, viewportCenter)
		assert(world:EqualTo(expected, 0.001), string.format("test case %d: Coords:ToWorld(%q) failed. Got %q, expected %q", i, tostring(window), tostring(world), tostring(expected)))
	end
end

---Tests all possible test cases.
---Throws an error in case any test fails.
local function testValidRenderingRect()
	for i, v in ipairs(testTable) do
		Coords.InternalResolution, Coords.WindowResolution, Coords.VirtualResolution, Coords.VirtualBorder = v.InternalRes, v.WindowRes, v.VirtualRes, v.VirtualBorder

		---@type Vec2
		local viewportCenter = Vec2(0, 0)

		local expectedTopLeft, expectedBottomRight = v.RenderedTopLeft, v.RenderedBottomRight

		---@type Vec2, Vec2
		local validTopLeft, validBottomRight = Coords:ValidRenderingRect()
		local validTopLeftWorld, validBottomRightWorld = Coords:ToWorld(validTopLeft, viewportCenter), Coords:ToWorld(validBottomRight, viewportCenter)
		assert(validTopLeftWorld:EqualTo(expectedTopLeft, 0.001) and validBottomRightWorld:EqualTo(expectedBottomRight, 0.001),
			string.format("test case %d: Coords:ValidRenderingRect() failed. Got %q - %q, expected %q - %q",
				i, tostring(validTopLeftWorld), tostring(validBottomRightWorld), tostring(expectedTopLeft), tostring(expectedBottomRight)
			)
		)
	end
end

---Runs all tests of this module.
local function testAll()
	local ok, err = pcall(testToWindow)
	if not ok then
		print(string.format("testToWindow failed: %s.", err))
	end

	local ok, err = pcall(testToWorld)
	if not ok then
		print(string.format("testToWorld failed: %s.", err))
	end

	local ok, err = pcall(testValidRenderingRect)
	if not ok then
		print(string.format("testValidRenderingRect failed: %s.", err))
	end
end

--testAll()

return Coords
