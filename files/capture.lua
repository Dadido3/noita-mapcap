-- Copyright (c) 2019-2022 David Vogel
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
local Vec2 = require("noita-api.vec2")
local Utils = require("noita-api.utils")

------------------
-- Global stuff --
------------------

----------
-- Code --
----------

Capture.MapCapturingCtx = Capture.MapCapturingCtx or ProcessRunner.New()
Capture.EntityCapturingCtx = Capture.EntityCapturingCtx or ProcessRunner.New()

---Returns a capturing rectangle in window coordinates, and also the world coordinates for the same rectangle.
---The rectangle is sized and placed in a way that aligns as pixel perfect as possible with the world coordinates.
---@param pos Vec2|nil -- Position of the viewport center in world coordinates. If set to nil, the viewport center will be queried automatically.
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
---@param pos Vec2|nil -- Position of the viewport center in world coordinates. If set to nil, the viewport will not be modified.
---@param ensureLoaded boolean|nil -- If true, the function will wait until all chunks in the virtual rectangle are loaded.
---@param dontOverwrite boolean|nil -- If true, the function will abort if there is already a file with the same coordinates.
---@param ctx ProcessRunnerCtx|nil -- The process runner context this runs in.
---@param outputPixelScale number|nil -- The resulting image pixel to world pixel ratio.
local function captureScreenshot(pos, ensureLoaded, dontOverwrite, ctx, outputPixelScale)
	outputPixelScale = outputPixelScale or 0

	local topLeftCapture, bottomRightCapture, topLeftWorld, bottomRightWorld = calculateCaptureRectangle(pos)

	---Top left in output coordinates.
	---@type Vec2
	local outputTopLeft
	if outputPixelScale > 0 then
		outputTopLeft = (topLeftWorld * outputPixelScale):Rounded()
	else
		outputTopLeft = topLeftWorld
	end

	-- Check if the file exists, and if we are allowed to overwrite it.
	if dontOverwrite and Utils.FileExists(string.format("mods/noita-mapcap/output/%d,%d.png", outputTopLeft.x, outputTopLeft.y)) then
		return
	end

	if pos then CameraAPI.SetPos(pos) end
	if ensureLoaded then
		local delayFrames = 0
		repeat
			-- Prematurely stop capturing if that is requested by the context.
			if ctx and ctx:IsStopping() then return end

			if delayFrames > 100 then
				-- Wiggle the screen a bit, as chunks sometimes don't want to load.
				if pos then CameraAPI.SetPos(pos + Vec2(math.random(-100, 100), math.random(-100, 100))) end
				wait(0)
				delayFrames = delayFrames + 1
				if pos then CameraAPI.SetPos(pos) end
			end

			wait(0)
			delayFrames = delayFrames + 1

		until DoesWorldExistAt(topLeftWorld.x, topLeftWorld.y, bottomRightWorld.x, bottomRightWorld.y)
		-- Chunks are loaded and will be drawn on the *next* frame.
	end

	-- Suspend UI drawing for 1 frame.
	UI:SuspendDrawing(1)

	wait(0)

	-- Fetch coordinates again, as they may have changed.
	if not pos then
		topLeftCapture, bottomRightCapture, topLeftWorld, bottomRightWorld = calculateCaptureRectangle(pos)
		if outputPixelScale > 0 then
			outputTopLeft = (topLeftWorld * outputPixelScale):Rounded()
		else
			outputTopLeft = topLeftWorld
		end
	end

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
	print(string.format("Failed to capture map: %s", err))
	Message:ShowRuntimeError("MapCaptureError", "Failed to capture map:", tostring(err))
end

