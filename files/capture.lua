-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

CAPTURE_PIXEL_SIZE = 1 -- Screen to virtual pixel ratio
CAPTURE_GRID_SIZE = 420 -- in ingame pixels. There will always be 3 to 6 images overlapping
CAPTURE_DELAY = 15 -- in frames
CAPTURE_BIGJUMP_DELAY = 20 -- in frames. Additional delay after doing a "larger than grid jump"
CAPTURE_FORCE_HP = 4 -- * 25HP

CAPTURE_LEFT = -25000 -- in ingame pixels. Left edge of the full map capture rectangle
CAPTURE_TOP = -36000 -- in ingame pixels. Top edge of the full map capture rectangle
CAPTURE_RIGHT = 25000 -- in ingame pixels. Right edge of the full map capture rectangle (Pixels are not included in the rectangle)
CAPTURE_BOTTOM = 36000 -- in ingame pixels. Bottom edge of the full map capture rectangle (Pixels are not included in the rectangle)

local function preparePlayer()
	local playerEntity = getPlayer()
	addEffectToEntity(playerEntity, "PROTECTION_ALL")

	addPerkToPlayer("BREATH_UNDERWATER")
	addPerkToPlayer("INVISIBILITY")
	addPerkToPlayer("REMOVE_FOG_OF_WAR")
	addPerkToPlayer("REPELLING_CAPE")
	addPerkToPlayer("WORM_DETRACTOR")

	setPlayerHP(CAPTURE_FORCE_HP)
end

local function resetPlayer()
	setPlayerHP(CAPTURE_FORCE_HP)
end

local xOld, yOld = 0, 0
local function captureScreenshot(x, y, rx, ry)
	-- "Larger than grid jump" delay
	local delay = CAPTURE_DELAY - 1
	if math.abs(x - xOld) > CAPTURE_GRID_SIZE or math.abs(y - yOld) > CAPTURE_GRID_SIZE then
		delay = delay + CAPTURE_BIGJUMP_DELAY
	end
	xOld, yOld = x, y

	-- Set pos several times, so that chunks will load even if nothing happens in the surrounding
	-- This prevents black blocks in areas without entites
	for i = 1, delay, 1 do
		GameSetCameraPos(x, y)
		wait(1)
	end
	GameSetCameraPos(x, y)

	UiHide = true -- Hide UI while capturing the screenshot
	wait(1)
	if not TriggerCapture(rx, ry) then
		UiCaptureProblem = "Screen capture failed. Please restart Noita."
	end
	UiHide = false

	-- Reset monitor and PC standby each screenshot
	ResetStandbyTimer()
end

function startCapturingSpiral()
	local ox, oy = GameGetCameraPos()
	ox, oy = math.floor(ox / CAPTURE_GRID_SIZE) * CAPTURE_GRID_SIZE, math.floor(oy / CAPTURE_GRID_SIZE) * CAPTURE_GRID_SIZE
	local x, y = ox, oy

	local virtualWidth, virtualHeight =
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")),
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y"))

	local virtualHalfWidth, virtualHalfHeight = math.floor(virtualWidth / 2), math.floor(virtualHeight / 2)

	preparePlayer()

	GameSetCameraFree(true)

	-- Coroutine to calculate next coordinate, and trigger screenshots
	local i = 1
	async_loop(
		function()
			-- +x
			for i = 1, i, 1 do
				local rx, ry = x * CAPTURE_PIXEL_SIZE - virtualHalfWidth, y * CAPTURE_PIXEL_SIZE - virtualHalfHeight
				if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
					captureScreenshot(x, y, rx, ry)
				end
				x, y = x + CAPTURE_GRID_SIZE, y
			end
			-- +y
			for i = 1, i, 1 do
				local rx, ry = x * CAPTURE_PIXEL_SIZE - virtualHalfWidth, y * CAPTURE_PIXEL_SIZE - virtualHalfHeight
				if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
					captureScreenshot(x, y, rx, ry)
				end
				x, y = x, y + CAPTURE_GRID_SIZE
			end
			i = i + 1
			-- -x
			for i = 1, i, 1 do
				local rx, ry = x * CAPTURE_PIXEL_SIZE - virtualHalfWidth, y * CAPTURE_PIXEL_SIZE - virtualHalfHeight
				if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
					captureScreenshot(x, y, rx, ry)
				end
				x, y = x - CAPTURE_GRID_SIZE, y
			end
			-- -y
			for i = 1, i, 1 do
				local rx, ry = x * CAPTURE_PIXEL_SIZE - virtualHalfWidth, y * CAPTURE_PIXEL_SIZE - virtualHalfHeight
				if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
					captureScreenshot(x, y, rx, ry)
				end
				x, y = x, y - CAPTURE_GRID_SIZE
			end
			i = i + 1
		end
	)
end

function startCapturingHilbert()
	local ox, oy = GameGetCameraPos()

	local virtualWidth, virtualHeight =
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")),
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y"))

	local virtualHalfWidth, virtualHalfHeight = math.floor(virtualWidth / 2), math.floor(virtualHeight / 2)

	-- Get size of the rectangle in grid/chunk coordinates
	local gridLeft = math.floor(CAPTURE_LEFT / CAPTURE_GRID_SIZE)
	local gridTop = math.floor(CAPTURE_TOP / CAPTURE_GRID_SIZE)
	local gridRight = math.ceil(CAPTURE_RIGHT / CAPTURE_GRID_SIZE) + 1
	local gridBottom = math.ceil(CAPTURE_BOTTOM / CAPTURE_GRID_SIZE) + 1

	-- Size of the grid in chunks
	local gridWidth = gridRight - gridLeft
	local gridHeight = gridBottom - gridTop

	-- Hilbert curve can only fit into a square, so get the longest side
	local gridPOTSize = math.ceil(math.log(math.max(gridWidth, gridHeight)) / math.log(2))
	-- Max size (Already rounded up to the next power of two)
	local gridMaxSize = math.pow(2, gridPOTSize)

	local t, tLimit = 0, gridMaxSize * gridMaxSize

	UiProgress = {Progress = 0, Max = gridWidth * gridHeight}

	preparePlayer()

	GameSetCameraFree(true)

	-- Coroutine to calculate next coordinate, and trigger screenshots
	async(
		function()
			while t < tLimit do
				local hx, hy = mapHilbert(t, gridPOTSize)
				if hx < gridWidth and hy < gridHeight then
					local x, y = (hx + gridLeft) * CAPTURE_GRID_SIZE, (hy + gridTop) * CAPTURE_GRID_SIZE
					local rx, ry = x * CAPTURE_PIXEL_SIZE - virtualHalfWidth, y * CAPTURE_PIXEL_SIZE - virtualHalfHeight
					if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
						captureScreenshot(x, y, rx, ry)
					end
					UiProgress.Progress = UiProgress.Progress + 1
				end

				t = t + 1
			end
		end
	)
end
