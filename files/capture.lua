-- Copyright (c) 2019-2024 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

--------------------------
-- Load library modules --
--------------------------

local CameraAPI = require("noita-api.camera")
local Coords = require("coordinates")
local EntityAPI = require("noita-api.entity")
local Hilbert = require("hilbert-curve")
local JSON = require("noita-api.json")
local MonitorStandby = require("monitor-standby")
local ProcessRunner = require("process-runner")
local ScreenCapture = require("screen-capture")
local Utils = require("noita-api.utils")
local Vec2 = require("noita-api.vec2")

------------------
-- Global stuff --
------------------

----------
-- Code --
----------

Capture.MapCapturingCtx = Capture.MapCapturingCtx or ProcessRunner.New()
Capture.EntityCapturingCtx = Capture.EntityCapturingCtx or ProcessRunner.New()
Capture.PlayerPathCapturingCtx = Capture.PlayerPathCapturingCtx or ProcessRunner.New()

---Returns a capturing rectangle in window coordinates, and also the world coordinates for the same rectangle.
---The rectangle is sized and placed in a way that aligns as pixel perfect as possible with the world coordinates.
---@param pos Vec2? -- Position of the viewport center in world coordinates. If set to nil, the viewport center will be queried automatically.
---@return Vec2 topLeftCapture
---@return Vec2 bottomRightCapture
---@return Vec2 topLeftWorld
---@return Vec2 bottomRightWorld
local function calculateCaptureRectangle(pos)
	local topLeft, bottomRight = Coords:ValidRenderingRect()

	-- Convert valid rendering rectangle into world coordinates, and round it towards the window center.
	local topLeftWorld, bottomRightWorld = Coords:ToWorld(topLeft, pos):Rounded("ceil"), Coords:ToWorld(bottomRight, pos):Rounded("floor")

	-- Convert back into window coordinates, and round to nearest.
	local topLeftCapture, bottomRightCapture = Coords:ToWindow(topLeftWorld, pos):Rounded(), Coords:ToWindow(bottomRightWorld, pos):Rounded()

	return topLeftCapture, bottomRightCapture, topLeftWorld, bottomRightWorld
end

