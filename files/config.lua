-- Copyright (c) 2022-2024 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local NXML = require("luanxml.nxml")
local Vec2 = require("noita-api.vec2")

-- List of components that will be disabled on every encountered entity.
-- This is only used when modifying entities, not when capturing/storing them.
Config.ComponentsToDisable = {
	"AnimalAIComponent",
	"SimplePhysicsComponent",
	"CharacterPlatformingComponent",
	"WormComponent",
	"WormAIComponent",
	--"CameraBoundComponent", -- This is already removed when capturing/storing entities. Not needed when we only modify entities.
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

local CHUNK_SIZE = 512

---Returns the rectangle of the base area as two vectors.
---@return Vec2 TopLeft Top left corner in world coordinates.
---@return Vec2 BottomRight Bottom right corner in world coordinates. This pixel is not included in the final rectangle.
local function getBaseArea()
	local xml = NXML.parse(ModTextFileGetContent("data/biome/_biomes_all.xml"))
	local width, height = BiomeMapGetSize()
	local offsetX, offsetY = math.floor(width/2), xml.attr.biome_offset_y -- TODO: This may not be right. Check what Noita is really doing when we have a biome map with an odd width.
	return Vec2(-offsetX, -offsetY)*CHUNK_SIZE, Vec2(-offsetX+width, -offsetY+height)*CHUNK_SIZE
	--return Vec2(-17920, -7168), Vec2(17920, 17408) -- Coordinates for a "New Game" without mods or anything.
end

---A list of capture areas.
---This contains functions that determine the capture area based on the biome size and other parameters.
---The returned vectors are the top left corner, and the bottom right corner of the capture area in world coordinates.
---The bottom right corner pixel is not included in the rectangle.
---@type table<string, fun():Vec2, Vec2>
Config.CaptureArea = {
	-- Base layout: Every part outside this is based on a similar layout, but uses different materials/seeds.
	["1x1"] = getBaseArea,

	-- Main world: The main world with 3 parts: sky, normal and hell.
	["1x3"] = function()
		local width, height = BiomeMapGetSize()
		local topLeft, bottomRight = getBaseArea()
		return topLeft + Vec2(0, -height)*CHUNK_SIZE, bottomRight + Vec2(0, height)*CHUNK_SIZE
		--return Vec2(-17920, -31744), Vec2(17920, 41984) -- Coordinates for a "New Game" without mods or anything.
	end,

	-- -1 parallel world: The parallel world with 3 parts: sky, normal and hell.
	["1x3 -1"] = function()
		local width, height = BiomeMapGetSize()
		local topLeft, bottomRight = getBaseArea()
		return topLeft + Vec2(-width, -height)*CHUNK_SIZE, bottomRight + Vec2(-width, height)*CHUNK_SIZE
		--return Vec2(-17920, -31744) + Vec2(-35840, 0), Vec2(17920, 41984) + Vec2(-35840, 0) -- Coordinates for a "New Game" without mods or anything.
	end,

	-- +1 parallel world: The parallel world with 3 parts: sky, normal and hell.
	["1x3 +1"] = function()
		local width, height = BiomeMapGetSize()
		local topLeft, bottomRight = getBaseArea()
		return topLeft + Vec2(width, -height)*CHUNK_SIZE, bottomRight + Vec2(width, height)*CHUNK_SIZE
		--return Vec2(-17920, -31744) + Vec2(35840, 0), Vec2(17920, 41984) + Vec2(35840, 0) -- Coordinates for a "New Game" without mods or anything.
	end,

	-- Extended: Main world + a fraction of the parallel worlds to the left and right.
	["1.5x3"] = function()
		local width, height = BiomeMapGetSize()
		local topLeft, bottomRight = getBaseArea()
		return topLeft + Vec2(-math.floor(0.25*width), -height)*CHUNK_SIZE, bottomRight + Vec2(math.floor(0.25*width), height)*CHUNK_SIZE
		--return Vec2(-25600, -31744), Vec2(25600, 41984) -- Coordinates for a "New Game" without mods or anything. These coordinates may not exactly be 1.5 of the base width for historic reasons.
	end,

	-- Extended: Main world + each parallel world to the left and right.
	["3x3"] = function()
		local width, height = BiomeMapGetSize()
		local topLeft, bottomRight = getBaseArea()
		return topLeft + Vec2(-width, -height)*CHUNK_SIZE, bottomRight + Vec2(width, height)*CHUNK_SIZE
		--return Vec2(-53760, -31744), Vec2(53760, 41984) -- Coordinates for a "New Game" without mods or anything.
	end,
}
