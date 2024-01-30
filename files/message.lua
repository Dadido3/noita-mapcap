-- Copyright (c) 2019-2024 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-----------------------
-- Load global stuff --
-----------------------

--------------------------
-- Load library modules --
--------------------------

local Coords = require("coordinates")
local DebugAPI = require("noita-api.debug")

----------
-- Code --
----------

---Removes all messages with the AutoClose flag.
---Use this before you recreate all auto closing messages.
function Message:CloseAutoClose()
	self.List = self.List or {}

	for k, message in pairs(self.List) do
		if message.AutoClose then
			self.List[k] = nil
		end
	end
end

---Add a general runtime error message to the message list.
---This will always overwrite the last runtime error with the same id.
---@param id string
---@param ... string
function Message:ShowRuntimeError(id, ...)
	self.List = self.List or {}

	self.List["RuntimeError" .. id] = {
		Type = "error",
		Lines = { ... },
	}
end

---Calls func and catches any exception.
---If there is one, a runtime error message will be shown to the user.
---@param id string
---@param func function
function Message:CatchException(id, func)
	local ok, err = xpcall(func, debug.traceback)
	if not ok then

		print(string.format("An exception happened in %s: %s", id, err))
		self:ShowRuntimeError(id, string.format("An exception happened in %s", id), err)
	end
end

---Request the user to let the addon automatically reset some Noita settings.
function Message:ShowResetNoitaSettings()
	self.List = self.List or {}

	self.List["ResetNoitaSettings"] = {
		Type = "info",
		Lines = {
			"You requested to reset some game settings like:",
			"- Custom resolutions",
			"- Screen-shake intensity",
			" ",
			"Press the following button to reset the settings and close Noita automatically:",
		},
		Actions = {
			{ Name = "Reset and close (May corrupt current save!)", Hint = nil, HintDesc = nil, Callback = function() Modification:Reset() end },
		},
	}
end

---Request the user to let the addon automatically set Noita settings based on the given callback.
---@param callback function
---@param desc string -- What's wrong.
function Message:ShowSetNoitaSettings(callback, desc)
	self.List = self.List or {}

	self.List["SetNoitaSettings"] = {
		Type = "warning",
		Lines = {
			"It seems that not all requested settings are applied to Noita:",
			desc or "",
			" ",
			"Press the button at the bottom to set up and close Noita automatically.",
			" ",
			"You can always reset any custom settings by right clicking the `start capture`",
			"button at the top left.",
		},
		Actions = {
			{ Name = "Setup and close (May corrupt current save!)", Hint = nil, HintDesc = nil, Callback = callback },
		},
		AutoClose = true, -- This message will automatically close.
	}
end

---Request the user to restart Noita.
---@param desc string -- What's wrong.
function Message:ShowRequestRestart(desc)
	self.List = self.List or {}

	self.List["RequestRestart"] = {
		Type = "warning",
		Lines = {
			"It seems that not all requested settings are applied to Noita:",
			desc or "",
			" ",
			"To resolve this issue, restart the game.",
		},
		AutoClose = true, -- This message will automatically close.
	}
end

---Request the user to let the addon automatically set Noita settings based on the given callback.
---@param callback function
---@param desc string -- What's wrong.
function Message:ShowWrongResolution(callback, desc)
	self.List = self.List or {}

	self.List["WrongResolution"] = {
		Type = "warning",
		Lines = {
			"The resolution changed:",
			desc or "",
			" ",
			"Press the button at the bottom to set up and close Noita automatically.",
			" ",
			"You can always reset any custom settings by right clicking the `start capture`",
			"button at the top left.",
		},
		Actions = {
			{ Name = "Setup and close (May corrupt current save!)", Hint = nil, HintDesc = nil, Callback = callback },
		},
		AutoClose = true, -- This message will automatically close.
	}
end

