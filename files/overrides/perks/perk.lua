-- Copyright (c) 2022 David Vogel
-- 
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Emulate and override some functions and tables to make everything conform more to standard lua.
-- This will make `require` work, even in sandboxes with restricted Noita API.
local libPath = "mods/noita-mapcap/files/libraries/"
dofile(libPath .. "noita-api/compatibility.lua")(libPath)

local EntityAPI = require("noita-api.entity")

local oldPerkSpawn = perk_spawn

---Spawns a perk.
---@param x number
---@param y number
---@param perkID integer
---@param dontRemoveOtherPerks boolean
---@return NoitaEntity|nil
function perk_spawn(x, y, perkID, dontRemoveOtherPerks)
	local entity = EntityAPI.Wrap(oldPerkSpawn(x, y, perkID, dontRemoveOtherPerks))
	if entity == nil then return end

	-- Remove the SpriteOffsetAnimatorComponent components from the entity.
	local components = entity:GetComponents("SpriteOffsetAnimatorComponent")
	for _, component in ipairs(components) do
		entity:RemoveComponent(component)
	end
end
