-- Copyright (c) 2022-2023 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Noita settings/configuration modifications.
-- We try to keep persistent modifications to a minimum, but some things have to be changed in order for the mod to work correctly.

-- There are 4 ways Noita can be modified by code:
-- - `config.xml`: These are persistent, and Noita needs to be force closed when changed from inside a mod.
-- - `magic_numbers.xml`: Persistent per world, can only be applied at mod startup.
-- - Process memory: Volatile, can be modified at runtime. Needs correct memory addresses to function.
-- - File patching: Volatile, can only be applied at mod startup.

--------------------------
-- Load library modules --
--------------------------

local CameraAPI = require("noita-api.camera")
local Coords = require("coordinates")
local ffi = require("ffi")
local Memory = require("memory")
local NXML = require("luanxml.nxml")
local Utils = require("noita-api.utils")
local Vec2 = require("noita-api.vec2")
local DebugAPI = require("noita-api.debug")

----------
-- Code --
----------

---Reads the current config from `config.xml` and returns it as table.
---@return table<string, string> config
function Modification.GetConfig()
	local configFilename = Utils.GetSpecialDirectory("save-shared") .. "config.xml"

	-- Read and modify config.
	local f, err = io.open(configFilename, "r")
	if not f then error(string.format("failed to read config file: %s", err)) end
	local xml = NXML.parse(f:read("*a"))

	f:close()

	return xml.attr
end

---Will update Noita's `config.xml` with the values in the given table.
---
---This will force close Noita!
---@param config table<string, string> -- List of `config.xml` attributes that should be changed.
function Modification.SetConfig(config)
	local configFilename = Utils.GetSpecialDirectory("save-shared") .. "config.xml"

	-- Read and modify config.
	local f, err = io.open(configFilename, "r")
	if not f then error(string.format("failed to read config file: %s", err)) end
	local xml = NXML.parse(f:read("*a"))

	for k, v in pairs(config) do
		xml.attr[k] = v
	end

	f:close()

	-- Write modified config back.
	local f, err = io.open(configFilename, "w")
	if not f then error(string.format("failed to create config file: %s", err)) end
	f:write(tostring(xml))
	f:close()

	-- We need to force close Noita, so it doesn't have any chance to overwrite the file.
	os.exit(0)
end

---Will update Noita's `magic_numbers.xml` with the values in the given table.
---
---Should be called on mod initialization only.
---@param magic table<string, string> -- List of `magic_numbers.xml` attributes that should be changed.
function Modification.SetMagicNumbers(magic)
	local xml = NXML.new_element("MagicNumbers", magic)

	-- Write magic number file.
	local f, err = io.open("mods/noita-mapcap/files/magic-numbers/generated.xml", "w")
	if not f then error(string.format("failed to create config file: %s", err)) end
	f:write(tostring(xml))
	f:close()

	ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic-numbers/generated.xml")
end

