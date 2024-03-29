-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local ComponentAPI = require("noita-api.component")
local JSON = require("noita-api.json")

-------------
-- Classes --
-------------

local EntityAPI = {}

---@class NoitaEntity
---@field ID integer -- Noita entity ID.
local NoitaEntity = {}
NoitaEntity.__index = NoitaEntity
EntityAPI.MetaTable = NoitaEntity

---Wraps the given entity ID and returns a Noita entity object.
---@param id number|nil
---@return NoitaEntity|nil
function EntityAPI.Wrap(id)
	if id == nil or type(id) ~= "number" then return nil end
	return setmetatable({ ID = id }, NoitaEntity)
end

------------------------
-- Noita API wrappers --
------------------------

---
---@param filename string
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- Y coordinate in world (virtual) pixels.
---@return NoitaEntity|nil
function EntityAPI.Load(filename, posX, posY) -- TODO: Change to use Vec2 object
	return EntityAPI.Wrap(EntityLoad(filename, posX, posY))
end

---
---@param filename string
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- Y coordinate in world (virtual) pixels.
---@return NoitaEntity|nil
function EntityAPI.LoadEndGameItem(filename, posX, posY) -- TODO: Change to use Vec2 object
	return EntityAPI.Wrap(EntityLoadEndGameItem(filename, posX, posY))
end

---
---@param filename string
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- Y coordinate in world (virtual) pixels.
function EntityAPI.LoadCameraBound(filename, posX, posY) -- TODO: Change to use Vec2 object
	return EntityLoadCameraBound(filename, posX, posY)
end

---Creates a new entity from the given XML file, and attaches it to entity.
---This will not load tags and other stuff, it seems.
---@param filename string
---@param entity NoitaEntity
function EntityAPI.LoadToEntity(filename, entity)
	return EntityLoadToEntity(filename, entity.ID)
end

---
---Note: works only in dev builds.
---@param filename string
function NoitaEntity:Save(filename)
	return EntitySave(self.ID, filename)
end

---
---@param name string
---@return NoitaEntity|nil
function EntityAPI.CreateNew(name)
	return EntityAPI.Wrap(EntityCreateNew(name))
end

---
function NoitaEntity:Kill()
	return EntityKill(self.ID)
end

---
function NoitaEntity:IsAlive()
	return EntityGetIsAlive(self.ID)
end

---
---@param componentTypeName string
---@param tableOfComponentValues string[]
---@return NoitaComponent|nil
function NoitaEntity:AddComponent(componentTypeName, tableOfComponentValues)
	local componentID = EntityAddComponent(self.ID, componentTypeName, tableOfComponentValues)
	return ComponentAPI.Wrap(componentID)
end

---
---@param component NoitaComponent
function NoitaEntity:RemoveComponent(component)
	return EntityRemoveComponent(self.ID, component.ID)
end

---Returns a table of with all components of this entity.
---@return NoitaComponent[]
function NoitaEntity:GetAllComponents()
	local componentIDs = EntityGetAllComponents(self.ID) or {}
	local result = {}
	for _, componentID in ipairs(componentIDs) do
		table.insert(result, ComponentAPI.Wrap(componentID))
	end
	return result
end

---Returns a table of components filtered by the given parameters.
---@param componentTypeName string
---@param tag string|nil
---@return NoitaComponent[]
function NoitaEntity:GetComponents(componentTypeName, tag)
	local componentIDs
	if tag ~= nil then
		componentIDs = EntityGetComponent(self.ID, componentTypeName, tag) or {}
	else
		componentIDs = EntityGetComponent(self.ID, componentTypeName) or {}
	end
	local result = {}
	for _, componentID in ipairs(componentIDs) do
		table.insert(result, ComponentAPI.Wrap(componentID))
	end
	return result
end

---Returns the first component of this entity that fits the given parameters.
---@param componentTypeName string
---@param tag string|nil
---@return NoitaComponent|nil
function NoitaEntity:GetFirstComponent(componentTypeName, tag)
	local componentID
	if tag ~= nil then
		componentID = EntityGetFirstComponent(self.ID, componentTypeName, tag)
	else
		componentID = EntityGetFirstComponent(self.ID, componentTypeName)
	end
	return ComponentAPI.Wrap(componentID)
end

