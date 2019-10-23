-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local CAPTURE_PIXEL_SIZE = 2 -- in FullHD a ingame pixel is expected to be 2 real pixels
local CAPTURE_GRID_SIZE = 1080 / 4 -- in ingame pixels
local CAPTURE_DELAY = 15 -- in frames
local CAPTURE_FORCE_HP = 4 -- * 25HP

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

function startCapturing()
	local ox, oy = getPlayerPos()
	ox, oy = math.floor(ox / CAPTURE_GRID_SIZE) * CAPTURE_GRID_SIZE, math.floor(oy / CAPTURE_GRID_SIZE) * CAPTURE_GRID_SIZE
	local x, y = ox, oy

	preparePlayer()

	GameSetCameraFree(true)

	-- Coroutine to calculate next coordinate, and trigger screenshots
	local i = 1
	async_loop(
		function()
			-- +x
			for i = 1, i, 1 do
				TriggerCapture(x * CAPTURE_PIXEL_SIZE, y * CAPTURE_PIXEL_SIZE)
				x, y = x + CAPTURE_GRID_SIZE, y
				GameSetCameraPos(x, y)
				wait(CAPTURE_DELAY)
			end
			-- +y
			for i = 1, i, 1 do
				TriggerCapture(x * CAPTURE_PIXEL_SIZE, y * CAPTURE_PIXEL_SIZE)
				x, y = x, y + CAPTURE_GRID_SIZE
				GameSetCameraPos(x, y)
				wait(CAPTURE_DELAY)
			end
			i = i + 1
			-- -x
			for i = 1, i, 1 do
				TriggerCapture(x * CAPTURE_PIXEL_SIZE, y * CAPTURE_PIXEL_SIZE)
				x, y = x - CAPTURE_GRID_SIZE, y
				GameSetCameraPos(x, y)
				wait(CAPTURE_DELAY)
			end
			-- -y
			for i = 1, i, 1 do
				TriggerCapture(x * CAPTURE_PIXEL_SIZE, y * CAPTURE_PIXEL_SIZE)
				x, y = x, y - CAPTURE_GRID_SIZE
				GameSetCameraPos(x, y)
				wait(CAPTURE_DELAY)
			end
			i = i + 1
		end
	)
end