---Changes some options directly by manipulating process memory.
---
---Related issue: https://github.com/Dadido3/noita-mapcap/issues/14.
---@param memory table
function Modification.SetMemoryOptions(memory)
	-- Lookup table with the following hierarchy:
	-- DevBuild -> OS -> BuildDate -> Option -> ModFunc.
	local lookup = {
		[true] = {
			Windows = {
				{_Offset = 0x00F77B0C, _BuildString = "Build Apr 23 2021 18:36:55", -- GOG dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x010E3B6C)[0] = value end, -- Can be found by using Cheat Engine while toggling options in the F7 menu.
					mGuiDisabled = function(value) ffi.cast("char*", 0x010E3B6D)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x010E3B6E)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x010E3B6F)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x010E3B70)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x010E3B71)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x010E3B72)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x010E3B73)[0] = value end,
				},
				{_Offset = 0x00F80384, _BuildString = "Build Apr 23 2021 18:40:40", -- Steam dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x010EDEBC)[0] = value end,
					mGuiDisabled = function(value) ffi.cast("char*", 0x010EDEBD)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x010EDEBE)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x010EDEBF)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x010EDEC0)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x010EDEC1)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x010EDEC2)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x010EDEC3)[0] = value end,
				},
				{_Offset = 0x00F8A7B4, _BuildString = "Build Mar 11 2023 14:05:19", -- Steam dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x010F80EC)[0] = value end,
					mGuiDisabled = function(value) ffi.cast("char*", 0x010F80ED)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x010F80EE)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x010F80EF)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x010F80F0)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x010F80F1)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x010F80F2)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x010F80F3)[0] = value end,
				},
				{_Offset = 0x00F8A8A4, _BuildString = "Build Jun 19 2023 14:14:52", -- Steam dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x010F810C)[0] = value end,
					mGuiDisabled = function(value) ffi.cast("char*", 0x010F810D)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x010F810E)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x010F810F)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x010F8110)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x010F8111)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x010F8112)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x010F8113)[0] = value end,
				},
				{_Offset = 0x00F82464, _BuildString = "Build Jul 26 2023 23:06:16", -- Steam dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x010E9A5C)[0] = value end,
					mGuiDisabled = function(value) ffi.cast("char*", 0x010E9A5D)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x010E9A5E)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x010E9A5F)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x010E9A60)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x010E9A61)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x010E9A62)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x010E9A63)[0] = value end,
				},
				{_Offset = 0x00FA654C, _BuildString = "Build Dec 19 2023 18:34:31", -- Steam dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x011154BC)[0] = value end,
					mGuiDisabled = function(value) ffi.cast("char*", 0x011154BD)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x011154BE)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x011154BF)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x011154C0)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x011154C1)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x011154C2)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x011154C3)[0] = value end,
				},
				{_Offset = 0x00F8A9DC, _BuildString = "Build Dec 21 2023 00:07:29", -- Steam dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x010F814C)[0] = value end,
					mGuiDisabled = function(value) ffi.cast("char*", 0x010F814D)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x010F814E)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x010F814F)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x010F8150)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x010F8151)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x010F8152)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x010F8153)[0] = value end,
				},
				{_Offset = 0x00F71DE4, _BuildString = "Build Dec 29 2023 23:36:18", -- Steam dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x0111758C)[0] = value end,
					mGuiDisabled = function(value) ffi.cast("char*", 0x0111758D)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x0111758E)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x0111758F)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x01117590)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x01117591)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x01117592)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x01117593)[0] = value end,
				},
				{_Offset = 0x00F74FA8, _BuildString = "Build Dec 30 2023 19:37:04", -- Steam dev build.
					mPostFxDisabled = function(value) ffi.cast("char*", 0x0111A5BC)[0] = value end,
					mGuiDisabled = function(value) ffi.cast("char*", 0x0111A5BD)[0] = value end,
					mGuiHalfSize = function(value) ffi.cast("char*", 0x0111A5BE)[0] = value end,
					mFogOfWarOpenEverywhere = function(value) ffi.cast("char*", 0x0111A5BF)[0] = value end,
					mTrailerMode = function(value) ffi.cast("char*", 0x0111A5C0)[0] = value end,
					mDayTimeRotationPause = function(value) ffi.cast("char*", 0x0111A5C1)[0] = value end,
					mPlayerNeverDies = function(value) ffi.cast("char*", 0x0111A5C2)[0] = value end,
					mFreezeAI = function(value) ffi.cast("char*", 0x0111A5C3)[0] = value end,
				},
			},
		},
		[false] = {
			Windows = {
				{_Offset = 0x00E1C550, _BuildString = "Build Apr 23 2021 18:44:24", -- Steam build.
					enableModDetection = function(value)
						local ptr = ffi.cast("char*", 0x0063D8AD) -- Can be found by searching for the pattern C6 80 20 01 00 00 >01< 8B CF E8 FB 1D. The pointer has to point to the highlighted byte.
						Memory.VirtualProtect(ptr, 1, Memory.PAGE_EXECUTE_READWRITE)
						ptr[0] = value -- This basically just changes the value that Noita forces to the "mods_have_been_active_during_this_run" member of the WorldStateComponent when any mod is enabled.
					end,
				},
				{_Offset = 0x00E22E18, _BuildString = "Build Mar 11 2023 14:09:24", -- Steam build.
					enableModDetection = function(value)
						local ptr = ffi.cast("char*", 0x006429ED)
						Memory.VirtualProtect(ptr, 1, Memory.PAGE_EXECUTE_READWRITE)
						ptr[0] = value -- This basically just changes the value that Noita forces to the "mods_have_been_active_during_this_run" member of the WorldStateComponent when any mod is enabled.
					end,
				},
				{_Offset = 0x00E22E18, _BuildString = "Build Jun 19 2023 14:18:46", -- Steam build.
					enableModDetection = function(value)
						local ptr = ffi.cast("char*", 0x006429ED)
						Memory.VirtualProtect(ptr, 1, Memory.PAGE_EXECUTE_READWRITE)
						ptr[0] = value -- This basically just changes the value that Noita forces to the "mods_have_been_active_during_this_run" member of the WorldStateComponent when any mod is enabled.
					end,
				},
				{_Offset = 0x00E146D4, _BuildString = "Build Jul 26 2023 23:10:16", -- Steam build.
					enableModDetection = function(value)
						local ptr = ffi.cast("char*", 0x0064390D)
						Memory.VirtualProtect(ptr, 1, Memory.PAGE_EXECUTE_READWRITE)
						ptr[0] = value -- This basically just changes the value that Noita forces to the "mods_have_been_active_during_this_run" member of the WorldStateComponent when any mod is enabled.
					end,
				},
				{_Offset = 0x00E333F4, _BuildString = "Build Dec 19 2023 18:38:23", -- Steam build.
					enableModDetection = function(value)
						local ptr = ffi.cast("char*", 0x00624C5D)
						Memory.VirtualProtect(ptr, 1, Memory.PAGE_EXECUTE_READWRITE)
						ptr[0] = value -- This basically just changes the value that Noita forces to the "mods_have_been_active_during_this_run" member of the WorldStateComponent when any mod is enabled.
					end,
				},
				{_Offset = 0x00E23EC4, _BuildString = "Build Dec 21 2023 00:11:06", -- Steam build.
					enableModDetection = function(value)
						local ptr = ffi.cast("char*", 0x0064246D)
						Memory.VirtualProtect(ptr, 1, Memory.PAGE_EXECUTE_READWRITE)
						ptr[0] = value -- This basically just changes the value that Noita forces to the "mods_have_been_active_during_this_run" member of the WorldStateComponent when any mod is enabled.
					end,
				},
				{_Offset = 0x00E14FA0, _BuildString = "Build Dec 29 2023 23:40:18", -- Steam build.
					enableModDetection = function(value)
						local ptr = ffi.cast("char*", 0x00625FFD)
						Memory.VirtualProtect(ptr, 1, Memory.PAGE_EXECUTE_READWRITE)
						ptr[0] = value -- This basically just changes the value that Noita forces to the "mods_have_been_active_during_this_run" member of the WorldStateComponent when any mod is enabled.
					end,
				},
				{_Offset = 0x00E180E8, _BuildString = "Build Dec 30 2023 19:40:49", -- Steam build.
					enableModDetection = function(value)
						local ptr = ffi.cast("char*", 0x00626EFD)
						Memory.VirtualProtect(ptr, 1, Memory.PAGE_EXECUTE_READWRITE)
						ptr[0] = value -- This basically just changes the value that Noita forces to the "mods_have_been_active_during_this_run" member of the WorldStateComponent when any mod is enabled.
					end,
				},
			},
		},
	}

	-- Look up the tree and set options accordingly.

	local level1 = lookup[DebugGetIsDevBuild()]
	level1 = level1 or {}

	local level2 = level1[ffi.os]
	level2 = level2 or {}

	local level3 = {}
	for _, v in ipairs(level2) do
		if ffi.string(ffi.cast("char*", v._Offset)) == v._BuildString then
			level3 = v
			break
		end
	end

	for k, v in pairs(memory) do
		local modFunc = level3[k]
		if modFunc ~= nil then
			modFunc(v)
		else
			Message:ShowModificationUnsupported("processMemory", k, v)
		end
	end
