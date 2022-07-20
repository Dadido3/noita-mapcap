-- Copyright (c) 2022 David Vogel
-- 
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

---@type NoitaAPI
local noitaAPI = dofile_once("mods/noita-mapcap/files/libraries/noita-api.lua")

local oldPerkSpawn = perk_spawn

---Spawns a perk.
---@param x number
---@param y number
---@param perkID integer
---@param dontRemoveOtherPerks boolean
---@return NoitaEntity|nil
function perk_spawn(x, y, perkID, dontRemoveOtherPerks)
	local entity = noitaAPI.Entity.WrapID(oldPerkSpawn(x, y, perkID, dontRemoveOtherPerks))
	if entity == nil then return end

	-- Remove the SpriteOffsetAnimatorComponent components from the entity.
	local components = entity:GetComponents("SpriteOffsetAnimatorComponent")
	for _, component in ipairs(components) do
		entity:RemoveComponent(component)
	end
end
