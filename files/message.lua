-- Copyright (c) 2019-2022 David Vogel
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

----------
-- Code --
----------

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
			"- Screenshake intensity",
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
			"To fix: Restart Noita or revert the change."
		},
		Actions = {
			{ Name = "Query settings again", Hint = nil, HintDesc = nil, Callback = function() Coords:ReadResolutions() end },
		},
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

---Tell the user that there is something wrong with the mod installation.
---@param ... string
function Message:ShowGeneralInstallationProblem(...)
	self.List = self.List or {}

	self.List["GeneralInstallationProblem"] = {
		Type = "error",
		Lines = { ... },
	}
end