---Starts the capturing process in a spiral around origin.
---Use `Capture.MapCapturingCtx` to stop, control or view the progress.
---@param origin Vec2 -- Center of the spiral in world pixels.
---@param captureGridSize number -- The grid size in world pixels.
---@param outputPixelScale number|nil -- The resulting image pixel to world pixel ratio.
function Capture:StartCapturingSpiral(origin, captureGridSize, outputPixelScale)

	-- Create file that signals that there are files in the output directory.
	local file = io.open("mods/noita-mapcap/output/nonempty", "a")
	if file ~= nil then file:close() end

	---Origin rounded to capture grid.
	---@type Vec2
	local origin = (origin / captureGridSize):Rounded("floor") * captureGridSize

	---The position in world coordinates.
	---Centered to chunks.
	---@type Vec2
	local pos = origin + Vec2(256, 256) -- TODO: Align chunks with top left pixel

	---Process main callback.
	---@param ctx ProcessRunnerCtx
	local function handleDo(ctx)
		CameraAPI.SetCameraFree(true)

		local i = 1
		repeat
			-- +x
			for _ = 1, i, 1 do
				captureScreenshot(pos, true, true, ctx, outputPixelScale)
				pos:Add(Vec2(captureGridSize, 0))
			end
			-- +y
			for _ = 1, i, 1 do
				captureScreenshot(pos, true, true, ctx, outputPixelScale)
				pos:Add(Vec2(0, captureGridSize))
			end
			i = i + 1
			-- -x
			for _ = 1, i, 1 do
				captureScreenshot(pos, true, true, ctx, outputPixelScale)
				pos:Add(Vec2(-captureGridSize, 0))
			end
			-- -y
			for _ = 1, i, 1 do
				captureScreenshot(pos, true, true, ctx, outputPixelScale)
				pos:Add(Vec2(0, -captureGridSize))
			end
			i = i + 1
		until ctx:IsStopping()
	end

	-- Run process, if there is no other running right now.
	self.MapCapturingCtx:Run(nil, handleDo, nil, mapCapturingCtxErrHandler)
end

---Starts the capturing process of the given area.
---Use `Capture.MapCapturingCtx` to stop, control or view the process.
---@param topLeft Vec2 -- Top left of the to be captured rectangle.
---@param bottomRight Vec2 -- Non included bottom left of the to be captured rectangle.
---@param captureGridSize number -- The grid size in world pixels.
---@param outputPixelScale number|nil -- The resulting image pixel to world pixel ratio.
function Capture:StartCapturingArea(topLeft, bottomRight, captureGridSize, outputPixelScale)

	-- Create file that signals that there are files in the output directory.
	local file = io.open("mods/noita-mapcap/output/nonempty", "a")
	if file ~= nil then file:close() end

	---The rectangle in grid coordinates.
	---@type Vec2, Vec2
	local gridTopLeft, gridBottomRight = (topLeft / captureGridSize):Rounded("floor"), (bottomRight / captureGridSize):Rounded("floor")

	-- Handle edge cases.
	if topLeft.x == bottomRight.x then gridBottomRight.x = gridTopLeft.x end
	if topLeft.y == bottomRight.y then gridBottomRight.y = gridTopLeft.y end

	---Size of the rectangle in grid coordinates.
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
		CameraAPI.SetCameraFree(true)
		ctx.progressCurrent, ctx.progressEnd = 0, gridSize.x * gridSize.y

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
				pos:Add(Vec2(256, 256)) -- Move to chunk center -- TODO: Align chunks with top left pixel
				captureScreenshot(pos, true, true, ctx, outputPixelScale)
				ctx.progressCurrent = ctx.progressCurrent + 1
			end

			t = t + 1
		end
	end

	-- Run process, if there is no other running right now.
	self.MapCapturingCtx:Run(nil, handleDo, nil, mapCapturingCtxErrHandler)
end

