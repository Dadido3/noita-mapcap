-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local Vec2 = require("noita-api.vec2")

Config.ComponentsToDisable = {
	"AnimalAIComponent",
	"SimplePhysicsComponent",
	"CharacterPlatformingComponent",
	"WormComponent",
	"WormAIComponent",
	"CameraBoundComponent", -- Disabling this component will prevent entites from being killed/reset when they go offscreen. If they are reset, all tags will be reset and we may capture these entities multiple times. This has some side effects, like longleg.xml and zombie_weak.xml will respawn every revisit, as the spawner doesn't get deleted.
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

Config.CaptureArea = {
	-- Base layout: Every part outside this is based on a similar layout, but uses different materials/seeds.
	["1x1"] = {
		TopLeft = Vec2(-17920, -7168), -- in world coordinates.
		BottomRight = Vec2(17920, 17408), -- in world coordinates. This pixel is not included in the rectangle.
	},

	-- Main world: The main world with 3 parts: sky, normal and hell.
	["1x3"] = {
		TopLeft = Vec2(-17920, -31744), -- in world coordinates.
		BottomRight = Vec2(17920, 41984), -- in world coordinates. This pixel is not included in the rectangle.
	},

	-- Extended: Main world + a fraction of the parallel worlds to the left and right.
	["1.5x3"] = {
		TopLeft = Vec2(-25600, -31744), -- in world coordinates.
		BottomRight = Vec2(25600, 41984), -- in world coordinates. This pixel is not included in the rectangle.
	},
}
