-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

---@type NoitaAPI
local noitaAPI = dofile_once("mods/noita-mapcap/files/libraries/noita-api.lua")

---@type JSONLib
local json = dofile_once("mods/noita-mapcap/files/libraries/json.lua")

CAPTURE_PIXEL_SIZE = 1 -- Screen to virtual pixel ratio.
CAPTURE_GRID_SIZE = 512 -- in virtual (world) pixels. There will always be exactly 4 images overlapping if the virtual resolution is 1024x1024.

-- "Base layout" (Base layout. Every part outside this is based on a similar layout, but uses different materials/seeds)
CAPTURE_AREA_BASE_LAYOUT = {
	Left = -17920, -- in virtual (world) pixels.
	Top = -7168, -- in virtual (world) pixels.
	Right = 17920, -- in virtual (world) pixels. (Coordinate is not included in the rectangle)
	Bottom = 17408 -- in virtual (world) pixels. (Coordinate is not included in the rectangle)
}

-- "Main world" (The main world with 3 parts: sky, normal and hell)
CAPTURE_AREA_MAIN_WORLD = {
	Left = -17920, -- in virtual (world) pixels.
	Top = -31744, -- in virtual (world) pixels.
	Right = 17920, -- in virtual (world) pixels. (Coordinate is not included in the rectangle)
	Bottom = 41984 -- in virtual (world) pixels. (Coordinate is not included in the rectangle)
}

-- "Extended" (Main world + a fraction of the parallel worlds to the left and right)
CAPTURE_AREA_EXTENDED = {
	Left = -25600, -- in virtual (world) pixels.
	Top = -31744, -- in virtual (world) pixels.
	Right = 25600, -- in virtual (world) pixels. (Coordinate is not included in the rectangle)
	Bottom = 41984 -- in virtual (world) pixels. (Coordinate is not included in the rectangle)
}

local componentTypeNamesToDisable = {
	"AnimalAIComponent",
	"SimplePhysicsComponent",
	"CharacterPlatformingComponent",
	"WormComponent",
	"WormAIComponent",
	"CameraBoundComponent", -- Disabling this component will prevent entites from being killed/reset when they go offscreen. If they are reset, the "MapCaptured" tag will be gone and we capture these entities multiple times. This has some side effects, like longleg.xml and zombie_weak.xml will respawn every revisit, as the spawner doesn't get deleted.
	--"PhysicsBodyCollisionDamageComponent",
	--"ExplodeOnDamageComponent",
	--"DamageModelComponent",
	--"SpriteOffsetAnimatorComponent",
	--"MaterialInventoryComponent",
	--"LuaComponent",
	--"PhysicsBody2Component", -- Disabling will hide barrels and similar stuff, also triggers an assertion.
	--"PhysicsBodyComponent",
	--"VelocityComponent", -- Disabling this component may cause a "...\component_updators\advancedfishai_system.cpp at line 107" exception.
	--"SpriteComponent",
	--"AudioComponent",
}

---
---@return file*|nil
local function createOrOpenEntityCaptureFile()
	-- Make sure the file exists.
	local file = io.open("mods/noita-mapcap/output/entities.json", "a")
	if file ~= nil then file:close() end

	-- Create or reopen entities CSV file.
	file = io.open("mods/noita-mapcap/output/entities.json", "r+b") -- Open for reading (r) and writing (+) in binary mode. r+b will not truncate the file to 0.
	if file == nil then return nil end

	return file
end

