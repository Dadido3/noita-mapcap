-- Copyright (c) 2019-2022 David Vogel
-- 
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- This contains just some utilitites that may be useful to have.

local DebugAPI = require("noita-api.debug")

local Utils = {}

---Returns if the file at filePath exists.
---This only works correctly when API access is not restricted.
---@param filePath string
---@return boolean
function Utils.FileExists(filePath)
	local f = io.open(filePath, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

local specialDirectoryDev = {
	["save-shared"] = "save_shared/",
	["save-stats"] = "save_stats/", -- Assumes that the first save is the currently used one.
	["save"] = "save00/" -- Assumes that the first save is the currently used one.
}

local specialDirectory = {
	["save-shared"] = "save_shared/",
	["save-stats"] = "save00/stats/", -- Assumes that the first save is the currently used one.
	["save"] = "save00/" -- Assumes that the first save is the currently used one.
}

---Returns the path to the special directory, or nil in case it couldn't be determined.
---This only works correctly when API access is not restricted.
---@param id "save-shared"|"save-stats"|"save"
---@return string|nil
function Utils.GetSpecialDirectory(id)
	if DebugAPI.IsDevBuild() then
		-- We are in the dev build.
		return "./" .. specialDirectoryDev[id]
	else
		-- We are in the normal Noita executable.
		-- Hacky way to get to LocalLow, there is just no other way to get this path. :/
		local pathPrefix = os.getenv('APPDATA'):gsub("[^\\/]+$", "") .. "LocalLow/Nolla_Games_Noita/"
		return pathPrefix .. specialDirectory[id]
	end
end

return Utils
