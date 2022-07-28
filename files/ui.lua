-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-----------------------
-- Load global stuff --
-----------------------

-- TODO: Wrap Noita utilities and wrap them into a table: https://stackoverflow.com/questions/9540732/loadfile-without-polluting-global-environment
require("utilities") -- Loads Noita's utilities from `data/scripts/lib/utilitites.lua`.

--------------------------
-- Load library modules --
--------------------------

----------
-- Code --
----------

---Returns unique IDs for the widgets.
---`_ResetID` has to be called every time before the UI is rebuilt.
---@return integer
function UI:_GenID()
	self.CurrentID = (self.CurrentID or 0) + 1
	return self.CurrentID
end

function UI:_ResetID()
	self.CurrentID = nil
end

---Stops the UI from drawing for the next few frames.
---@param frames integer
function UI:SuspendDrawing(frames)
	self.suspendFrames = math.max(self.suspendFrames or 0, frames)
end

function UI:_DrawToolbar()
	local gui = self.gui
	GuiZSet(gui, 0)

	GuiLayoutBeginHorizontal(gui, 2, 2, true, 2, 2)

	if Capture.MapCapturingCtx:IsRunning() then
		local clicked, clickedRight = GuiImageButton(gui, self:_GenID(), 0, 0, "", "mods/noita-mapcap/files/ui-gfx/stop-16x16.png")
		GuiTooltip(gui, "Stop capture", "Stop the capturing process.\n \nRight click: Reset any modifications that this mod has done to Noita.")
		if clicked then Capture:StopCapturing() end
		if clickedRight then Message:ShowResetNoitaSettings() end
	else
		local clicked, clickedRight = GuiImageButton(gui, self:_GenID(), 0, 0, "", "mods/noita-mapcap/files/ui-gfx/record-16x16.png")
		GuiTooltip(gui, "Start capture", "Start the capturing process based on mod settings.\n \nRight click: Reset any modifications that this mod has done to Noita.")
		if clicked then Capture:StartCapturing() end
		if clickedRight then Message:ShowResetNoitaSettings() end
	end

	local clicked = GuiImageButton(gui, self:_GenID(), 0, 0, "", "mods/noita-mapcap/files/ui-gfx/open-output-16x16.png")
	GuiTooltip(gui, "Open output directory", "Reveals the output directory in your file browser.")
	if clicked then os.execute("start .\\mods\\noita-mapcap\\output\\") end

	GuiLayoutEnd(gui)
end

function UI:_DrawMessages(messages)
	local gui = self.gui

	-- Abort if there is no messages list.
	if not messages then return end
	
	GuiZSet(gui, 0)

	-- Unfortunately you can't stack multiple layout containers with the same direction.
	-- So keep track of the y position manually.
	local posY = 60
	for key, message in pairs(messages) do
		GuiZSet(gui, -10)
		GuiBeginAutoBox(gui)

		GuiLayoutBeginHorizontal(gui, 27, posY, true, 5, 0) posY = posY + 20

		if message.Type == "warning" or message.Type == "error" then
			GuiImage(gui, self:_GenID(), 0, 0, "mods/noita-mapcap/files/ui-gfx/warning-16x16.png", 1, 1, 0, 0, 0, "")
		elseif message.Type == "hint" or message.Type == "info" then
			GuiImage(gui, self:_GenID(), 0, 0, "mods/noita-mapcap/files/ui-gfx/hint-16x16.png", 1, 1, 0, 0, 0, "")
		else
			GuiImage(gui, self:_GenID(), 0, 0, "mods/noita-mapcap/files/ui-gfx/hint-16x16.png", 1, 1, 0, 0, 0, "")
		end
		
		GuiLayoutBeginVertical(gui, 0, 0, false, 0, 0)
		if type(message.Lines) == "table" then
			for _, line in ipairs(message.Lines) do
				GuiText(gui, 0, 0, tostring(line)) posY = posY + 11
			end
		end
		if type(message.Actions) == "table" then
			posY = posY + 11
			for _, action in ipairs(message.Actions) do
				local clicked = GuiButton(gui, self:_GenID(), 0, 11, ">" .. action.Name .. " <") posY = posY + 11
				if action.Hint or action.HintDesc then
					GuiTooltip(gui, action.Hint or "", action.HintDesc or "")
				end
				if clicked then
					local ok, err = pcall(action.Callback)
					if not ok then
						Message:ShowRuntimeError("MessageAction", "Message action error:", err)
					end
					messages[key] = nil
				end
			end
		end
		GuiLayoutEnd(gui)

		local clicked = GuiImageButton(gui, self:_GenID(), 5, 0, "", "mods/noita-mapcap/files/ui-gfx/dismiss-8x8.png")
		--GuiTooltip(gui, "Dismiss message", "")
		if clicked then messages[key] = nil end

		GuiLayoutEnd(gui)

		GuiZSet(gui, -9)
		GuiEndAutoBoxNinePiece(gui, 5, 0, 0, false, 0, "data/ui_gfx/decorations/9piece0_gray.png", "data/ui_gfx/decorations/9piece0_gray.png")
	end
end

function UI:Draw()
	self.gui = self.gui or GuiCreate()
	local gui = self.gui

	-- Skip drawing if we are asked to do so.
	if self.suspendFrames and self.suspendFrames > 0 then self.suspendFrames = self.suspendFrames - 1 return end
	self.suspendFrames = nil

	-- Reset ID generator.
	self:_ResetID()

	GuiStartFrame(gui)

	GuiIdPushString(gui, "noita-mapcap")

	self:_DrawToolbar()
	self:_DrawMessages(Message.List)

	GuiIdPop(gui)
end