---captureEntities gathers all entities on the screen (around x, y within radius), serializes them, appends them into entityFile and modifies those entities.
---@param entityFile file*|nil
---@param x number
---@param y number
---@param radius number
local function captureEntities(entityFile, x, y, radius)
	if not entityFile then return end

	local entities = noitaAPI.Entity.GetInRadius(x, y, radius)
	for _, entity in ipairs(entities) do
		-- Get to the root entity, as we are exporting entire entity trees.
		local rootEntity = entity:GetRootEntity()
		-- Make sure to only export entities when they are encountered the first time.
		if not rootEntity:HasTag("MapCaptured") then
			--print(rootEntity:GetFilename(), "got captured!")

			-- Some hacky way to generate valid JSON that doesn't break when the game crashes.
			-- Well, as long as it does not crash between write and flush.
			if entityFile:seek("end") == 0 then
				-- First line.
				entityFile:write("[\n\t", json.Marshal(rootEntity), "\n", "]")
			else
				-- Following lines.
				entityFile:seek("end", -2) -- Seek a few bytes back, so we can overwrite some stuff.
				entityFile:write(",\n\t", json.Marshal(rootEntity), "\n", "]")
			end

			-- Prevent recapturing.
			rootEntity:AddTag("MapCaptured")

			-- Disable some components.
			for _, componentTypeName in ipairs(componentTypeNamesToDisable) do
				local components = rootEntity:GetComponents(componentTypeName)
				for _, component in ipairs(components) do
					rootEntity:SetComponentsEnabled(component, false)
				end
			end

			-- Modify the gravity of every VelocityComponent, so stuff will not fall.
			local component = rootEntity:GetFirstComponent("VelocityComponent")
			if component then
				component:SetValue("gravity_x", 0)
				component:SetValue("gravity_y", 0)
				component:SetValue("mVelocity", 0, 0)
			end

			-- Modify the gravity of every CharacterPlatformingComponent, so mobs will not fall.
			local component = rootEntity:GetFirstComponent("CharacterPlatformingComponent")
			if component then
				component:SetValue("pixel_gravity", 0)
			end

			-- Disable the hover and spinning animations of every ItemComponent.
			local component = rootEntity:GetFirstComponent("ItemComponent")
			if component then
				component:SetValue("play_hover_animation", false)
				component:SetValue("play_spinning_animation", false)
			end

			-- Disable the hover animation of cards. Disabling the "SpriteOffsetAnimatorComponent" does not help.
			--[[local components = rootEntity:GetComponents("SpriteOffsetAnimatorComponent")
			for _, component in ipairs(components) do
				component:SetValue("x_speed", 0)
				component:SetValue("y_speed", 0)
				component:SetValue("x_amount", 0)
				component:SetValue("y_amount", 0)
			end]]

			-- Try to prevent some stuff from exploding.
			local component = rootEntity:GetFirstComponent("PhysicsBody2Component")
			if component then
				component:SetValue("kill_entity_if_body_destroyed", false)
				component:SetValue("destroy_body_if_entity_destroyed", false)
				component:SetValue("auto_clean", false)
			end

			-- Try to prevent some stuff from exploding.
			local component = rootEntity:GetFirstComponent("DamageModelComponent")
			if component then
				component:SetValue("falling_damages", false)
			end

			-- Try to prevent some stuff from exploding.
			local component = rootEntity:GetFirstComponent("ExplodeOnDamageComponent")
			if component then
				component:SetValue("explode_on_death_percent", 0)
			end

			-- Try to prevent some stuff from exploding.
			local component = rootEntity:GetFirstComponent("MaterialInventoryComponent")
			if component then
				component:SetValue("on_death_spill", false)
				component:SetValue("kill_when_empty", false)
			end

		end
	end

	-- Ensure everything is written to disk before noita decides to crash.
	entityFile:flush()
end

function DebugEntityCapture()
	local entityFile = createOrOpenEntityCaptureFile()

	-- Coroutine to capture all entities around the viewport every frame.
	async_loop(function()
		local x, y = GameGetCameraPos() -- Returns the virtual coordinates of the screen center.
		-- Call the protected function and catch any errors.
		local ok, err = pcall(captureEntities, entityFile, x, y, 5000)
		if not ok then
			print(string.format("Entity capture error: %s", err))
		end
		wait(0)
	end)