---Captures a screenshot at the given position in world coordinates.
---This will block until all chunks in the virtual rectangle are loaded.
---
---Don't set `ensureLoaded` to true when `pos` is nil!
---@param pos Vec2? -- Position of the viewport center in world coordinates. If set to nil, the viewport will not be modified.
---@param ensureLoaded boolean? -- If true, the function will wait until all chunks in the virtual rectangle are loaded.
---@param dontOverwrite boolean? -- If true, the function will abort if there is already a file with the same coordinates.
---@param ctx ProcessRunnerCtx? -- The process runner context this runs in.
---@param outputPixelScale number? -- The resulting image pixel to world pixel ratio.
---@param captureDelay number? -- The number of additional frames to wait before a screen capture.
local function captureScreenshot(pos, ensureLoaded, dontOverwrite, ctx, outputPixelScale, captureDelay)
	if outputPixelScale == 0 or outputPixelScale == nil then
		outputPixelScale = Coords:PixelScale()
	end

	local rectTopLeft, rectBottomRight = ScreenCapture.GetRect()
	if Coords:InternalRectSize() ~= rectBottomRight - rectTopLeft then
		error(string.format("internal rectangle size seems to have changed from %s to %s", Coords:InternalRectSize(), rectBottomRight - rectTopLeft))
	end

	local topLeftCapture, bottomRightCapture, topLeftWorld, bottomRightWorld = calculateCaptureRectangle(pos)

	---Top left in output coordinates.
	---@type Vec2
	local outputTopLeft = (topLeftWorld * outputPixelScale):Rounded()

	-- Check if the file exists, and if we are allowed to overwrite it.
	if dontOverwrite and Utils.FileExists(string.format("mods/noita-mapcap/output/%d,%d.png", outputTopLeft.x, outputTopLeft.y)) then
		return
	end

	-- Reset the count for the "Waiting for x frames." message in the UI.
	if ctx then ctx.state.WaitFrames = 0 end

	-- Wait some additional frames.
	-- We will shake the screen a little bit so that Noita generates/populates chunks.
	if captureDelay and captureDelay > 0 then
		for _ = 1, captureDelay do
			if pos then CameraAPI.SetPos(pos + Vec2(math.random(-1, 1), math.random(-1, 1))) end
			wait(0)
			if ctx then ctx.state.WaitFrames = ctx.state.WaitFrames + 1 end
		end
	end

	if pos then CameraAPI.SetPos(pos) end

	if ensureLoaded then
		local delayFrames = 0
		repeat
			-- Prematurely stop capturing if that is requested by the context.
			if ctx and ctx:IsStopping() then return end

			if delayFrames > 30 then
				-- Wiggle the screen a bit, as chunks sometimes don't want to load.
				if pos then CameraAPI.SetPos(pos + Vec2(math.random(-10, 10), math.random(-10, 10))) end
				wait(0)
				delayFrames = delayFrames + 1
				if ctx then ctx.state.WaitFrames = ctx.state.WaitFrames + 1 end
				if pos then CameraAPI.SetPos(pos) end
			end

			if delayFrames > 600 then
				-- Shaking wasn't enough, we will just move somewhere else an try again.
				if pos then CameraAPI.SetPos(pos + Vec2(math.random(-4000, 4000), math.random(-4000, 4000))) end
				wait(50)
				delayFrames = delayFrames + 50
				if ctx then ctx.state.WaitFrames = ctx.state.WaitFrames + 50 end
				if pos then CameraAPI.SetPos(pos) end
				wait(10)
				delayFrames = delayFrames + 10
				if ctx then ctx.state.WaitFrames = ctx.state.WaitFrames + 10 end
			end

			wait(0)
			delayFrames = delayFrames + 1
			if ctx then ctx.state.WaitFrames = ctx.state.WaitFrames + 1 end

			local topLeftBounds, bottomRightBounds = CameraAPI:Bounds()
		until DoesWorldExistAt(topLeftBounds.x, topLeftBounds.y, bottomRightBounds.x, bottomRightBounds.y)
		-- Chunks are loaded and will be drawn on the *next* frame.
	end

	if ctx then ctx.state.WaitFrames = 0 end

	-- Suspend UI drawing for 1 frame.
	UI:SuspendDrawing(1)

	-- First we wait one frame for the current state to be drawn.
	wait(0)

	-- At this point the needed frame is fully drawn, but the framebuffers are swapped.

	-- Recalculate capture position and rectangle if we are not forcing any capture position.
	-- We are in the `OnWorldPreUpdate` hook, this means that `CameraAPI.GetPos` return the position of the last frame.
	if not pos then
		topLeftCapture, bottomRightCapture, topLeftWorld, bottomRightWorld = calculateCaptureRectangle(pos)
		if outputPixelScale > 0 then
			outputTopLeft = (topLeftWorld * outputPixelScale):Rounded()
		else
			outputTopLeft = topLeftWorld
		end
	end

	-- Wait another frame.
	-- After this `wait` the framebuffer will be swapped again, and we can grab the correct frame.
	wait(0)

	-- The top left world position needs to be upscaled by the pixel scale.
	-- Otherwise it's not possible to stitch the images correctly.
	if not ScreenCapture.Capture(topLeftCapture, bottomRightCapture, outputTopLeft, (bottomRightWorld - topLeftWorld) * outputPixelScale) then
		error(string.format("failed to capture screenshot"))
	end

	-- Reset monitor and PC standby every screenshot.
	MonitorStandby.ResetTimer()
end

---Map capture process runner context error handler callback. Just rolls off the tongue.
---@param err string
---@param scope "init"|"do"|"end"
local function mapCapturingCtxErrHandler(err, scope)
	print(string.format("Failed to capture map: %s.", err))
	Message:ShowRuntimeError("MapCaptureError", "Failed to capture map:", tostring(err))