---Sets the transform of the entity.
---@param x number
---@param y number
---@param rotation number
---@param scaleX number
---@param scaleY number
function NoitaEntity:SetTransform(x, y, rotation, scaleX, scaleY) -- TODO: Change to use Vec2 object
	return EntitySetTransform(self.ID, x, y, rotation, scaleX, scaleY)
end

---Sets the transform and tries to immediately refresh components that calculate values based on an entity's transform.
---@param x number
---@param y number
---@param rotation number
---@param scaleX number
---@param scaleY number
function NoitaEntity:SetAndApplyTransform(x, y, rotation, scaleX, scaleY) -- TODO: Change to use Vec2 object
	return EntityApplyTransform(self.ID, x, y, rotation, scaleX, scaleY)
end

---Returns the transformation of the entity.
---@return number x, number y, number rotation, number scaleX, number scaleY
function NoitaEntity:GetTransform() -- TODO: Change to use Vec2 object
	return EntityGetTransform(self.ID)
end

---
---@param child NoitaEntity
function NoitaEntity:AddChild(child)
	return EntityAddChild(self.ID, child.ID)
end

---
---@return NoitaEntity[]
function NoitaEntity:GetAllChildren()
	local entityIDs = EntityGetAllChildren(self.ID) or {}
	local result = {}
	for _, entityID in ipairs(entityIDs) do
		table.insert(result, EntityAPI.Wrap(entityID))
	end
	return result
end

---
---@return NoitaEntity|nil
function NoitaEntity:GetParent()
	return EntityAPI.Wrap(EntityGetParent(self.ID))
end

---Returns the given entity if it has no parent, otherwise walks up the parent hierarchy to the topmost parent and returns it.
---@return NoitaEntity|nil
function NoitaEntity:GetRootEntity()
	return EntityAPI.Wrap(EntityGetRootEntity(self.ID))
end

---
function NoitaEntity:RemoveFromParent()
	return EntityRemoveFromParent(self.ID)
end

---
---@param tag string
---@param enabled boolean
function NoitaEntity:SetComponentsWithTagEnabled(tag, enabled)
	return EntitySetComponentsWithTagEnabled(self.ID, tag, enabled)
end

---
---@param component NoitaComponent
---@param enabled boolean
function NoitaEntity:SetComponentsEnabled(component, enabled)
	return EntitySetComponentIsEnabled(self.ID, component.ID, enabled)
end

---
---@return string
function NoitaEntity:GetName()
	return EntityGetName(self.ID)
end

---
---@param name string
function NoitaEntity:SetName(name)
	return EntitySetName(self.ID, name)
end

---Returns an array of all the entity's tags.
---@return string[]
function NoitaEntity:GetTags()
	---@type string
	local tagsString = EntityGetTags(self.ID) or ""
	local result = {}
	for tag in tagsString:gmatch('([^,]+)') do
		table.insert(result, tag)
	end
	return result
end

---Returns all entities with 'tag'.
---@param tag string
---@return NoitaEntity[]
function EntityAPI.GetWithTag(tag)
	local entityIDs = EntityGetWithTag(tag) or {}
	local result = {}
	for _, entityID in ipairs(entityIDs) do
		table.insert(result, EntityAPI.Wrap(entityID))
	end
	return result
end

---Returns all entities in 'radius' distance from 'x','y'.
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- X coordinate in world (virtual) pixels.
---@param radius number -- Radius in world (virtual) pixels.
---@return NoitaEntity[]
function EntityAPI.GetInRadius(posX, posY, radius) -- TODO: Change to use Vec2 object
	local entityIDs = EntityGetInRadius(posX, posY, radius) or {}
	local result = {}
	for _, entityID in ipairs(entityIDs) do
		table.insert(result, EntityAPI.Wrap(entityID))
	end
	return result
end

---Returns all entities in 'radius' distance from 'x','y' that have the given tag.
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- X coordinate in world (virtual) pixels.
---@param radius number -- Radius in world (virtual) pixels.
---@param tag string
---@return NoitaEntity[]
function EntityAPI.GetInRadiusWithTag(posX, posY, radius, tag) -- TODO: Change to use Vec2 object
	local entityIDs = EntityGetInRadiusWithTag(posX, posY, radius, tag) or {}
	local result = {}
	for _, entityID in ipairs(entityIDs) do
		table.insert(result, EntityAPI.Wrap(entityID))
	end
	return result
end

