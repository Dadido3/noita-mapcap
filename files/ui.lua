-- Copyright (c) 2019-2020 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

UiHide = false
local UiReduce = false
UiProgress = nil
UiCaptureProblem = nil

async_loop(
	function()
		if modGUI ~= nil then
			GuiStartFrame(modGUI)

			GuiLayoutBeginVertical(modGUI, 50, 50)
			if not UiReduce then
				local problem
				local rect = GetRect()

				if not rect then
					GuiTextCentered(modGUI, 0, 0, '!!! WARNING !!! You are not using "Windowed" mode.')
					GuiTextCentered(modGUI, 0, 0, "To fix the problem, do one of these:")
					GuiTextCentered(modGUI, 0, 0, '- Change the window mode in the game options to "Windowed"')
					GuiTextCentered(modGUI, 0, 0, " ")
					problem = true
				end

				if rect then
					local screenWidth, screenHeight = rect.right - rect.left, rect.bottom - rect.top
					local virtualWidth, virtualHeight =
						tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")),
						tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y"))
					local ratioX, ratioY = screenWidth / virtualWidth, screenHeight / virtualHeight
					--GuiTextCentered(modGUI, 0, 0, string.format("SCREEN_RESOLUTION_*: %d, %d", screenWidth, screenHeight))
					--GuiTextCentered(modGUI, 0, 0, string.format("VIRTUAL_RESOLUTION_*: %d, %d", virtualWidth, virtualHeight))
					if math.abs(ratioX - CAPTURE_PIXEL_SIZE) > 0.0001 or math.abs(ratioY - CAPTURE_PIXEL_SIZE) > 0.0001 then
						GuiTextCentered(modGUI, 0, 0, "!!! WARNING !!! Screen and virtual resolution differ.")
						GuiTextCentered(modGUI, 0, 0, "To fix the problem, do one of these:")
						GuiTextCentered(
							modGUI,
							0,
							0,
							string.format(
								"- Change the resolution in the game options to %dx%d",
								virtualWidth * CAPTURE_PIXEL_SIZE,
								virtualHeight * CAPTURE_PIXEL_SIZE
							)
						)
						GuiTextCentered(
							modGUI,
							0,
							0,
							string.format(
								"- Change the virtual resolution in the mod to %dx%d",
								screenWidth / CAPTURE_PIXEL_SIZE,
								screenHeight / CAPTURE_PIXEL_SIZE
							)
						)
						if math.abs(ratioX - ratioY) < 0.0001 then
							GuiTextCentered(modGUI, 0, 0, string.format("- Change the CAPTURE_PIXEL_SIZE in the mod to %f", ratioX))
						end
						GuiTextCentered(modGUI, 0, 0, " ")
						problem = true
					end
				end

				if not fileExists("mods/noita-mapcap/bin/capture-b/capture.dll") then
					GuiTextCentered(modGUI, 0, 0, "!!! WARNING !!! Can't find library for screenshots.")
					GuiTextCentered(modGUI, 0, 0, "To fix the problem, do one of these:")
					GuiTextCentered(modGUI, 0, 0, "- Redownload a release of this mod from GitHub, don't download the sourcecode")
					GuiTextCentered(modGUI, 0, 0, " ")
					problem = true
				end

				if not fileExists("mods/noita-mapcap/bin/stitch/stitch.exe") then
					GuiTextCentered(modGUI, 0, 0, "!!! WARNING !!! Can't find software for stitching.")
					GuiTextCentered(modGUI, 0, 0, "You can still take screenshots, but you won't be able to stitch those screenshots.")
					GuiTextCentered(modGUI, 0, 0, "To fix the problem, do one of these:")
					GuiTextCentered(modGUI, 0, 0, "- Redownload a release of this mod from GitHub, don't download the sourcecode")
					GuiTextCentered(modGUI, 0, 0, " ")
					problem = true
				end

				if not problem then
					GuiTextCentered(modGUI, 0, 0, "No problems found.")
					GuiTextCentered(modGUI, 0, 0, " ")
				end

				GuiTextCentered(modGUI, 0, 0, "You can freely look around and search a place to start capturing.")
				GuiTextCentered(modGUI, 0, 0, "When started the mod will take pictures automatically.")
				GuiTextCentered(modGUI, 0, 0, "Use ESC  to pause, and close the game to stop the process.")
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
				GuiTextCentered(modGUI, 0, 0, " ")
				if GuiButton(modGUI, 0, 0, ">> Start capturing map around view <<", 1) then
					startCapturingSpiral()
					UiReduce = true
				end
				if GuiButton(modGUI, 0, 0, ">> Start capturing full map <<", 1) then
					startCapturingHilbert()
					UiReduce = true
				end
				GuiTextCentered(modGUI, 0, 0, " ")
			end
			if not UiHide then
				local x, y = GameGetCameraPos()
				GuiTextCentered(modGUI, 0, 0, string.format("Coordinates: %d, %d", x, y))
				if UiProgress then
					GuiTextCentered(
						modGUI,
						0,
						0,
						progressBarString(
							UiProgress,
							{BarLength = 100, CharFull = "l", CharEmpty = ".", Format = "|%s| [%d / %d] [%1.2f%%]"}
						)
					)
				end
				if UiCaptureProblem then
					GuiTextCentered(modGUI, 0, 0, string.format("A problem occurred while capturing: %s", UiCaptureProblem))
				end
			end
			GuiLayoutEnd(modGUI)
		end

		wait(0)
	end
)
