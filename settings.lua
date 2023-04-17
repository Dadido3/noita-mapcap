-- Copyright (c) 2022-2023 David Vogel
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

-- TODO: Replace Noita's mod settings lib with something better. Or at least wrap it: https://stackoverflow.com/questions/9540732/loadfile-without-polluting-global-environment
require("mod_settings") -- Loads Noita's mod settings library from `data/scripts/lib/mod_settings.lua`.

--------------------------
-- Load library modules --
--------------------------

local DebugAPI = require("noita-api.debug")

-------------------------------
-- Load and run script files --
-------------------------------

----------
-- Code --
----------

---Custom button gadget for the settings menu.
---@param modID string
---@param gui any
---@param inMainMenu boolean
---@param imID any
---@param setting table
local function customSettingButton(modID, gui, inMainMenu, imID, setting)
	local text = setting.ui_name

	local clicked, right_clicked = GuiButton(gui, imID, mod_setting_group_x_offset, 0, text)
	if clicked then
		mod_setting_handle_change_callback(modID, gui, inMainMenu, setting, true, true)
	end

	mod_setting_tooltip(modID, gui, inMainMenu, setting)
end

---Round changed value to the closest integer.
---@param modID string
---@param gui any
---@param inMainMenu boolean
---@param setting table
---@param oldValue number
---@param newValue number
local function roundChange(modID, gui, inMainMenu, setting, oldValue, newValue)
	ModSettingSetNextValue(mod_setting_get_id(modID, setting), math.floor(newValue + 0.5), false)
end

-- This is a magic global (eww) that can be used to migrate settings to new mod versions.
-- Call `mod_settings_get_version()` before `mod_settings_update()` to get the old value.
mod_settings_version = 1

