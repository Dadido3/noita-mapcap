-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Noita modding API, but a bit more beautiful.
-- Current modding API version: 7

-- State: Working but incomplete. If something is missing, add it by hand!
-- It would be optimal to generate this API wrapper automatically...

---@type Vec2
local Vec2 = dofile_once("mods/noita-mapcap/files/libraries/vec2.lua")

-------------
-- Classes --
-------------

---@class NoitaCameraAPI
local CameraAPI = {}

------------------------
-- Noita API wrappers --
------------------------

---
---@param strength number
---@param position Vec2|nil -- Defaults to camera position if not set.
function CameraAPI.Screenshake(strength, position)
	if position == nil then
		return GameScreenshake(strength)
	end
	return GameScreenshake(strength, position.x, position.y)
end

---Returns the center position of the viewport in world/virtual coordinates.
---@return Vec2
function CameraAPI.Pos()
	return Vec2(GameGetCameraPos())
end

---Sets the center position of the viewport in world/virtual coordinates.
---@param position Vec2
function CameraAPI.SetPos(position)
	return GameSetCameraPos(position.x, position.y)
end

---
---@param isFree boolean
function CameraAPI.SetCameraFree(isFree)
	return GameSetCameraFree(isFree)
end

---Returns the camera boundary rectangle in world/virtual coordinates.
---This may not be 100% pixel perfect with regards to what you see on the screen.
---@return Vec2 topLeft
---@return Vec2 bottomRight
function CameraAPI.Bounds()
	local x, y, w, h = GameGetCameraBounds()
	return Vec2(x, y), Vec2(x + w, y + h)
end

return CameraAPI
