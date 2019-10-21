-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

dofile("mods/noita-mapcap/files/util.lua")
dofile("mods/noita-mapcap/files/external.lua")
dofile("mods/noita-mapcap/files/ws.lua")

--dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/perks/perk_list.lua")

if not async then -- Check if lib is already loaded
	dofile("data/scripts/lib/coroutines.lua")
end

local CAPTURE_PIXEL_SIZE = 2 -- in FullHD a ingame pixel is expected to be 2 real pixels
local CAPTURE_GRID_SIZE = 128 -- in ingame pixels
local CAPTURE_DELAY = 15 -- in frames
local CAPTURE_FORCE_HP = 40 -- * 25HP

local function getPlayer()
	local players = EntityGetWithTag("player_unit")
	if players == nil or #players < 1 then
		return nil
	end
	return players[1]
end

local function getPlayerPos()
	return EntityGetTransform(getPlayer())
end

local function teleportPlayer(x, y)
	EntitySetTransform(getPlayer(), x, y)
end

local function setPlayerHP(hp)
	local damagemodels = EntityGetComponent(getPlayer(), "DamageModelComponent")

	if damagemodels ~= nil then
		for i, damagemodel in ipairs(damagemodels) do
			ComponentSetValue(damagemodel, "max_hp", hp)
			ComponentSetValue(damagemodel, "hp", hp)
		end
	end
end

local function addEffectToEntity(entity, gameEffect)
	local gameEffectComp = GetGameEffectLoadTo(entity, gameEffect, true)
	if gameEffectComp ~= nil then
		ComponentSetValue(gameEffectComp, "frames", "-1")
	end
end

local function addPerkToPlayer(perkID)
	local playerEntity = getPlayer()
	local x, y = getPlayerPos()
	local perkData = get_perk_with_id(perk_list, perkID)

	-- Add effect
	addEffectToEntity(playerEntity, perkData.game_effect)

	-- Add ui icon etc
	local perkIcon = EntityCreateNew("")
	EntityAddComponent(
		perkIcon,
		"UIIconComponent",
		{
			name = perkData.ui_name,
			description = perkData.ui_description,
			icon_sprite_file = perkData.ui_icon
		}
	)
	EntityAddChild(playerEntity, perkIcon)

	--local effect = EntityLoad("data/entities/misc/effect_protection_all.xml", x, y)
	--EntityAddChild(playerEntity, effect)
end

local function preparePlayer()
	local playerEntity = getPlayer()
	addEffectToEntity(playerEntity, "PROTECTION_ALL")

	addPerkToPlayer("BREATH_UNDERWATER")
	addPerkToPlayer("INVISIBILITY")
	addPerkToPlayer("REMOVE_FOG_OF_WAR")
	addPerkToPlayer("REPELLING_CAPE")
	addPerkToPlayer("WORM_DETRACTOR")

	setPlayerHP(CAPTURE_FORCE_HP)
end

local function resetPlayer()
	setPlayerHP(CAPTURE_FORCE_HP)
end

local function startCapturing()
	local ox, oy = getPlayerPos()
	ox, oy = math.floor(ox / CAPTURE_GRID_SIZE) * CAPTURE_GRID_SIZE, math.floor(oy / CAPTURE_GRID_SIZE) * CAPTURE_GRID_SIZE
	local x, y = ox, oy

	preparePlayer()

	GameSetCameraFree(true)

	-- Coroutine to calculate next coordinate, and trigger screenshots
	local i = 1
	async_loop(
		function()
			-- +x
			for i = 1, i, 1 do
				TriggerCapture(x * CAPTURE_PIXEL_SIZE, y * CAPTURE_PIXEL_SIZE)
				x, y = x + CAPTURE_GRID_SIZE, y
				GameSetCameraPos(x, y)
				wait(CAPTURE_DELAY)
			end
			-- +y
			for i = 1, i, 1 do
				TriggerCapture(x * CAPTURE_PIXEL_SIZE, y * CAPTURE_PIXEL_SIZE)
				x, y = x, y + CAPTURE_GRID_SIZE
				GameSetCameraPos(x, y)
				wait(CAPTURE_DELAY)
			end
			i = i + 1
			-- -x
			for i = 1, i, 1 do
				TriggerCapture(x * CAPTURE_PIXEL_SIZE, y * CAPTURE_PIXEL_SIZE)
				x, y = x - CAPTURE_GRID_SIZE, y
				GameSetCameraPos(x, y)
				wait(CAPTURE_DELAY)
			end
			-- -y
			for i = 1, i, 1 do
				TriggerCapture(x * CAPTURE_PIXEL_SIZE, y * CAPTURE_PIXEL_SIZE)
				x, y = x, y - CAPTURE_GRID_SIZE
				GameSetCameraPos(x, y)
				wait(CAPTURE_DELAY)
			end
			i = i + 1
		end
	)
end

-- #### UI ####

local gui = GuiCreate()

async_loop(
	function()
		if gui ~= nil then
			GuiStartFrame(gui)

			GuiLayoutBeginVertical(gui, 50, 20)
			if GuiButton(gui, 0, 0, "Start capturing map", 1) then
				startCapturing()
				GuiDestroy(gui)
				gui = nil
			end
			GuiTextCentered(gui, 0, 0, "Don't do anything while the capturing process is running!")
			GuiTextCentered(gui, 0, 0, "Use ESC and close the game to stop the process.")
			--[[if GuiButton(gui, 0, 0, "DEBUG globals", 1) then
				local file = io.open("mods/noita-mapcap/output/globals.txt", "w")
				for i, v in pairs(_G) do
					file:write(i .. "\n")
				end
				file:close()
			end]]
			GuiLayoutEnd(gui)
		end

		wait(0)
	end
)
