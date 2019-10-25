-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

UiHide = false
local UiReduce = false

async_loop(
	function()
		if modGUI ~= nil then
			GuiStartFrame(modGUI)

			GuiLayoutBeginVertical(modGUI, 50, 50)
			if not UiReduce then
				GuiTextCentered(modGUI, 0, 0, "You can freely look around and search a place to start capturing.")
				GuiTextCentered(modGUI, 0, 0, "The mod will then take images in a spiral around your current view.")
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
				if GuiButton(modGUI, 0, 0, ">> Start capturing map <<", 1) then
					startCapturing()
					UiReduce = true
				end
			end
			if not UiHide then
				local x, y = GameGetCameraPos()
				GuiTextCentered(modGUI, 0, 0, string.format("Coordinates: %d, %d", x, y))
			end
			GuiLayoutEnd(modGUI)
		end

		wait(0)
	end
)