end

--- Captures a screenshot at the given coordinates.
--- This will block until all chunks in the given area are loaded.
---
--- @param x number -- Virtual x coordinate (World pixels) of the screen center.
--- @param y number -- Virtual y coordinate (World pixels) of the screen center.
--- @param rx number -- Screen x coordinate of the top left corner of the screenshot rectangle.
--- @param ry number -- Screen y coordinate of the top left corner of the screenshot rectangle.
local function captureScreenshot(x, y, rx, ry)
	local virtualWidth, virtualHeight =
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")),
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y"))

	local virtualHalfWidth, virtualHalfHeight = math.floor(virtualWidth / 2), math.floor(virtualHeight / 2)
	local xMin, yMin = x - virtualHalfWidth, y - virtualHalfHeight
	local xMax, yMax = xMin + virtualWidth, yMin + virtualHeight

	UiCaptureDelay = 0
	GameSetCameraPos(x, y)
	repeat
		if UiCaptureDelay > 100 then
			-- Wiggle the screen a bit, as chunks sometimes don't want to load.
			GameSetCameraPos(x + math.random(-100, 100), y + math.random(-100, 100))
			DrawUI()
			wait(0)
			UiCaptureDelay = UiCaptureDelay + 1
			GameSetCameraPos(x, y)
		end

		DrawUI()
		wait(0)
		UiCaptureDelay = UiCaptureDelay + 1

	until DoesWorldExistAt(xMin, yMin, xMax, yMax) -- Chunks will be drawn on the *next* frame.

	wait(0) -- Without this line empty chunks may still appear, also it's needed for the UI to disappear.
	if not TriggerCapture(rx, ry) then
		UiCaptureProblem = "Screen capture failed. Please restart Noita."
	end

	-- Reset monitor and PC standby each screenshot.
	ResetStandbyTimer()
end

function startCapturingSpiral()
	local entityFile = createOrOpenEntityCaptureFile()

	local ox, oy = GameGetCameraPos() -- Returns the virtual coordinates of the screen center.
	ox, oy = math.floor(ox / CAPTURE_GRID_SIZE) * CAPTURE_GRID_SIZE, math.floor(oy / CAPTURE_GRID_SIZE) * CAPTURE_GRID_SIZE
	ox, oy = ox + 256, oy + 256 -- Align screen with ingame chunk grid that is 512x512.
	local x, y = ox, oy

	local virtualWidth, virtualHeight =
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")),
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y"))

	local virtualHalfWidth, virtualHalfHeight = math.floor(virtualWidth / 2), math.floor(virtualHeight / 2)

	GameSetCameraFree(true)

	-- Coroutine to capture all entities around the viewport every frame.
	async_loop(function()
		local x, y = GameGetCameraPos() -- Returns the virtual coordinates of the screen center.
		-- Call the protected function and catch any errors.
		local ok, err = pcall(captureEntities, entityFile, x, y, 5000)
		if not ok then
			print(string.format("Entity capture error: %s", err))
		end
		wait(0)
	end)

	-- Coroutine to calculate next coordinate, and trigger screenshots.
	local i = 1
	async_loop(
		function()
			-- +x
			for i = 1, i, 1 do
				local rx, ry = (x - virtualHalfWidth) * CAPTURE_PIXEL_SIZE, (y - virtualHalfHeight) * CAPTURE_PIXEL_SIZE
				if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
					captureScreenshot(x, y, rx, ry, entityFile)
				end
				x, y = x + CAPTURE_GRID_SIZE, y
			end
			-- +y
			for i = 1, i, 1 do
				local rx, ry = (x - virtualHalfWidth) * CAPTURE_PIXEL_SIZE, (y - virtualHalfHeight) * CAPTURE_PIXEL_SIZE
				if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
					captureScreenshot(x, y, rx, ry, entityFile)
				end
				x, y = x, y + CAPTURE_GRID_SIZE
			end
			i = i + 1
			-- -x
			for i = 1, i, 1 do
				local rx, ry = (x - virtualHalfWidth) * CAPTURE_PIXEL_SIZE, (y - virtualHalfHeight) * CAPTURE_PIXEL_SIZE
				if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
					captureScreenshot(x, y, rx, ry, entityFile)
				end
				x, y = x - CAPTURE_GRID_SIZE, y
			end
			-- -y
			for i = 1, i, 1 do
				local rx, ry = (x - virtualHalfWidth) * CAPTURE_PIXEL_SIZE, (y - virtualHalfHeight) * CAPTURE_PIXEL_SIZE
				if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
					captureScreenshot(x, y, rx, ry, entityFile)
				end
				x, y = x, y - CAPTURE_GRID_SIZE
			end
			i = i + 1
		end
	)