end

---Starts the capturing process in a spiral around origin.
---Use `Capture.MapCapturingCtx` to stop, control or view the progress.
---@param origin Vec2 -- Center of the spiral in world pixels.
---@param captureGridSize number -- The grid size in world pixels.
---@param outputPixelScale number? -- The resulting image pixel to world pixel ratio.
---@param captureDelay number? -- The number of additional frames to wait before a screen capture.
function Capture:StartCapturingSpiral(origin, captureGridSize, outputPixelScale, captureDelay)

	-- Create file that signals that there are files in the output directory.
	local file = io.open("mods/noita-mapcap/output/nonempty", "a")
	if file ~= nil then file:close() end

	---Origin rounded to capture grid.
	---@type Vec2
	local origin = (origin / captureGridSize):Rounded("floor") * captureGridSize

	---The position in world coordinates.
	---Centered to the grid.
	---@type Vec2
	local pos = origin + Vec2(captureGridSize / 2, captureGridSize / 2)

	---Process main callback.
	---@param ctx ProcessRunnerCtx
	local function handleDo(ctx)
		Modification.SetCameraFree(true)

		local i = 1
		repeat
			-- +x
			for _ = 1, i, 1 do
				captureScreenshot(pos, true, true, ctx, outputPixelScale, captureDelay)
				pos:Add(Vec2(captureGridSize, 0))
			end
			-- +y
			for _ = 1, i, 1 do
				captureScreenshot(pos, true, true, ctx, outputPixelScale, captureDelay)
				pos:Add(Vec2(0, captureGridSize))
			end
			i = i + 1
			-- -x
			for _ = 1, i, 1 do
				captureScreenshot(pos, true, true, ctx, outputPixelScale, captureDelay)
				pos:Add(Vec2(-captureGridSize, 0))
			end
			-- -y
			for _ = 1, i, 1 do
				captureScreenshot(pos, true, true, ctx, outputPixelScale, captureDelay)
				pos:Add(Vec2(0, -captureGridSize))
			end
			i = i + 1
		until ctx:IsStopping()
	end

	---Process end callback.
	---@param ctx ProcessRunnerCtx
	local function handleEnd(ctx)
		Modification.SetCameraFree()
	end

	-- Run process, if there is no other running right now.
	self.MapCapturingCtx:Run(nil, handleDo, handleEnd, mapCapturingCtxErrHandler)
end

