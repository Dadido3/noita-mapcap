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

require("mod_settings")

--------------------------
-- Load library modules --
--------------------------

-------------------------------
-- Load and run script files --
-------------------------------

----------
-- Code --
----------

local function customSettingButton(modID, gui, inMainMenu, imID, setting)
	local text = setting.ui_name

	local clicked, right_clicked = GuiButton(gui, imID, mod_setting_group_x_offset, 0, text)
	if clicked then
		mod_setting_handle_change_callback(modID, gui, inMainMenu, setting, true, true)
	end

	mod_setting_tooltip(modID, gui, inMainMenu, setting)
end

-- This is a magic global (eww) that can be used to migrate settings to new mod versions.
-- Call `mod_settings_get_version()` before `mod_settings_update()` to get the old value.
mod_settings_version = 1

local modID = "noita-mapcap"
local modSettings = {
	{
		id = "capture-mode",
		ui_name = "Mode",
		ui_description = "The capturing mode.\n- Live: Capture as you play along.\n- Area: Capture a defined area of the world\n- Spiral: Capture in a spiral around a starting point indefinitely.",
		value_default = "live",
		values = { { "live", "Live" }, { "area", "Area" }, { "spiral", "Spiral" } },
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "capture-mode-spiral-origin",
		ui_name = "Spiral origin",
		ui_description = "The starting point or center of the spiral.\n- Current position: Your ingame position.\n- World origin: Near the cave entrance.\n- Custom position: Enter your own coordinates.",
		value_default = "current",
		values = { { "current", "Current position" }, { "0", "World origin" }, { "custom", "Custom position" } },
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "capture-mode-spiral-origin-vector",
		ui_name = "Spiral origin",
		ui_description = "",
		value_default = "0, 0",
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "area",
		ui_name = "Area",
		ui_description = "The area to be captured.",
		value_default = "1x1",
		values = { { "1x1", "Base layout" }, { "1x3", "Main World" }, { "1.5x3", "Extended" }, { "custom", "Custom" } },
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "area-top-left",
		ui_name = "Area: Top Left corner",
		ui_description = "The top left corner of the to be captured rectangle.",
		value_default = "-512, -512",
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "area-bottom-right",
		ui_name = "Area: Bottom right corner",
		ui_description = "The bottom right corner of the to be captured rectangle.",
		value_default = "512, 512",
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "capture-entities",
		ui_name = "Capture entities",
		ui_description = "If enabled, the mod will create a JSON file with all encountered entities.\nThis may slow down things a bit.",
		value_default = false,
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		category_id = "advanced",
		ui_name = "ADVANCED",
		ui_description = "- A D V A N C E D -",
		foldable = true,
		settings = {
			{
				id = "grid-size",
				ui_name = "Grid size",
				ui_description = "How many pixels the viewport will move between screenshots.",
				value_default = "512",
				allowed_characters = "0123456789",
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				id = "pixel-size",
				ui_name = "Pixel size",
				ui_description = "How big a single resulting pixel will be.\nThis is the ratio of image to world pixels.\nA setting of 0 disables any scaling.",
				value_default = 1,
				value_min = 0,
				value_max = 8,
				value_display_multiplier = 1,
				value_display_formatting = " $0 pixels/pixel",
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				id = "custom-resolution-live",
				ui_name = "Use custom resolution",
				ui_description = "If enabled, the mod will change the game resolutions to custom values.",
				value_default = false,
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				id = "custom-resolution-other",
				ui_name = "Use custom resolution",
				ui_description = "If enabled, the mod will change the game resolutions to custom values.",
				value_default = true,
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				id = "window-resolution",
				ui_name = "Window resolution",
				ui_description = "Size of the window in screen pixels.",
				value_default = "1024, 1024",
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				id = "internal-resolution",
				ui_name = "Internal resolution",
				ui_description = "Size of the viewport in screen pixels.\nIdeally set to the window resolution.",
				value_default = "1024, 1024",
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
			{
				id = "virtual-resolution",
				ui_name = "Virtual resolution",
				ui_description = "Size of the viewport in world pixels.",
				value_default = "1024, 1024",
				scope = MOD_SETTING_SCOPE_RUNTIME,
			},
		}
	},
	{
		category_id = "actions",
		ui_name = "ACTIONS",
		foldable = true,
		settings = {
			{
				id = "button-open-output",
				ui_name = "Open output directory",
				ui_description = "Reveals the output directory in your file browser.",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				ui_fn = customSettingButton,
				change_fn = function() print("test") end,
			},
		}
	},
}

---Hide/unhide some settings based on other settings.
function modSettings:AutoHide()
	self:Get("capture-mode-spiral-origin").hidden = false
	self:Get("capture-mode-spiral-origin-vector").hidden = false
	self:Get("area").hidden = false
	self:Get("area-top-left").hidden = false
	self:Get("area-bottom-right").hidden = false
	self:Get("advanced.settings.grid-size").hidden = false

	local value = self:GetNextValue("capture-mode")
	if value == "live" then
		self:Get("capture-mode-spiral-origin").hidden = true
		self:Get("capture-mode-spiral-origin-vector").hidden = true
		self:Get("area").hidden = true
		self:Get("area-top-left").hidden = true
		self:Get("area-bottom-right").hidden = true
		self:Get("advanced.settings.grid-size").hidden = true
	elseif value == "area" then
		self:Get("capture-mode-spiral-origin").hidden = true
		self:Get("capture-mode-spiral-origin-vector").hidden = true
	elseif value == "spiral" then
		self:Get("area").hidden = true
		self:Get("area-top-left").hidden = true
		self:Get("area-bottom-right").hidden = true
	end

	local value = self:GetNextValue("capture-mode-spiral-origin")
	if value ~= "custom" then
		self:Get("capture-mode-spiral-origin-vector").hidden = true
	end

	local value = self:GetNextValue("area")
	if value ~= "custom" then
		self:Get("area-top-left").hidden = true
		self:Get("area-bottom-right").hidden = true
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
		first, rest = v, path:sub(first:len() + 1)
		break
	end

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

	-- Search in table.
	if type(self) == "table" and type(self[first]) == "table" then
		return modSettings.Get(self[first], rest)
	end

	return nil
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