end

function startCapturingHilbert(area)
	local entityFile = createOrOpenEntityCaptureFile()

	local ox, oy = GameGetCameraPos()

	local virtualWidth, virtualHeight =
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")),
		tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y"))

	local virtualHalfWidth, virtualHalfHeight = math.floor(virtualWidth / 2), math.floor(virtualHeight / 2)

	-- Get size of the rectangle in grid/chunk coordinates.
	local gridLeft = math.floor(area.Left / CAPTURE_GRID_SIZE)
	local gridTop = math.floor(area.Top / CAPTURE_GRID_SIZE)
	local gridRight = math.ceil(area.Right / CAPTURE_GRID_SIZE) -- This grid coordinate is not included.
	local gridBottom = math.ceil(area.Bottom / CAPTURE_GRID_SIZE) -- This grid coordinate is not included.

	-- Edge case
	if area.Left == area.Right then
		gridRight = gridLeft
	end
	if area.Top == area.Bottom then
		gridBottom = gridTop
	end

	-- Size of the grid in chunks.
	local gridWidth = gridRight - gridLeft
	local gridHeight = gridBottom - gridTop

	-- Hilbert curve can only fit into a square, so get the longest side.
	local gridPOTSize = math.ceil(math.log(math.max(gridWidth, gridHeight)) / math.log(2))
	-- Max size (Already rounded up to the next power of two).
	local gridMaxSize = math.pow(2, gridPOTSize)

	local t, tLimit = 0, gridMaxSize * gridMaxSize

	UiProgress = {Progress = 0, Max = gridWidth * gridHeight}

	GameSetCameraFree(true)

	-- Coroutine to capture all entities around the viewport every frame.
	async_loop(function()
		local x, y = GameGetCameraPos() -- Returns the virtual coordinates of the screen center.
		-- Call the protected function and catch any errors.
		local ok, err = pcall(captureEntities, entityFile, x, y, 5000)
		if not ok then
			print(string.format("Entity capture error: %s", err))
		end
		wait(0)
	end)

	-- Coroutine to calculate next coordinate, and trigger screenshots.
	async(
		function()
			while t < tLimit do
				local hx, hy = mapHilbert(t, gridPOTSize)
				if hx < gridWidth and hy < gridHeight then
					local x, y = (hx + gridLeft) * CAPTURE_GRID_SIZE, (hy + gridTop) * CAPTURE_GRID_SIZE
					x, y = x + 256, y + 256 -- Align screen with ingame chunk grid that is 512x512.
					local rx, ry = (x - virtualHalfWidth) * CAPTURE_PIXEL_SIZE, (y - virtualHalfHeight) * CAPTURE_PIXEL_SIZE
					if not fileExists(string.format("mods/noita-mapcap/output/%d,%d.png", rx, ry)) then
						captureScreenshot(x, y, rx, ry, entityFile)
					end
					UiProgress.Progress = UiProgress.Progress + 1
				end

				t = t + 1
			end

			UiProgress.Done = true
		end
	)
end
