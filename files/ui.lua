-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

async_loop(
	function()
		if modGUI ~= nil then
			GuiStartFrame(modGUI)

			GuiLayoutBeginVertical(modGUI, 50, 20)
			if GuiButton(modGUI, 0, 0, "Start capturing map", 1) then
				startCapturing()
				GuiDestroy(modGUI)
				modGUI = nil
			end
			GuiTextCentered(modGUI, 0, 0, "Don't do anything while the capturing process is running!")
			GuiTextCentered(modGUI, 0, 0, "Use ESC and close the game to stop the process.")
			--[[if GuiButton(gui, 0, 0, "DEBUG globals", 1) then
				local file = io.open("mods/noita-mapcap/output/globals.txt", "w")
				for i, v in pairs(_G) do
					file:write(i .. "\n")
				end
				file:close()
			end]]
			GuiLayoutEnd(modGUI)
		end

		wait(0)
	end
)