---Starts the capturing process of the given area using a hilbert curve.
---Use `Capture.MapCapturingCtx` to stop, control or view the process.
---@param topLeft Vec2 -- Top left of the to be captured rectangle.
---@param bottomRight Vec2 -- Non inclusive bottom right coordinate of the to be captured rectangle.
---@param captureGridSize number -- The grid size in world pixels.
---@param outputPixelScale number? -- The resulting image pixel to world pixel ratio.
---@param captureDelay number? -- The number of additional frames to wait before a screen capture.
function Capture:StartCapturingAreaHilbert(topLeft, bottomRight, captureGridSize, outputPixelScale, captureDelay)

	-- Create file that signals that there are files in the output directory.
	local file = io.open("mods/noita-mapcap/output/nonempty", "a")
	if file ~= nil then file:close() end

	-- The capture offset which is needed to center the grid cells in the viewport.
	local captureOffset = Vec2(captureGridSize / 2, captureGridSize / 2)

	-- Get the extended capture rectangle that encloses all grid cells that need to be included in the capture.
	-- In this case we only need to extend the capture area by the valid rendering rectangle.
	local validTopLeft, validBottomRight = Coords:ValidRenderingRect()
	local validTopLeftWorld, validBottomRightWorld = Coords:ToWorld(validTopLeft, topLeft + captureOffset), Coords:ToWorld(validBottomRight, bottomRight + captureOffset)

	---The capture rectangle in grid coordinates.
	---@type Vec2, Vec2
	local gridTopLeft, gridBottomRight = (validTopLeftWorld / captureGridSize):Rounded("floor"), ((validBottomRightWorld) / captureGridSize):Rounded("ceil") - Vec2(1, 1)

	---Size of the rectangle in grid cells.
	---@type Vec2
	local gridSize = gridBottomRight - gridTopLeft

	-- Hilbert curve can only fit into a square, so get the longest side.
	local gridPOTSize = math.ceil(math.log(math.max(gridSize.x, gridSize.y)) / math.log(2))

	-- Max size (Already rounded up to the next power of two).
	local gridMaxSize = math.pow(2, gridPOTSize)

	local t, tLimit = 0, gridMaxSize * gridMaxSize

	---Process main callback.
	---@param ctx ProcessRunnerCtx
	local function handleDo(ctx)
		Modification.SetCameraFree(true)
		ctx.state = { Current = 0, Max = gridSize.x * gridSize.y }

		while t < tLimit do
			-- Prematurely stop capturing if that is requested by the context.
			if ctx:IsStopping() then return end

			---Position in grid coordinates.
			---@type Vec2
			local hilbertPos = Vec2(Hilbert.Map(t, gridPOTSize))
			if hilbertPos.x < gridSize.x and hilbertPos.y < gridSize.y then
				---Position in world coordinates.
				---@type Vec2
				local pos = (hilbertPos + gridTopLeft) * captureGridSize
				pos:Add(captureOffset) -- Move to center of grid cell.
				captureScreenshot(pos, true, true, ctx, outputPixelScale, captureDelay)
				ctx.state.Current = ctx.state.Current + 1
			end

			t = t + 1
		end
	end

	---Process end callback.
	---@param ctx ProcessRunnerCtx
	local function handleEnd(ctx)
		Modification.SetCameraFree()
	end

	-- Run process, if there is no other running right now.
	self.MapCapturingCtx:Run(nil, handleDo, handleEnd, mapCapturingCtxErrHandler)
end

---Starts the capturing process of the given area by scanning from left to right, and top to bottom.
---Use `Capture.MapCapturingCtx` to stop, control or view the process.
---@param topLeft Vec2 -- Top left of the to be captured rectangle.
---@param bottomRight Vec2 -- Non inclusive bottom right coordinate of the to be captured rectangle.
---@param captureGridSize number -- The grid size in world pixels.
---@param outputPixelScale number? -- The resulting image pixel to world pixel ratio.
---@param captureDelay number? -- The number of additional frames to wait before a screen capture.
function Capture:StartCapturingAreaScan(topLeft, bottomRight, captureGridSize, outputPixelScale, captureDelay)

	-- Create file that signals that there are files in the output directory.
	local file = io.open("mods/noita-mapcap/output/nonempty", "a")
	if file ~= nil then file:close() end

	-- The capture offset which is needed to center the grid cells in the viewport.
	local captureOffset = Vec2(captureGridSize / 2, captureGridSize / 2)

	-- Get the extended capture rectangle that encloses all grid cells that need to be included in the capture.
	-- In this case we only need to extend the capture area by the valid rendering rectangle.
	local validTopLeft, validBottomRight = Coords:ValidRenderingRect()
	local validTopLeftWorld, validBottomRightWorld = Coords:ToWorld(validTopLeft, topLeft + captureOffset), Coords:ToWorld(validBottomRight, bottomRight + captureOffset)

	---The capture rectangle in grid coordinates.
	---@type Vec2, Vec2
	local gridTopLeft, gridBottomRight = (validTopLeftWorld / captureGridSize):Rounded("floor"), ((validBottomRightWorld) / captureGridSize):Rounded("ceil") - Vec2(1, 1)

	---Size of the rectangle in grid cells.
	---@type Vec2
	local gridSize = gridBottomRight - gridTopLeft

	---Process main callback.
	---@param ctx ProcessRunnerCtx
	local function handleDo(ctx)
		Modification.SetCameraFree(true)
		ctx.state = { Current = 0, Max = gridSize.x * gridSize.y }

		for gridY = gridTopLeft.y, gridBottomRight.y-1, 1 do
			for gridX = gridTopLeft.x, gridBottomRight.x-1, 1 do
				-- Prematurely stop capturing if that is requested by the context.
				if ctx:IsStopping() then return end

				---Position in grid coordinates.
				---@type Vec2
				local gridPos = Vec2(gridX, gridY)

				---Position in world coordinates.
				---@type Vec2
				local pos = gridPos * captureGridSize
				pos:Add(captureOffset) -- Move to center of grid cell.
				captureScreenshot(pos, true, true, ctx, outputPixelScale, captureDelay)
				ctx.state.Current = ctx.state.Current + 1
			end
		end
	end

	---Process end callback.
	---@param ctx ProcessRunnerCtx
	local function handleEnd(ctx)
		Modification.SetCameraFree()
	end

	-- Run process, if there is no other running right now.
	self.MapCapturingCtx:Run(nil, handleDo, handleEnd, mapCapturingCtxErrHandler)
