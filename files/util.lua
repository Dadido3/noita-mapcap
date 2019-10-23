-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

function SplitStringByLength(string, length)
	local chunks = {}
	for i = 1, #string, length do
		table.insert(chunks, string:sub(i, i + length - 1))
	end
	return chunks
end

-- Improved version of GamePrint, that behaves more like print.
local oldGamePrint = GamePrint
function GamePrint(...)
	local arg = {...}

	local result = ""

	for i, v in ipairs(arg) do
		result = result .. tostring(v) .. "    "
	end

	for line in result:gmatch("[^\r\n]+") do
		for i, v in ipairs(splitStringByLength(line, 100)) do
			oldGamePrint(v)
		end
	end
end

function getPlayer()
	local players = EntityGetWithTag("player_unit")
	if players == nil or #players < 1 then
		return nil
	end
	return players[1]
end

function getPlayerPos()
	return EntityGetTransform(getPlayer())
end

function teleportPlayer(x, y)
	EntitySetTransform(getPlayer(), x, y)
end

function setPlayerHP(hp)
	local damagemodels = EntityGetComponent(getPlayer(), "DamageModelComponent")

	if damagemodels ~= nil then
		for i, damagemodel in ipairs(damagemodels) do
			ComponentSetValue(damagemodel, "max_hp", hp)
			ComponentSetValue(damagemodel, "hp", hp)
		end
	end
end

function addEffectToEntity(entity, gameEffect)
	local gameEffectComp = GetGameEffectLoadTo(entity, gameEffect, true)
	if gameEffectComp ~= nil then
		ComponentSetValue(gameEffectComp, "frames", "-1")
	end
end

function addPerkToPlayer(perkID)
	local playerEntity = getPlayer()
	local x, y = getPlayerPos()
	local perkData = get_perk_with_id(perk_list, perkID)

	-- Add effect
	addEffectToEntity(playerEntity, perkData.game_effect)

	-- Add ui icon etc
	--[[local perkIcon = EntityCreateNew("")
	EntityAddComponent(
		perkIcon,
		"UIIconComponent",
		{
			name = perkData.ui_name,
			description = perkData.ui_description,
			icon_sprite_file = perkData.ui_icon
		}
	)
	EntityAddChild(playerEntity, perkIcon)]]

	--local effect = EntityLoad("data/entities/misc/effect_protection_all.xml", x, y)
	--EntityAddChild(playerEntity, effect)
end

function fileExists(fileName)
	local f = io.open(fileName, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end
