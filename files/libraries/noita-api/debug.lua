-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local Vec2 = require("noita-api.vec2")

-------------
-- Classes --
-------------

local DebugAPI = {}

------------------------
-- Noita API wrappers --
------------------------

---Returns the mouse cursor position in world coordinates.
---@return Vec2
function DebugAPI.GetMouseWorld()
	return Vec2(DEBUG_GetMouseWorld())
end

---Draws a mark in the world at the given position.
---@param pos Vec2 -- In world coordinates.
---@param message string|nil -- Defaults to "".
---@param r number|nil -- Color's red amount in the range [0, 1]. Defaults to 1.
---@param g number|nil -- Color's green amount in the range [0, 1]. Defaults to 0.
---@param b number|nil -- Color's blue amount in the range [0, 1]. Defaults to 0.
function DebugAPI.Mark(pos, message, r, g, b)
	message, r, g, b = message or "", r or 1, g or 0, b or 0
	return DEBUG_MARK(pos.x, pos.y, message, r, g, b)
end

---Returns true if this is a beta version of the game.
---
---Can return nil it seems.
---@return boolean|nil
function DebugAPI.IsBetaBuild()
	return GameIsBetaBuild()
end

---Returns true if this is the dev version of the game (`noita_dev.exe`).
---@return boolean
function DebugAPI.IsDevBuild()
	return DebugGetIsDevBuild()
end

---Enables the trailer mode and some other things:
---
--- - Disables in-game GUI.
--- - Opens fog of war everywhere (Not the same as disabling it completely).
--- - Enables `mTrailerMode`, whatever that does.
---
---No idea how to disable it, beside pressing F12 in dev build.
function DebugAPI.EnableTrailerMode()
	return DebugEnableTrailerMode()
end

---
---@return boolean
function DebugAPI.IsTrailerModeEnabled()
	return GameGetIsTrailerModeEnabled()
end

---
---@param pos Vec2 -- In world coordinates.
---@return string
function DebugAPI.BiomeMapGetFilename(pos)
	return DebugBiomeMapGetFilename(pos.x, pos.y)
end

return DebugAPI