end

---Applies patches to game files based on in the given table.
---
---Should be called on mod initialization only.
---@param patches table
function Modification.PatchFiles(patches)
	-- Change constants in post_final.frag.
	if patches.PostFinalConst then
		local postFinal = ModTextFileGetContent("data/shaders/post_final.frag")
		for k, v in pairs(patches.PostFinalConst) do
			postFinal = postFinal:gsub(string.format(" %s%%s+=[^;]+;", k), string.format(" %s = %s;", k, tostring(v)), 1)
		end
		ModTextFileSetContent("data/shaders/post_final.frag", postFinal)
	end
end

---Returns tables with user requested game configuration changes.
---@return table config -- List of `config.xml` attributes that should be changed.
---@return table magic -- List of `magic_number.xml` attributes that should be changed.
---@return table memory -- List of options in RAM of this process that should be changed.
---@return table patches -- List of patches that should be applied to game files.
function Modification.RequiredChanges()
	local config, magic, memory, patches = {}, {}, {}, {}

	-- Does the user request a custom resolution?
	local customResolution = (ModSettingGet("noita-mapcap.custom-resolution-live") and ModSettingGet("noita-mapcap.capture-mode") == "live")
		or (ModSettingGet("noita-mapcap.custom-resolution-other") and ModSettingGet("noita-mapcap.capture-mode") ~= "live")

	if customResolution then
		config["window_w"] = tostring(Vec2(ModSettingGet("noita-mapcap.window-resolution")).x)
		config["window_h"] = tostring(Vec2(ModSettingGet("noita-mapcap.window-resolution")).y)
		config["internal_size_w"] = tostring(Vec2(ModSettingGet("noita-mapcap.internal-resolution")).x)
		config["internal_size_h"] = tostring(Vec2(ModSettingGet("noita-mapcap.internal-resolution")).y)
		config["backbuffer_width"] = config["window_w"]
		config["backbuffer_height"] = config["window_h"]
		magic["VIRTUAL_RESOLUTION_X"] = tostring(Vec2(ModSettingGet("noita-mapcap.virtual-resolution")).x)
		magic["VIRTUAL_RESOLUTION_Y"] = tostring(Vec2(ModSettingGet("noita-mapcap.virtual-resolution")).y)
		-- Set virtual offset to prevent/reduce not correctly drawn pixels at the window border.
		magic["GRID_RENDER_BORDER"] = "3" -- This will widen the right side of the virtual rectangle. It also shifts the world coordinates to the right.
		magic["VIRTUAL_RESOLUTION_OFFSET_X"] = "-3"
		magic["VIRTUAL_RESOLUTION_OFFSET_Y"] = "0"
	else
		-- Reset some values if there is no custom resolution requested.
		config["internal_size_w"] = "1280"
		config["internal_size_h"] = "720"
		magic["VIRTUAL_RESOLUTION_X"] = "427"
		magic["VIRTUAL_RESOLUTION_Y"] = "242"
		magic["GRID_RENDER_BORDER"] = "2"
		magic["VIRTUAL_RESOLUTION_OFFSET_X"] = "-1"
		magic["VIRTUAL_RESOLUTION_OFFSET_Y"] = "-1"
	end

	-- Always expect a fullscreen mode of 0 (windowed).
	-- Capturing will not work in fullscreen.
	config["fullscreen"] = "0"

	-- Also disable screen shake.
	config["screenshake_intensity"] = "0"

	magic["DRAW_PARALLAX_BACKGROUND"] = ModSettingGet("noita-mapcap.disable-background") and "0" or "1"

	-- These magic numbers seem only to work in the dev build.
	magic["DEBUG_PAUSE_GRID_UPDATE"] = ModSettingGet("noita-mapcap.disable-physics") and "1" or "0"
	magic["DEBUG_PAUSE_BOX2D"] = ModSettingGet("noita-mapcap.disable-physics") and "1" or "0"
	magic["DEBUG_DISABLE_POSTFX_DITHERING"] = ModSettingGet("noita-mapcap.disable-postfx") and "1" or "0"

	-- These magic numbers stop any grid updates (pixel physics), even in the release build.
	-- But any Box2D objects glitch, therefore the mod option (disable-physics) is disabled and hidden in the non dev build.
	--magic["GRID_MAX_UPDATES_PER_FRAME"] = ModSettingGet("noita-mapcap.disable-physics") and "0" or "128"
	--magic["GRID_MIN_UPDATES_PER_FRAME"] = ModSettingGet("noita-mapcap.disable-physics") and "1" or "40"

	if ModSettingGet("noita-mapcap.disable-postfx") then
		patches.PostFinalConst = {
			ENABLE_REFRACTION       = false,
			ENABLE_LIGHTING         = false,
			ENABLE_FOG_OF_WAR       = false,
			ENABLE_GLOW             = false,
			ENABLE_GAMMA_CORRECTION = false,
			ENABLE_PATH_DEBUG       = false,
			FOG_FOREGROUND          = "vec4(0.0,0.0,0.0,1.0)",
			FOG_BACKGROUND          = "vec3(0.0,0.0,0.0)",
			FOG_FOREGROUND_NIGHT    = "vec4(0.0,0.0,0.0,1.0)",
			FOG_BACKGROUND_NIGHT    = "vec3(0.0,0.0,0.0)",
		}
	end

	if ModSettingGet("noita-mapcap.disable-shaders-gui-ai") and DebugAPI.IsDevBuild() then
		memory["mPostFxDisabled"] = 1
		memory["mGuiDisabled"] = 1
		memory["mFreezeAI"] = 1
		memory["mTrailerMode"] = 1 -- Is necessary for chunks to correctly load when DEBUG_PAUSE_GRID_UPDATE is enabled.
	end

	if ModSettingGet("noita-mapcap.disable-mod-detection") and not DebugAPI.IsDevBuild() then
		memory["enableModDetection"] = 0
	else
		-- Don't actively (re)enable mod detection.
		--memory["enableModDetection"] = 1
	end

	-- Disables or hides most of the UI.
	-- The game is still somewhat playable this way.
	if ModSettingGet("noita-mapcap.disable-ui") then
		magic["INVENTORY_GUI_ALWAYS_VISIBLE"] = "0"
		magic["UI_BARS2_OFFSET_X"] = "100"
	else
		-- Reset to default.
		magic["INVENTORY_GUI_ALWAYS_VISIBLE"] = "1"
		magic["UI_BARS2_OFFSET_X"] = "-40"
	end

	return config, magic, memory, patches
end

---Sets the camera free if required by the mod settings.
---@param force boolean|nil -- If true, the camera will be set free regardless.
function Modification.SetCameraFree(force)
	if force ~= nil then CameraAPI.SetCameraFree(force) return end

	local captureMode = ModSettingGet("noita-mapcap.capture-mode")
	local spiralOrigin = ModSettingGet("noita-mapcap.capture-mode-spiral-origin")

	-- Allow free roaming when in spiral mode with origin being the current position.
	if captureMode == "spiral" and spiralOrigin == "current" then
		CameraAPI.SetCameraFree(true)
		return
	end

	CameraAPI.SetCameraFree(false)
end

---Will change the game settings according to `Modification.RequiredChanges()`.
---
---This will force close Noita!
function Modification.AutoSet()
	local config, magic = Modification.RequiredChanges()
	Modification.SetConfig(config)
end

---Will reset all persistent settings that may have been changed by this mod.
---
---This will force close Noita!
function Modification.Reset()
	local config = {
		window_w = "1280",
		window_h = "720",
		internal_size_w = "1280",
		internal_size_h = "720",
		backbuffer_width = "1280",
		backbuffer_height = "720",
		screenshake_intensity = "0.7",
	}

	Modification.SetConfig(config)
end