---Starts the live capturing process.
---Use `Capture.MapCapturingCtx` to stop, control or view the process.
---@param interval integer|nil -- The interval length in frames. Defaults to 60.
---@param minDistance number|nil -- The minimum distance between screenshots. This will prevent screenshots if the player doesn't move much.
---@param maxDistance number|nil -- The maximum distance between screenshots. This will allow more screenshots per interval if the player moves fast.
---@param outputPixelScale number|nil -- The resulting image pixel to world pixel ratio.
function Capture:StartCapturingLive(interval, minDistance, maxDistance, outputPixelScale)
	interval = interval or 60
	minDistance = minDistance or 10
	maxDistance = maxDistance or 50

	-- Create file that signals that there are files in the output directory.
	local file = io.open("mods/noita-mapcap/output/nonempty", "a")
	if file ~= nil then file:close() end

	---Process main callback.
	---@param ctx ProcessRunnerCtx
	local function handleDo(ctx)
		local oldPos
		local minDistanceSqr, maxDistanceSqr = minDistance ^ 2, maxDistance ^ 2

		repeat
			-- Wait until we are allowed to take a new screenshot.
			local delayFrames = 0
			repeat
				wait(0)
				delayFrames = delayFrames + 1

				local distanceSqr
				if oldPos then distanceSqr = CameraAPI.GetPos():DistanceSqr(oldPos) else distanceSqr = math.huge end
			until ctx:IsStopping() or ((delayFrames >= interval or distanceSqr >= maxDistanceSqr) and distanceSqr >= minDistanceSqr)

			captureScreenshot(nil, false, false, ctx, outputPixelScale)
			oldPos = CameraAPI.GetPos()
		until ctx:IsStopping()
	end

	-- Run process, if there is no other running right now.
	self.MapCapturingCtx:Run(nil, handleDo, nil, mapCapturingCtxErrHandler)
end

---Gathers all entities on the screen (around x, y within radius), serializes them, appends them into entityFile and modifies those entities.
---@param file file*|nil
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
		end
	end

	-- Ensure everything is written to disk before noita decides to crash.
	if file then
		file:flush()
	end
end

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

---Starts the capturing process based on user/mod settings.
function Capture:StartCapturing()
	Message:CatchException("Capture:StartCapturing", function()

		local mode = ModSettingGet("noita-mapcap.capture-mode")
		local outputPixelScale = ModSettingGet("noita-mapcap.pixel-scale")
		local captureGridSize = tonumber(ModSettingGet("noita-mapcap.grid-size"))

		if mode == "live" then
			local interval = ModSettingGet("noita-mapcap.live-interval")
			local minDistance = ModSettingGet("noita-mapcap.live-min-distance")
			local maxDistance = ModSettingGet("noita-mapcap.live-max-distance")

			self:StartCapturingLive(interval, minDistance, maxDistance, outputPixelScale)
		elseif mode == "area" then
			local area = ModSettingGet("noita-mapcap.area")
			if area == "custom" then
				local topLeft = Vec2(ModSettingGet("noita-mapcap.area-top-left"))
				local bottomRight = Vec2(ModSettingGet("noita-mapcap.area-bottom-right"))

				self:StartCapturingArea(topLeft, bottomRight, captureGridSize, outputPixelScale)
			else
				local predefinedArea = Config.CaptureArea[area]
				if predefinedArea then
					self:StartCapturingArea(predefinedArea.TopLeft, predefinedArea.BottomRight, captureGridSize, outputPixelScale)
				else
					Message:ShowRuntimeError("PredefinedArea", string.format("Unknown predefined capturing area %q", tostring(area)))
				end
			end
		elseif mode == "spiral" then
			local origin = ModSettingGet("noita-mapcap.capture-mode-spiral-origin")
			if origin == "custom" then
				local originVec = Vec2(ModSettingGet("noita-mapcap.capture-mode-spiral-origin-vector"))
				self:StartCapturingSpiral(originVec, captureGridSize, outputPixelScale)
			elseif origin == "0" then
				local originVec = Vec2(0, 0)
				self:StartCapturingSpiral(originVec, captureGridSize, outputPixelScale)
			elseif origin == "current" then
				local originVec = CameraAPI:GetPos()
				self:StartCapturingSpiral(originVec, captureGridSize, outputPixelScale)
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
end