local modID = "noita-mapcap"
local modSettings
modSettings = {
	{
		id = "capture-mode",
		ui_name = "Mode",
		ui_description = "How the mod captures:\n- Live: Capture as you play along.\n- Area: Capture a defined area of the world.\n- Spiral: Capture in a spiral around a starting point indefinitely.",
		value_default = "live",
		values = { { "live", "Live" }, { "area", "Area" }, { "spiral", "Spiral" } },
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "capture-mode-spiral-origin",
		ui_name = "  Origin",
		ui_description = "The starting point or center of the spiral.\n- Current position: Your in-game position.\n- World origin: Near the cave entrance.\n- Custom position: Enter your own coordinates.",
		value_default = "current",
		values = { { "current", "Current position" }, { "0", "World origin" }, { "custom", "Custom position" } },
		scope = MOD_SETTING_SCOPE_RUNTIME,
		show_fn = function() return modSettings:GetNextValue("capture-mode") == "spiral" end,
	},
	{
		id = "capture-mode-spiral-origin-vector",
		ui_name = "  Origin",
		ui_description = "",
		value_default = "0,0",
		allowed_characters = "-0123456789,",
		scope = MOD_SETTING_SCOPE_RUNTIME,
		show_fn = function() return not modSettings:Get("capture-mode-spiral-origin.hidden") and modSettings:GetNextValue("capture-mode-spiral-origin") == "custom" end,
	},
	{
		id = "area",
		ui_name = "  Rectangle",
		ui_description = "The area to be captured.\nSee documentation for more information.",
		value_default = "1x1",
		values = { { "1x1", "Base layout" }, { "1x3", "Main World" }, { "1.5x3", "Extended" }, { "custom", "Custom" } },
		scope = MOD_SETTING_SCOPE_RUNTIME,
		show_fn = function() return modSettings:GetNextValue("capture-mode") == "area" end,
	},
	{
		id = "area-top-left",
		ui_name = "    Top left corner",
		ui_description = "The top left corner of the to be captured rectangle.\n \nDefault: -512,-512", -- TODO: Fix "right click for default" for text inputs
		value_default = "-512,-512",
		allowed_characters = "-0123456789,",
		scope = MOD_SETTING_SCOPE_RUNTIME,
		show_fn = function() return not modSettings:Get("area.hidden") and modSettings:GetNextValue("area") == "custom" end,
	},
	{
		id = "area-bottom-right",
		ui_name = "    Bottom right corner",
		ui_description = "The bottom right corner of the to be captured rectangle.\n \nDefault: 512,512",
		value_default = "512,512",
		allowed_characters = "-0123456789,",
		scope = MOD_SETTING_SCOPE_RUNTIME,
		show_fn = function() return not modSettings:Get("area.hidden") and modSettings:GetNextValue("area") == "custom" end,
	},
	{
		ui_fn = mod_setting_vertical_spacing,
		not_setting = true,
	},
	{
		category_id = "advanced",
		ui_name = "ADVANCED",
		ui_description = "- A D V A N C E D -",
		foldable = true,
		_folded = true,
		settings = {
			{
				id = "seed",
				ui_name = "World seed",
				ui_description = "Lock the world to the given seed\n \nClear field to use a random seed.",
				value_default = DebugAPI.IsDevBuild() and "123" or "",
				allowed_characters = "0123456789",
				scope = MOD_SETTING_SCOPE_NEW_GAME,
			},
			{
				id = "grid-size",
				ui_name = "Grid size",
				ui_description = "How many world pixels the viewport will move between screenshots.\n \nDefault: 512",
				value_default = "512",
				allowed_characters = "0123456789",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function() return modSettings:GetNextValue("capture-mode") ~= "live" end,
			},
			{
				id = "pixel-scale",
				ui_name = "Pixel scale",
				ui_description = "How big a single resulting pixel will be.\nThis is the ratio of image to world pixels.\nA setting of 0 disables any scaling.\n \nDon't change while capturing,\nOr you will get unstitchable results.",
				value_default = 1,
				value_min = 0,
				value_max = 8,
				value_display_multiplier = 1,
				value_display_formatting = " $0 pixels/pixel",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = roundChange,
			},
			{
				id = "custom-resolution-live",
				ui_name = "Use custom resolution",
				ui_description = "If enabled, the mod will change the game resolutions to custom values.",
				value_default = false,
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function() return modSettings:GetNextValue("capture-mode") == "live" end,
			},
			{
				id = "custom-resolution-other",
				ui_name = "Use custom resolution",
				ui_description = "If enabled, the mod will change the game resolutions to custom values.",
				value_default = true,
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function() return modSettings:GetNextValue("capture-mode") ~= "live" end,
			},
			{
				id = "window-resolution",
				ui_name = "  Window resolution",
				ui_description = "Size of the window in screen pixels.\n \nDefault: 1024,1024",
				value_default = "1024,1024",
				allowed_characters = "0123456789,",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function()
					return (not modSettings:Get("advanced.settings.custom-resolution-live.hidden") and modSettings:GetNextValue("advanced.settings.custom-resolution-live"))
						or (not modSettings:Get("advanced.settings.custom-resolution-other.hidden") and modSettings:GetNextValue("advanced.settings.custom-resolution-other"))
				end,
			},
			{
				id = "internal-resolution",
				ui_name = "  Internal resolution",
				ui_description = "Size of the viewport in screen pixels.\nIdeally set to the window resolution.\n \nDefault: 1024,1024",
				value_default = "1024,1024",
				allowed_characters = "0123456789,",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function()
					return (not modSettings:Get("advanced.settings.custom-resolution-live.hidden") and modSettings:GetNextValue("advanced.settings.custom-resolution-live"))
						or (not modSettings:Get("advanced.settings.custom-resolution-other.hidden") and modSettings:GetNextValue("advanced.settings.custom-resolution-other"))
				end,
			},
			{
				id = "virtual-resolution",
				ui_name = "  Virtual resolution",
				ui_description = "Size of the viewport in world pixels.\nIdeally set to the window resolution.\n \nDefault: 1024,1024",
				value_default = "1024,1024",
				allowed_characters = "0123456789,",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function()
					return (not modSettings:Get("advanced.settings.custom-resolution-live.hidden") and modSettings:GetNextValue("advanced.settings.custom-resolution-live"))
						or (not modSettings:Get("advanced.settings.custom-resolution-other.hidden") and modSettings:GetNextValue("advanced.settings.custom-resolution-other"))
				end,
			},
			{
				ui_fn = mod_setting_vertical_spacing,
				not_setting = true,
				show_fn = function() return modSettings:GetNextValue("capture-mode") == "live" end,
			},
			{
				id = "live-interval",
				ui_name = "Capture interval",
				ui_description = "Capturing interval in frames.",
				value_default = 30,
				value_min = 5,
				value_max = 240,
				value_display_multiplier = 1,
				value_display_formatting = " $0 frames",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function() return modSettings:GetNextValue("capture-mode") == "live" end,
			},
			{
				id = "live-min-distance",
				ui_name = "Min. capture distance",
				ui_description = "The distance the viewport has to move to allow another screenshot.\nIn world pixels.",
				value_default = 10,
				value_min = 0,
				value_max = 200,
				value_display_multiplier = 1,
				value_display_formatting = " $0 pixels",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function() return modSettings:GetNextValue("capture-mode") == "live" end,
			},
			{
				id = "live-max-distance",
				ui_name = "Max. capture distance",
				ui_description = "The distance the viewport has to move to force another screenshot.\nIn world pixels.",
				value_default = 50,
				value_min = 0,
				value_max = 200,
				value_display_multiplier = 1,
				value_display_formatting = " $0 pixels",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				show_fn = function() return modSettings:GetNextValue("capture-mode") == "live" end,
			},
			{
				ui_fn = mod_setting_vertical_spacing,
				not_setting = true,
			},
			{
				id = "capture-entities",
				ui_name = "Capture entities",
				ui_description = "If enabled, the mod will create a JSON file with all encountered entities.\n \nThis may slow down things a bit.\nAnd it may make Noita more likely to crash.\nUse at your own risk.",
				value_default = false,
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				ui_fn = mod_setting_vertical_spacing,
				not_setting = true,
			},
			{
				id = "",
				ui_name = "Game modifications:",
				not_setting = true,
			},
			{
				id = "disable-background",
				ui_name = "  Disable parallax background",
				ui_description = "Turns the world background black.",
				value_default = DebugAPI.IsDevBuild(), -- Defaults to true in dev build, false in regular Noita.
				scope = MOD_SETTING_SCOPE_RUNTIME_RESTART,
			},
			{
				id = "disable-ui",
				ui_name = "  Disable UI",
				ui_description = "Hides and disables some of the UI.",
				value_default = false,
				scope = MOD_SETTING_SCOPE_RUNTIME_RESTART,
			},
			{
				id = "disable-physics",
				ui_name = "  Disable pixel and entity physics",
				ui_description = "Will freeze all pixel simulations and rigid body dynamics.",
				hidden = not DebugAPI.IsDevBuild(),
				value_default = DebugAPI.IsDevBuild(), -- Defaults to true in dev build, false in regular Noita.
				scope = MOD_SETTING_SCOPE_RUNTIME_RESTART,
			},
			{
				id = "disable-postfx",
				ui_name = "  Disable post FX",
				ui_description = "Will disable the following postprocessing:\n- Dithering\n- Refraction\n- Lighting\n- Fog of war\n- Glow\n- Gamma correction",
				value_default = DebugAPI.IsDevBuild(), -- Defaults to true in dev build, false in regular Noita.
				scope = MOD_SETTING_SCOPE_RUNTIME_RESTART,
			},
			{
				id = "disable-shaders-gui-ai",
				ui_name = "  Disable shaders, GUI and AI",
				ui_description = "It has the same effect as pressing F5, F8 and F12 in the Noita dev build.\nDoesn't work outside the dev build.",
				hidden = not DebugAPI:IsDevBuild(), -- Hide in anything else than the dev build.
				value_default = DebugAPI.IsDevBuild(), -- Defaults to true in dev build, false in regular Noita.
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				id = "modify-entities",
				ui_name = "  Disable entity logic",
				ui_description = "If enabled, the mod will disable some components of all encountered entities.\nThis will:\n- Disable AI\n- Disable falling\n- Disable hovering and rotation animations\n- Reduce explosions\n \nThis may slow down things a bit.\nAnd it may make Noita more likely to crash.\nUse at your own risk.",
				value_default = false,
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				id = "disable-mod-detection",
				ui_name = "  Disable mod detection",
				ui_description = "If enabled, Noita will behave as if no mods are enabled.\nTherefore secrets like the cauldron will be generated.",
				hidden = DebugAPI.IsDevBuild(),
				value_default = false,
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
		}
	},
}

---Hide/unhide some settings based on other settings.
function modSettings:AutoHide()
	for i, v in ipairs(self) do
		if v.show_fn then
			v.hidden = not v.show_fn()
		end
		if type(v.settings) == "table" then
			modSettings.AutoHide(v.settings)
		end
	end
end

---Returns the element at the given path of the settings hierarchy.
---@param path string -- Example: "category1.settings.foo.ui_name"
---@return any -- Result can be a settings table, a category table, or any value inside these tables.
function modSettings:Get(path)
	-- Return whatever we have found.
	if path == "" then
		return self
	end

	-- Split path into first element and rest.
	local first, rest = path, ""
	for v in path:gmatch("[^%.]+") do
		first, rest = v, path:sub(v:len() + 2, -1)
		break
	end

	-- Abort if element is not a table/array, as we expect a sub element.
	if type(self) ~= "table" then return nil end

	-- Search array of settings/categories.
	for _, v in ipairs(self) do
		if type(v) == "table" then
			if v.id == first then
				return modSettings.Get(v, rest) -- Found settings table.
			elseif v.category_id == first then
				return modSettings.Get(v, rest) -- Found category table.
			end
		end
	end

	-- Search in field of table.
	return modSettings.Get(self[first], rest)
end

---Returns combination of modID and settings ID of the given settings element at `path`.
---@param path string
---@return string|nil
function modSettings:GetID(path)
	local setting = modSettings:Get(path)
	if type(setting) == "table" and type(setting.id) == "string" then
		return string.format("%s.%s", modID, setting.id)
	end

	return nil
end

---Returns the latest value set by the user, which might not be equal to the value that is used in the game (depending on the 'scope' value selected for the setting).
---@param path string
---@return boolean|string|number|nil
function modSettings:GetNextValue(path)
	local id = modSettings:GetID(path)
	if not id then return nil end

	return ModSettingGetNextValue(id)
end

--------------------
-- Hook callbacks --
--------------------

---This function is called to ensure the correct setting values are visible to the game via `ModSettingGet()`.
---Your mod's settings don't work if you don't have a function like this defined in settings.lua.
---This function is called:
--- - when entering the mod settings menu (initScope will be `MOD_SETTINGS_SCOPE_ONLY_SET_DEFAULT`)
--- - before mod initialization when starting a new game (initScope will be `MOD_SETTING_SCOPE_NEW_GAME`)
--- - when entering the game after a restart (initScope will be `MOD_SETTING_SCOPE_RESTART`)
--- - at the end of an update when mod settings have been changed via `ModSettingsSetNextValue()` and the game is unpaused (initScope will be `MOD_SETTINGS_SCOPE_RUNTIME`)
---@param initScope number
function ModSettingsUpdate(initScope)
	local oldVersion = mod_settings_get_version(modID)
	mod_settings_update(modID, modSettings, initScope)
end

---This function should return the number of visible setting UI elements.
---Your mod's settings wont be visible in the mod settings menu if this function isn't defined correctly.
---If your mod changes the displayed settings dynamically, you might need to implement custom logic.
---The value will be used to determine whether or not to display various UI elements that link to mod settings.
---At the moment it is fine to simply return 0 or 1 in a custom implementation, but we don't guarantee that will be the case in the future.
---This function is called every frame when in the settings menu.
function ModSettingsGuiCount()
	return mod_settings_gui_count(modID, modSettings)
end

---This function is called to display the settings UI for this mod.
---Your mod's settings wont be visible in the mod settings menu if this function isn't defined correctly.
---@param gui any
---@param inMainMenu boolean
function ModSettingsGui(gui, inMainMenu)
	modSettings:AutoHide()
	mod_settings_gui(modID, modSettings, gui, inMainMenu)
end