end

---Starts the live capturing process.
---Use `Capture.MapCapturingCtx` to stop, control or view the process.
---@param outputPixelScale number? -- The resulting image pixel to world pixel ratio.
function Capture:StartCapturingLive(outputPixelScale)

	---Queries the mod settings for the live capture parameters.
	---@return integer interval -- The interval length in frames. Defaults to 30.
	---@return number minDistanceSqr -- The minimum (squared) distance between screenshots. This will prevent screenshots if the player doesn't move much.
	---@return number maxDistanceSqr -- The maximum (squared) distance between screenshots. This will allow more screenshots per interval if the player moves fast.
	local function querySettings()
		local interval = tonumber(ModSettingGet("noita-mapcap.live-interval")) or 30
		local minDistance = tonumber(ModSettingGet("noita-mapcap.live-min-distance")) or 10
		local maxDistance = tonumber(ModSettingGet("noita-mapcap.live-max-distance")) or 50
		return interval, minDistance ^ 2, maxDistance ^ 2
	end

	-- Create file that signals that there are files in the output directory.
	local file = io.open("mods/noita-mapcap/output/nonempty", "a")
	if file ~= nil then file:close() end

	---Process main callback.
	---@param ctx ProcessRunnerCtx
	local function handleDo(ctx)
		Modification.SetCameraFree(false)

		local oldPos

		repeat
			local interval, minDistanceSqr, maxDistanceSqr = querySettings()

			-- Wait until we are allowed to take a new screenshot.
			local delayFrames = 0
			repeat
				wait(0)
				delayFrames = delayFrames + 1

				local distanceSqr
				if oldPos then distanceSqr = CameraAPI.GetPos():DistanceSqr(oldPos) else distanceSqr = math.huge end
			until ctx:IsStopping() or ((delayFrames >= interval or distanceSqr >= maxDistanceSqr) and distanceSqr >= minDistanceSqr)

			captureScreenshot(nil, false, false, ctx, outputPixelScale, nil)
			oldPos = CameraAPI.GetPos()
		until ctx:IsStopping()
	end

	---Process end callback.
	---@param ctx ProcessRunnerCtx
	local function handleEnd(ctx)
		Modification.SetCameraFree()
	end

	-- Run process, if there is no other running right now.
	self.MapCapturingCtx:Run(nil, handleDo, handleEnd, mapCapturingCtxErrHandler)
end

