-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Check if everything is alright.
-- This does mainly trigger user messages and suggest actions.

-----------------------
-- Load global stuff --
-----------------------

--------------------------
-- Load library modules --
--------------------------

local Coords = require("coordinates")
local ScreenCap = require("screen-capture")
local Vec2 = require("noita-api.vec2")
local Utils = require("noita-api.utils")

----------
-- Code --
----------

---Runs a list of checks at addon startup.
function Check:Startup()
	if Utils.FileExists("mods/noita-mapcap/output/nonempty") then
		Message:ShowOutputNonEmpty()
	end

	if not Utils.FileExists("mods/noita-mapcap/bin/capture-b/capture.dll") then
		Message:ShowGeneralInstallationProblem("`capture.dll` is missing.", "Make sure you have installed the mod correctly.")
	end

	if not Utils.FileExists("mods/noita-mapcap/bin/stitch/stitch.exe") then
		Message:ShowGeneralInstallationProblem("`stitch.exe` is missing.", "Make sure you have installed the mod correctly.", " ", "You can still use the mod to capture, though.")
	end
end

---Regularly runs a list of checks.
---@param interval integer -- Check interval in frames.
function Check:Regular(interval)
	interval = interval or 60
	self.Counter = (self.Counter or 0) - 1
	if self.Counter > 0 then return end
	self.Counter = interval

	-- Remove some messages, so they will automatically disappear when the problem is solved.
	Message:CloseAutoClose()

	-- Compare Noita config and actual window resolution.
	local topLeft, bottomRight = ScreenCap.GetRect() -- Actual window client area.
	if topLeft and bottomRight then
		local actual = bottomRight - topLeft
		if actual ~= Coords.WindowResolution then
			Message:ShowWrongResolution(Modification.AutoSet, string.format("Old window resolution is %s. Current resolution is %s.", Coords.WindowResolution, actual))
		end
	else
		Message:ShowRuntimeError("GetRect", "Couldn't determine window resolution.")
	end

	-- Check if we have the required settings.
	local config, magic, patches = Modification.RequiredChanges()
	if config["fullscreen"] then
		local expected = tonumber(config["fullscreen"])
		if expected ~= Coords.FullscreenMode then
			Message:ShowSetNoitaSettings(Modification.AutoSet, string.format("Fullscreen mode %s. Expected %s.", Coords.FullscreenMode, expected))
		end
	end
	if config["window_w"] and config["window_h"] then
		local expected = Vec2(tonumber(config["window_w"]), tonumber(config["window_h"]))
		if expected ~= Coords.WindowResolution then
			Message:ShowSetNoitaSettings(Modification.AutoSet, string.format("Window resolution is %s. Expected %s.", Coords.WindowResolution, expected))
		end
	end
	if config["internal_size_w"] and config["internal_size_h"] then
		local expected = Vec2(tonumber(config["internal_size_w"]), tonumber(config["internal_size_h"]))
		if expected ~= Coords.InternalResolution then
			Message:ShowSetNoitaSettings(Modification.AutoSet, string.format("Internal resolution is %s. Expected %s.", Coords.InternalResolution, expected))
		end
	end
	if config["screenshake_intensity"] then
		local expected = config.screenshake_intensity
		if expected ~= self.StartupConfig.screenshake_intensity then
			Message:ShowSetNoitaSettings(Modification.AutoSet, string.format("Screen shake intensity is %s, expected %s.", self.StartupConfig.screenshake_intensity, expected))
		end
	end

	-- Magic numbers stuff doesn't need a forced restart, just a normal restart by the user.
	if magic["VIRTUAL_RESOLUTION_X"] and magic["VIRTUAL_RESOLUTION_Y"] then
		local expected = Vec2(tonumber(magic["VIRTUAL_RESOLUTION_X"]), tonumber(magic["VIRTUAL_RESOLUTION_Y"]))
		if expected ~= Coords.VirtualResolution then
			Message:ShowRequestRestart(string.format("Virtual resolution is %s. Expected %s.", Coords.VirtualResolution, expected))
		end
	end
	if magic["VIRTUAL_RESOLUTION_OFFSET_X"] and magic["VIRTUAL_RESOLUTION_OFFSET_Y"] then
		local expected = Vec2(tonumber(magic["VIRTUAL_RESOLUTION_OFFSET_X"]), tonumber(magic["VIRTUAL_RESOLUTION_OFFSET_Y"]))
		if expected ~= Coords.VirtualOffset then
			Message:ShowRequestRestart(string.format("Virtual offset is %s. Expected %s.", Coords.VirtualOffset, expected))
		end
	end

	-- Request a restart if the user has changed specific mod settings.
	local restartModSettings = {"disable-background", "disable-ui", "disable-physics", "disable-postfx"}
	for i, v in ipairs(restartModSettings) do
		local settingID = "noita-mapcap." .. v
		if ModSettingGetNextValue(settingID) ~= ModSettingGet(settingID) then
			Message:ShowRequestRestart(string.format("Setting %s got changed from %s to %s.", v, tostring(ModSettingGet(settingID)), tostring(ModSettingGetNextValue(settingID))))
		end
	end

	-- Check if capture grid size is smaller than the virtual resolution.
	-- This is not perfect, as it doesn't take rounding and cropping into account, so the actual captured area may be a few pixels smaller.
	local mode = ModSettingGet("noita-mapcap.capture-mode")
	local captureGridSize = tonumber(ModSettingGet("noita-mapcap.grid-size"))
	if mode ~= "live" and (Coords.VirtualResolution.x < captureGridSize or Coords.VirtualResolution.y < captureGridSize) then
		Message:ShowGeneralSettingsProblem(
			"The virtual resolution is smaller than the capture grid size.",
			"This means that you will get black areas in your final stitched image.",
			" ",
			"Apply either of the following in the mod settings:",
			string.format("- Set the grid size to at most %s.", math.min(Coords.VirtualResolution.x, Coords.VirtualResolution.y)),
			string.format("- Increase the custom resolutions to at least %s in any direction.", captureGridSize),
			"- Change capture mode to `live`."
		)
	end

end