---
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- X coordinate in world (virtual) pixels.
---@return NoitaEntity|nil
function EntityAPI.GetClosest(posX, posY) -- TODO: Change to use Vec2 object
	return EntityAPI.Wrap(EntityGetClosest(posX, posY))
end

---
---@param name string
---@return NoitaEntity|nil
function EntityAPI.GetWithName(name)
	return EntityAPI.Wrap(EntityGetWithName(name))
end

---
---@param tag string
function NoitaEntity:AddTag(tag)
	return EntityAddTag(self.ID, tag)
end

---
---@param tag string
function NoitaEntity:RemoveTag(tag)
	return EntityRemoveTag(self.ID, tag)
end

---
---@param tag string
---@return boolean
function NoitaEntity:HasTag(tag)
	return EntityHasTag(self.ID, tag)
end

---
---@return string -- example: 'data/entities/items/flute.xml'.
function NoitaEntity:GetFilename()
	return EntityGetFilename(self.ID)
end

---Creates a component of type 'component_type_name' and adds it to 'entity_id'.
---'table_of_component_values' should be a string-indexed table, where keys are field names and values are field values of correct type.
---The value setting works like ComponentObjectSetValue2(), with the exception that multi value types are not supported.
---Additional supported values are _tags:comma_separated_string and _enabled:bool, which basically work like the those fields work in entity XML files.
---Returns the created component, if creation succeeded, or nil.
---@param componentTypeName string
---@param tableOfComponentValues table<string, any>
---@return NoitaComponent|nil
function NoitaEntity:EntityAddComponent(componentTypeName, tableOfComponentValues)
	local componentID = EntityAddComponent2(self.ID, componentTypeName, tableOfComponentValues)
	return ComponentAPI.Wrap(componentID)
end

-- TODO: Add missing Noita API methods and functions.

---
---@return NoitaEntity|nil
function EntityAPI.GetUpdatedEntity()
	return EntityAPI.Wrap(GetUpdatedEntityID())
end

---
---@return NoitaEntity|nil
function EntityAPI.GetWorldStateEntity()
	return EntityAPI.Wrap(GameGetWorldStateEntity())
end

---
---@return NoitaEntity|nil
function EntityAPI.GetPlayerStatsEntity()
	return EntityAPI.Wrap(GameGetPlayerStatsEntity())
end

-- TODO: Add missing Noita API methods and functions.

---
function NoitaEntity:RegenItemAction()
	return GameRegenItemAction(self.ID)
end

---
function NoitaEntity:RegenItemActionsInContainer()
	return GameRegenItemActionsInContainer(self.ID)
end

---
function NoitaEntity:RegenItemActionsInPlayer()
	return GameRegenItemActionsInPlayer(self.ID)
end

---
---@param itemEntity NoitaEntity
function NoitaEntity:KillInventoryItem(itemEntity)
	return GameKillInventoryItem(self.ID, itemEntity.ID)
end

---
---@param itemEntity NoitaEntity
---@param doPickUpEffects boolean
function NoitaEntity:PickUpInventoryItem(itemEntity, doPickUpEffects)
	if doPickUpEffects == nil then doPickUpEffects = true end
	return GamePickUpInventoryItem(self.ID, itemEntity.ID, doPickUpEffects)
end

---
function NoitaEntity:DropAllItems()
	return GameDropAllItems(self.ID)
end

---
function NoitaEntity:DropPlayerInventoryItems()
	return GameDropPlayerInventoryItems(self.ID)
end

---
function NoitaEntity:DestroyInventoryItems()
	return GameDestroyInventoryItems(self.ID)
end

-- TODO: Add missing Noita API methods and functions.

---
---@return boolean
function NoitaEntity:IsPlayer()
	return IsPlayer(self.ID)
end

---
---@return boolean
function NoitaEntity:IsInvisible()
	return IsInvisible(self.ID)
end

-- TODO: Add missing Noita API methods and functions.

-------------------------
-- JSON Implementation --
-------------------------

---MarshalJSON implements the JSON marshaler interface.
---@return string
function NoitaEntity:MarshalJSON()
	local result = {
		name = self:GetName(),
		filename = self:GetFilename(),
		tags = self:GetTags(),
		children = self:GetAllChildren(),
		components = self:GetAllComponents(),
		transform = {},
	}

	result.transform.x, result.transform.y, result.transform.rotation, result.transform.scaleX, result.transform.scaleY = self:GetTransform()

	return JSON.Marshal(result)
end

return EntityAPI