---Gathers all entities on the screen (around x, y within radius), serializes them, appends them into entityFile and/or modifies those entities.
---@param file file*?
---@param modify boolean
---@param x number
---@param y number
---@param radius number
local function captureModifyEntities(file, modify, x, y, radius)
	local entities = EntityAPI.GetInRadius(x, y, radius)
	for _, entity in ipairs(entities) do
		-- Get to the root entity, as we are exporting entire entity trees.
		local rootEntity = entity:GetRootEntity() or entity

		-- Make sure to only export entities when they are encountered the first time.
		if file and not rootEntity:HasTag("MapCaptured") then
			--print(rootEntity:GetFilename(), "got captured!")

			-- Some hacky way to generate valid JSON that doesn't break when the game crashes.
			-- Well, as long as it does not crash between write and flush.
			if file:seek("end") == 0 then
				-- First line.
				file:write("[\n\t", JSON.Marshal(rootEntity), "\n", "]")
			else
				-- Following lines.
				file:seek("end", -2) -- Seek a few bytes back, so we can overwrite some stuff.
				file:write(",\n\t", JSON.Marshal(rootEntity), "\n", "]")
			end

			-- Disabling this component will prevent entities from being killed/reset when they go offscreen.
			-- If they are reset, all tags will be reset and we may capture these entities multiple times.
			-- This has some side effects, like longleg.xml and zombie_weak.xml will respawn every revisit, as their spawner doesn't get deleted. (Or something similar to this)
			local components = rootEntity:GetComponents("CameraBoundComponent")
			for _, component in ipairs(components) do
				rootEntity:SetComponentsEnabled(component, false)
			end

			-- Prevent recapturing.
			rootEntity:AddTag("MapCaptured")
		end

		-- Make sure to only modify entities when they are encountered the first time.
		-- Also, don't modify the player.
		if modify and not rootEntity:IsPlayer() and not rootEntity:HasTag("MapModified") then
			-- Disable some components.
			for _, componentTypeName in ipairs(Config.ComponentsToDisable) do
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

			-- Prevent it from being modified again.
			rootEntity:AddTag("MapModified")

			-- Just a test on how to remove/kill creatures and enemies.
			--if (rootEntity:HasTag("enemy") or rootEntity:HasTag("helpless_animal")) and not rootEntity:HasTag("boss") then
			--	rootEntity:Kill()
			--end
		end
	end

	-- Ensure everything is written to disk before noita decides to crash.
	if file then
		file:flush()
	end
end

---
---@return file*?
local function createOrOpenEntityCaptureFile()
	-- Make sure the file exists.
	local file = io.open("mods/noita-mapcap/output/entities.json", "a")
	if file ~= nil then file:close() end

	-- Create or reopen entities JSON file.
	file = io.open("mods/noita-mapcap/output/entities.json", "r+b") -- Open for reading (r) and writing (+) in binary mode. r+b will not truncate the file to 0.
	if file == nil then return nil end

	return file
end

---Starts entity capturing and modification.
---Use `Capture.EntityCapturingCtx` to stop, control or view the progress.
---@param store boolean -- Will create a file and write all encountered entities into it.
---@param modify boolean -- Will modify all encountered entities.
function Capture:StartCapturingEntities(store, modify)
	-- There is nothing to capture, don't start anything.
	if not store and not modify then return end

	local file

	---Process initialization callback.
	---@param ctx ProcessRunnerCtx
	local function handleInit(ctx)
		-- Create output file if requested.
		file = store and createOrOpenEntityCaptureFile() or nil
	end

	---Process main callback.
	---@param ctx ProcessRunnerCtx
	local function handleDo(ctx)
		repeat
			local pos, radius = CameraAPI:GetPos(), 5000 -- Returns the virtual coordinates of the screen center.
			captureModifyEntities(file, modify, pos.x, pos.y, radius)

			wait(0)
		until ctx:IsStopping()
	end

	---Process end callback.
	---@param ctx ProcessRunnerCtx
	local function handleEnd(ctx)
		if file then file:close() end
	end

	---Error handler callback.
	---@param err string
	---@param scope "init"|"do"|"end"
	local function handleErr(err, scope)
		print(string.format("Failed to capture entities: %s", err))
		Message:ShowRuntimeError("EntitiesCaptureError", "Failed to capture entities:", tostring(err))
	end

	-- Run process, if there is no other running right now.
	self.EntityCapturingCtx:Run(handleInit, handleDo, handleEnd, handleErr)
