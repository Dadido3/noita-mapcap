-- Copyright (c) 2022 David Vogel
-- 
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

dofile("mods/noita-mapcap/files/init.lua")

function OnPlayerSpawned(player_entity)
	--EntityLoad("mods/noita-mapcap/files/luacomponent.xml") -- ffi isn't accessible from inside lua components, scrap that idea
	modGUI = GuiCreate()
	GameSetCameraFree(true)

	-- Start entity capturing right when the player spawn.
	--DebugEntityCapture()
end

-- Called *every* time the game is about to start updating the world
function OnWorldPreUpdate()
	wake_up_waiting_threads(1) -- Coroutines aren't run every frame in this sandbox, do it manually here.
end

-- Called *every* time the game has finished updating the world
function OnWorldPostUpdate() end

ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic_numbers.xml") -- override some game constants

-- Apply overrides.
ModLuaFileAppend("data/scripts/perks/perk.lua", "mods/noita-mapcap/files/overrides/perks/perk.lua")
