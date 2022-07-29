-- Copyright (c) 2022 David Vogel
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
local NXML = require("luanxml.nxml")
local Utils = require("noita-api.utils")
local Vec2 = require("noita-api.vec2")

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
	-- DevBuild -> OS -> BuildDate -> Option -> Address.
	local lookup = {
		[true] = {
			Windows = {
				[0x00F77B0C] = { _BuildString = "Build Apr 23 2021 18:36:55", -- GOG build.
					mPostFxDisabled = 0x010E3B6C,
					mGuiDisabled = 0x010E3B6D,
					mGuiHalfSize = 0x010E3B6E,
					mFogOfWarOpenEverywhere = 0x010E3B6F,
					mTrailerMode = 0x010E3B70,
					mDayTimeRotationPause = 0x010E3B71,
					mPlayerNeverDies = 0x010E3B72,
					mFreezeAI = 0x010E3B73,
				},
				[0x00F80384] = { _BuildString = "Build Apr 23 2021 18:40:40", -- Steam build.
					mPostFxDisabled = 0x010EDEBC,
					mGuiDisabled = 0x010EDEBD,
					mGuiHalfSize = 0x010EDEBE,
					mFogOfWarOpenEverywhere = 0x010EDEBF,
					mTrailerMode = 0x010EDEC0,
					mDayTimeRotationPause = 0x010EDEC1,
					mPlayerNeverDies = 0x010EDEC2,
					mFreezeAI = 0x010EDEC3,
				},
			},
		},
	}

	-- Look up the tree and set options accordingly.

	local level1 = lookup[DebugGetIsDevBuild()]
	if level1 == nil then return end

	local level2 = level1[ffi.os]
	if level2 == nil then return end

	local level3
	for k, v in pairs(level2) do
		if ffi.string(ffi.cast("char*", k)) == v._BuildString then
			level3 = v
			break
		end
	end

	for k, v in pairs(memory) do
		local address = level3[k]
		if address ~= nil then
			ffi.cast("char*", address)[0] = v
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
			postFinal = postFinal:gsub(string.format("const bool %s%%s+=[^;]+;", k), string.format("const bool %s = %s;", k, tostring(v)))
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
	else
		-- Only reset some stuff that is independent to the users chosen resolution.
		config["internal_size_w"] = "1280"
		config["internal_size_h"] = "720"
		magic["VIRTUAL_RESOLUTION_X"] = "427"
		magic["VIRTUAL_RESOLUTION_Y"] = "242"
	end

	-- Set virtual offset to prevent/reduce not correctly drawn pixels at the window border.
	magic["GRID_RENDER_BORDER"] = "3" -- This will widen the right side of the virtual rectangle. It also shifts the world coordinates to the right.
	magic["VIRTUAL_RESOLUTION_OFFSET_X"] = "-3"
	magic["VIRTUAL_RESOLUTION_OFFSET_Y"] = "0"

	-- Always expect a fullscreen mode of 0 (windowed).
	-- Capturing will not work in fullscreen.
	config["fullscreen"] = "0"

	-- Also disable screenshake.
	config["screenshake_intensity"] = "0"

	magic["DRAW_PARALLAX_BACKGROUND"] = ModSettingGet("noita-mapcap.disable-background") and "0" or "1"

	-- These magic numbers seem only to work in the dev build.
	magic["DEBUG_PAUSE_GRID_UPDATE"] = ModSettingGet("noita-mapcap.disable-physics") and "1" or "0"
	magic["DEBUG_PAUSE_BOX2D"] = ModSettingGet("noita-mapcap.disable-physics") and "1" or "0"
	magic["DEBUG_DISABLE_POSTFX_DITHERING"] = ModSettingGet("noita-mapcap.disable-postfx") and "1" or "0"

	if ModSettingGet("noita-mapcap.disable-postfx") then
		patches.PostFinalConst = {
			ENABLE_REFRACTION       = false,
			ENABLE_LIGHTING         = false,
			ENABLE_FOG_OF_WAR       = false,
			ENABLE_GLOW             = false,
			ENABLE_GAMMA_CORRECTION = false,
			ENABLE_PATH_DEBUG       = false,
		}
	end

	if ModSettingGet("noita-mapcap.disable-shaders-gui-ai") then
		memory["mPostFxDisabled"] = 1
		memory["mGuiDisabled"] = 1
		memory["mFreezeAI"] = 1
		memory["mTrailerMode"] = 1 -- Is necessary for chunks to correctly load when DEBUG_PAUSE_GRID_UPDATE is enabled.
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
