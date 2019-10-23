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
			GuiTextCentered(modGUI, 0, 0, "Use ESC and close the game to stop the process.")
			GuiTextCentered(
				modGUI,
				0,
				0,
				'You can resume capturing just by restarting noita and pressing "Start capturing map" again,'
			)
			GuiTextCentered(modGUI, 0, 0, "the mod will skip already captured files.")
			GuiTextCentered(
				modGUI,
				0,
				0,
				'If you want to start a new map, you have to delete all images from the "output" folder!'
			)
			GuiLayoutEnd(modGUI)
		end

		wait(0)
	end
)