end

---Writes the current player position and other stats onto disk.
---@param file file*?
---@param pos Vec2
---@param oldPos Vec2
---@param hp number
---@param maxHP number
---@param polymorphed boolean
local function writePlayerPathEntry(file, pos, oldPos, hp, maxHP, polymorphed)
	if not file then return end

	local struct = {
		from = oldPos,
		to = pos,
		hp = hp,
		maxHP = maxHP,
		polymorphed = polymorphed,
	}

	-- Some hacky way to generate valid JSON that doesn't break when the game crashes.
	-- Well, as long as it does not crash between write and flush.
	if file:seek("end") == 0 then
		-- First line.
		file:write("[\n\t", JSON.Marshal(struct), "\n", "]")
	else
		-- Following lines.
		file:seek("end", -2) -- Seek a few bytes back, so we can overwrite some stuff.
		file:write(",\n\t", JSON.Marshal(struct), "\n", "]")
	end

	-- Ensure everything is written to disk before noita decides to crash.
	file:flush()
end

---
---@return file*?
local function createOrOpenPlayerPathCaptureFile()
	-- Make sure the file exists.
	local file = io.open("mods/noita-mapcap/output/player-path.json", "a")
	if file ~= nil then file:close() end

	-- Create or reopen JSON file.
	file = io.open("mods/noita-mapcap/output/player-path.json", "r+b") -- Open for reading (r) and writing (+) in binary mode. r+b will not truncate the file to 0.
	if file == nil then return nil end

	return file
end

---Starts capturing the player path.
---Use `Capture.PlayerPathCapturingCtx` to stop, control or view the progress.
---@param interval integer? -- Wait time between captures in frames.
---@param outputPixelScale number? -- The resulting image pixel to world pixel ratio.
function Capture:StartCapturingPlayerPath(interval, outputPixelScale)
	interval = interval or 20

	if outputPixelScale == 0 or outputPixelScale == nil then
		outputPixelScale = Coords:PixelScale()
	end

	local file
	local oldPos

	---Process initialization callback.
	---@param ctx ProcessRunnerCtx
	local function handleInit(ctx)
		-- Create output file if requested.
		file = createOrOpenPlayerPathCaptureFile()
	end

	---Process main callback.
	---@param ctx ProcessRunnerCtx
	local function handleDo(ctx)
		repeat
			-- Get player entity, even if it is polymorphed.

			-- For some reason Noita crashes when querying the "is_player" GameStatsComponent value on a freshly polymorphed entity found by its "player_unit" tag.
			-- It seems that the entity can still be found by the tag, but its components/values can't be accessed anymore.
			-- Solution: Don't do that.

			---@type NoitaEntity?
			local playerEntity

			-- Try to find the regular player entity.
			for _, entity in ipairs(EntityAPI.GetWithTag("player_unit")) do
				playerEntity = entity
				break
			end

			-- If no player_unit entity was found, check if the player is any of the polymorphed entities.
			if not playerEntity then
				for _, entity in ipairs(EntityAPI.GetWithTag("polymorphed")) do
					local gameStatsComponent = entity:GetFirstComponent("GameStatsComponent")
					if gameStatsComponent and gameStatsComponent:GetValue("is_player") then
						playerEntity = entity
						break
					end
				end
			end

			-- Found some player entity.
			if playerEntity then
				-- Get position.
				local x, y, rotation, scaleX, scaleY = playerEntity:GetTransform()
				local pos = Vec2(x, y) * outputPixelScale

				-- Get some other stats from the player.
				local damageModel = playerEntity:GetFirstComponent("DamageModelComponent")
				local hp, maxHP
				if damageModel then
					hp, maxHP = damageModel:GetValue("hp"), damageModel:GetValue("max_hp")
				end
				local polymorphed = playerEntity:HasTag("polymorphed")

				if oldPos then writePlayerPathEntry(file, pos, oldPos, hp, maxHP, polymorphed) end
				oldPos = pos
			end

			wait(interval)
		until ctx:IsStopping()
	end

	---Process end callback.
	---@param ctx ProcessRunnerCtx
	local function handleEnd(ctx)
		if file then file:close() end
	end

	---Error handler callback.
	---@param err string
	---@param scope "init"|"do"|"end"
	local function handleErr(err, scope)
		print(string.format("Failed to capture player path: %s", err))
		Message:ShowRuntimeError("PlayerPathCaptureError", "Failed to capture player path:", tostring(err))
	end

	-- Run process, if there is no other running right now.
	self.PlayerPathCapturingCtx:Run(handleInit, handleDo, handleEnd, handleErr)
