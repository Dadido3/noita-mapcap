-- Copyright (c) 2022-2024 David Vogel
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

-- TODO: Replace Noita's coroutine lib with something better
if not async then
	require("coroutines") -- Loads Noita's coroutines library from `data/scripts/lib/coroutines.lua`.
end

--------------------------
-- Load library modules --
--------------------------

local CameraAPI = require("noita-api.camera")
local Coords = require("coordinates")
local DebugAPI = require("noita-api.debug")
local LiveReload = require("noita-api.live-reload")
local Vec2 = require("noita-api.vec2")

-----------------------
-- Global namespaces --
-----------------------

Capture = Capture or {}
Check = Check or {}
Config = Config or {}
Message = Message or {}
Modification = Modification or {}
UI = UI or {}

-------------------------------
-- Load and run script files --
-------------------------------

dofile("mods/noita-mapcap/files/capture.lua")
dofile("mods/noita-mapcap/files/config.lua")
dofile("mods/noita-mapcap/files/check.lua")
dofile("mods/noita-mapcap/files/message.lua")
dofile("mods/noita-mapcap/files/modification.lua")
dofile("mods/noita-mapcap/files/ui.lua")

--------------------
-- Hook callbacks --
--------------------

---Called in order upon loading a new(?) game.
function OnModPreInit()
	if ModSettingGet("noita-mapcap.seed") ~= "" then
		SetWorldSeed(tonumber(ModSettingGet("noita-mapcap.seed")) or 0)
	end

	-- Read Noita's config to be used in checks later on.
	Check.StartupConfig = Modification.GetConfig()

	-- Set magic numbers and other stuff based on mod settings.
	local config, magic, memory, patches = Modification.RequiredChanges()
	Modification.SetMagicNumbers(magic)
	Modification.SetMemoryOptions(memory)
	Modification.PatchFiles(patches)

	-- Override virtual resolution and some other stuff.
	--ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic-numbers/1024.xml")
	ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic-numbers/fast-cam.xml")
	--ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic-numbers/no-ui.xml")
	--ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic-numbers/offset.xml")

	-- Remove hover animation of newly created perks.
	ModLuaFileAppend("data/scripts/perks/perk.lua", "mods/noita-mapcap/files/overrides/perks/perk.lua")
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
	-- Set camera free based on mod settings.
	-- We need to do this here, otherwise it will bug up or delete the player entity.
	Modification.SetCameraFree()
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
	Message:CatchException("OnWorldPreUpdate", function()
		-- Coroutines aren't run every frame in this lua sandbox, do it manually here.
		wake_up_waiting_threads(1)

	end)
end

---Called *every* time the game has finished updating the world.
function OnWorldPostUpdate()
	Message:CatchException("OnWorldPostUpdate", function()
		-- Reload mod every 60 frames.
		-- This allows live updates to the mod while Noita is running.
		-- !!! DISABLE THE FOLLOWING LINE BEFORE COMMITTING !!!
		--LiveReload:Reload("mods/noita-mapcap/", 60)

		-- Run checks every 60 frames.
		Check:Regular(60)

		-- Draw UI after coroutines have been resumed.
		UI:Draw()

	end)
end

---Called when the biome config is loaded.
function OnBiomeConfigLoaded()
end

---The last point where the Mod API is available.
---After this materials.xml will be loaded.
function OnMagicNumbersAndWorldSeedInitialized()
	-- Get resolutions for correct coordinate transformations.
	-- This needs to be done once all magic numbers are set.
	Coords:ReadResolutions()

	Check:Startup()
end

---Called when the game is paused or unpaused.
---@param isPaused boolean
---@param isInventoryPause boolean
function OnPausedChanged(isPaused, isInventoryPause)
	Message:CatchException("OnPausedChanged", function()
		-- Set some stuff based on mod settings.
		-- Normally this would be in `OnModSettingsChanged`, but that doesn't seem to be called.
		local config, magic, memory, patches = Modification.RequiredChanges()
		Modification.SetMemoryOptions(memory)

	end)
end

---Will be called when the game is unpaused, if player changed any mod settings while the game was paused.
function OnModSettingsChanged()
end

---Will be called when the game is paused, either by the pause menu or some inventory menus.
---Please be careful with this, as not everything will behave well when called while the game is paused.
function OnPausePreUpdate()
end