---Tell the user that there are files in the output directory.
function Message:ShowOutputNonEmpty()
	self.List = self.List or {}

	self.List["OutputNonEmpty"] = {
		Type = "hint",
		Lines = {
			"There are already files in the output directory.",
			"If you are continuing a capture session, ignore this message.",
			" ",
			"If you are about to capture a new map, make sure to delete all files in the output directory first."
		},
		Actions = {
			{ Name = "Open output directory", Hint = nil, HintDesc = nil, Callback = function() os.execute("start .\\mods\\noita-mapcap\\output\\") end },
		},
	}
end

---Tell the user that some settings are not optimal.
---@param ... string
function Message:ShowGeneralSettingsProblem(...)
	self.List = self.List or {}

	self.List["GeneralSettingsProblem"] = {
		Type = "hint",
		Lines = { ... },
		AutoClose = true, -- This message will automatically close.
	}
end

---Tell the user that there is something wrong with the mod installation.
---@param ... string
function Message:ShowGeneralInstallationProblem(...)
	self.List = self.List or {}

	self.List["GeneralInstallationProblem"] = {
		Type = "error",
		Lines = { ... },
	}
end

---Tell the user that some modification couldn't be applied because it is unsupported.
---@param realm "config"|"magicNumbers"|"processMemory"|"filePatches"
---@param name string
---@param value any
function Message:ShowModificationUnsupported(realm, name, value)
	self.List = self.List or {}

	self.List["ModificationFailed"] = self.List["ModificationFailed"] or {
		Type = "warning",
	}

	self.List["ModificationFailed"].ModificationEntries = self.List["ModificationFailed"].ModificationEntries or {}
	table.insert(self.List["ModificationFailed"].ModificationEntries, {realm = realm, name = name, value = value})

	-- Build message lines.
	self.List["ModificationFailed"].Lines = {"The mod couldn't apply the following changes:"}
	table.insert(self.List["ModificationFailed"].Lines, " ")
	for _, modEntry in ipairs(self.List["ModificationFailed"].ModificationEntries) do
		table.insert(self.List["ModificationFailed"].Lines, string.format("- %q in %q realm", modEntry.name, modEntry.realm))
	end

	table.insert(self.List["ModificationFailed"].Lines, " ")
	table.insert(self.List["ModificationFailed"].Lines, "This simply means that the mod can't automatically apply this change in the Noita version you are using.")
	table.insert(self.List["ModificationFailed"].Lines, "If you are running a non-beta version of Noita, feel free to open an issue at https://github.com/Dadido3/noita-mapcap.")

	-- Tell the user to change some settings manually, if possible.
	local manuallyWithF7 = {}
	local possibleManualWithF7 = {mPostFxDisabled = true, mGuiDisabled = true, mGuiHalfSize = true, mFogOfWarOpenEverywhere = true, mTrailerMode = true, mDayTimeRotationPause = true, mPlayerNeverDies = true, mFreezeAI = true}
	for _, modEntry in ipairs(self.List["ModificationFailed"].ModificationEntries) do
		if modEntry.realm == "processMemory" and possibleManualWithF7[modEntry.name] then
			table.insert(manuallyWithF7, modEntry)
		end
	end

	if #manuallyWithF7 > 0 then
		table.insert(self.List["ModificationFailed"].Lines, " ")
		table.insert(self.List["ModificationFailed"].Lines, "You can apply the setting manually:")
		table.insert(self.List["ModificationFailed"].Lines, " ")
		table.insert(self.List["ModificationFailed"].Lines, "- Press F7 to open the debug menu.")
		for _, modEntry in ipairs(manuallyWithF7) do
			table.insert(self.List["ModificationFailed"].Lines, string.format("- Change %q to %q.", modEntry.name, modEntry.value))
		end
		table.insert(self.List["ModificationFailed"].Lines, "- Press F7 again to close the menu.")
		table.insert(self.List["ModificationFailed"].Lines, "- Close this warning when you are done.")
	end
end
