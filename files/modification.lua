-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Noita settings/configuration modifications.
-- We try to keep non volatile modifications to a minimum, but some things have to be changed in order for the mod to work correctly.

--------------------------
-- Load library modules --
--------------------------

local CameraAPI = require("noita-api.camera")
local Coords = require("coordinates")
local NXML = require("luanxml.nxml")
local Utils = require("noita-api.utils")
local Vec2 = require("noita-api.vec2")

----------
-- Code --
----------

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

---Returns tables with user requested game configuration changes.
---@return table config -- List of `config.xml` attributes that should be changed.
---@return table magic -- List of `magic_number.xml` attributes that should be changed.
function Modification.RequiredChanges()
	local config, magic = {}, {}

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
	end

	-- Set virtual offset to be pixel perfect.
	magic["VIRTUAL_RESOLUTION_OFFSET_X"] = tostring(Coords.VirtualOffsetPixelPerfect.x)
	magic["VIRTUAL_RESOLUTION_OFFSET_Y"] = tostring(Coords.VirtualOffsetPixelPerfect.y)

	-- Always expect a fullscreen mode of 0 (windowed).
	-- Capturing will not work in fullscreen.
	config["fullscreen"] = "0"

	magic["DRAW_PARALLAX_BACKGROUND"] = ModSettingGet("noita-mapcap.disable-background") and "0" or "1"
	magic["DEBUG_PAUSE_GRID_UPDATE"] = ModSettingGet("noita-mapcap.disable-physics") and "1" or "0"
	magic["DEBUG_PAUSE_BOX2D"] = ModSettingGet("noita-mapcap.disable-physics") and "1" or "0"
	magic["DEBUG_DISABLE_POSTFX_DITHERING"] = ModSettingGet("noita-mapcap.disable-postfx") and "1" or "0"

	return config, magic
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

---Will reset all settings that may have been changed by this mod.
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
	}

	Modification.SetConfig(config)
end
