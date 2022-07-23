-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-----------------------
-- Load global stuff --
-----------------------

-- Emulate and override some functions and tables to make everything conform more to standard lua.
-- This will make `require` work, even in sandboxes with restricted Noita API.
local libPath = "mods/noita-mapcap/files/libraries/"
dofile(libPath .. "noita-api/compatibility.lua")(libPath)

if not async then
	require("coroutines") -- Loads Noita's coroutines library from `data/scripts/lib/coroutines.lua`.
end

-------------------------------
-- Load and run script files --
-------------------------------

dofile("mods/noita-mapcap/files/external.lua")
dofile("mods/noita-mapcap/files/capture.lua")
dofile("mods/noita-mapcap/files/ui.lua")

--------------------
-- Hook callbacks --
--------------------

---Called in order upon loading a new(?) game.
function OnModPreInit()
end

---Called in order upon loading a new(?) game.
function OnModInit()
end

---Called in order upon loading a new(?) game.
function OnModPostInit()
end

---Called when player entity has been created.
---Ensures chunks around the player have been loaded & created.
---@param playerEntityID integer
function OnPlayerSpawned(playerEntityID)
	modGUI = GuiCreate()
	GameSetCameraFree(true)

	-- Start entity capturing right when the player spawn.
	--DebugEntityCapture()
end

---Called when the player dies.
---@param playerEntityID integer
function OnPlayerDied(playerEntityID)
end

---Called once the game world is initialized.
---Doesn't ensure any chunks around the player.
function OnWorldInitialized()
end

---Called *every* time the game is about to start updating the world.
function OnWorldPreUpdate()
	-- Coroutines aren't run every frame in this lua sandbox, do it manually here.
	wake_up_waiting_threads(1)
end

---Called *every* time the game has finished updating the world.
function OnWorldPostUpdate()
end

---Called when the biome config is loaded.
function OnBiomeConfigLoaded()
end

---The last point where the Mod API is available.
---After this materials.xml will be loaded.
function OnMagicNumbersAndWorldSeedInitialized()
end

---Called when the game is paused or unpaused.
---@param isPaused boolean
---@param isInventoryPause boolean
function OnPausedChanged(isPaused, isInventoryPause)
end

---Will be called when the game is unpaused, if player changed any mod settings while the game was paused.
function OnModSettingsChanged()
end

---Will be called when the game is paused, either by the pause menu or some inventory menus.
---Please be careful with this, as not everything will behave well when called while the game is paused.
function OnPausePreUpdate()
end

---------------
-- Overrides --
---------------

-- Override virtual resolution and some other stuff.
ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic_numbers.xml")

-- Remove hover animation of newly created perks.
ModLuaFileAppend("data/scripts/perks/perk.lua", "mods/noita-mapcap/files/overrides/perks/perk.lua")