end

---Starts the capturing process based on user/mod settings.
function Capture:StartCapturing()
	Message:CatchException("Capture:StartCapturing", function()

		local mode = ModSettingGet("noita-mapcap.capture-mode")
		local outputPixelScale = ModSettingGet("noita-mapcap.pixel-scale")
		local captureGridSize = tonumber(ModSettingGet("noita-mapcap.grid-size"))
		local captureDelay = tonumber(ModSettingGet("noita-mapcap.capture-delay"))

		if mode == "live" then
			self:StartCapturingLive(outputPixelScale)
			self:StartCapturingPlayerPath(5, outputPixelScale) -- Capture player path with an interval of 5 frames.
		elseif mode == "area" then
			local area = ModSettingGet("noita-mapcap.area")
			if area == "custom" then
				local topLeft = Vec2(ModSettingGet("noita-mapcap.area-top-left"))
				local bottomRight = Vec2(ModSettingGet("noita-mapcap.area-bottom-right"))

				self:StartCapturingAreaScan(topLeft, bottomRight, captureGridSize, outputPixelScale, captureDelay)
			else
				local predefinedAreaFunction = Config.CaptureArea[area]
				if predefinedAreaFunction then
					local predefinedArea = predefinedAreaFunction()
					self:StartCapturingAreaScan(predefinedArea.TopLeft, predefinedArea.BottomRight, captureGridSize, outputPixelScale, captureDelay)
				else
					Message:ShowRuntimeError("PredefinedArea", string.format("Unknown predefined capturing area %q", tostring(area)))
				end
			end
		elseif mode == "spiral" then
			local origin = ModSettingGet("noita-mapcap.capture-mode-spiral-origin")
			if origin == "custom" then
				local originVec = Vec2(ModSettingGet("noita-mapcap.capture-mode-spiral-origin-vector"))
				self:StartCapturingSpiral(originVec, captureGridSize, outputPixelScale, captureDelay)
			elseif origin == "0" then
				local originVec = Vec2(0, 0)
				self:StartCapturingSpiral(originVec, captureGridSize, outputPixelScale, captureDelay)
			elseif origin == "current" then
				local originVec = CameraAPI:GetPos()
				self:StartCapturingSpiral(originVec, captureGridSize, outputPixelScale, captureDelay)
			else
				Message:ShowRuntimeError("SpiralOrigin", string.format("Unknown spiral origin %q", tostring(origin)))
			end
		else
			Message:ShowRuntimeError("StartCapturing", string.format("Unknown capturing mode %q", tostring(mode)))
		end

		-- Start entity capturing and modification, if wanted.
		local captureEntities = ModSettingGet("noita-mapcap.capture-entities")
		local modifyEntities = ModSettingGet("noita-mapcap.modify-entities")
		self:StartCapturingEntities(captureEntities, modifyEntities)

	end)
end

---Stops all capturing processes.
function Capture:StopCapturing()
	self.EntityCapturingCtx:Stop()
	self.MapCapturingCtx:Stop()
	self.PlayerPathCapturingCtx:Stop()
end
