-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Noita modding API, but a bit more beautiful.
-- Current modding API version: 7

-- State: Working but incomplete. If something is missing, add it by hand!
-- It would be optimal to generate this API wrapper automatically...

---@type JSONLib
local json = dofile_once("mods/noita-mapcap/files/json-serialize.lua")

-------------
-- Classes --
-------------

local EntityAPI = {}

---@class NoitaEntity
---@field ID integer -- Noita entity ID.
local NoitaEntity = {}
NoitaEntity.__index = NoitaEntity

---WrapID wraps the given entity ID and returns a Noita entity object.
---@param id number
---@return NoitaEntity|nil
function EntityAPI.WrapID(id)
	if id == nil or type(id) ~= "number" then return nil end
	return setmetatable({ ID = id }, NoitaEntity)
end

local ComponentAPI = {}

---@class NoitaComponent
---@field ID integer -- Noita component ID.
local NoitaComponent = {}
NoitaComponent.__index = NoitaComponent

---WrapID wraps the given component ID and returns a Noita component object.
---@param id number
---@return NoitaComponent|nil
function ComponentAPI.WrapID(id)
	if id == nil or type(id) ~= "number" then return nil end
	return setmetatable({ ID = id }, NoitaComponent)
end

-------------------------
-- JSON Implementation --
-------------------------

-- Set of component keys that would return an "invalid type" error when called with ComponentGetValue2().
-- This is more or less to get around console error spam that otherwise can't be prevented when iterating over component members.
-- Only used inside the JSON marshaler, until there is a better solution.
local componentValueKeysWithInvalidType = {}

---MarshalJSON implements the JSON marshaler interface.
---@return string
function NoitaComponent:MarshalJSON()
	-- Get list of members, but with correct type (instead of string values).
	local membersTable = self:GetMembers()
	local members = {}
	if membersTable then
		for k, v in pairs(membersTable) do
			if not componentValueKeysWithInvalidType[k] then
				local packedResult = table.pack(self:GetValue(k)) -- Try to get value with correct type. Assuming nil is an error, but this is not always the case... meh.
				if packedResult.n == 0 then
					members[k] = nil -- Write no result as nil. Basically do nothing.
				elseif packedResult.n == 1 then
					members[k] = packedResult[1] -- Write single value result as single value.
				else
					packedResult.n = nil -- Discard n field, otherwise this is not a pure array.
					members[k] = packedResult -- Write multi value result as array.
				end
			end
			if members[k] == nil then
				componentValueKeysWithInvalidType[k] = true
				--members[k] = v -- Fall back to string value of self:GetMembers().
			end
		end
	end

	local resultObject = {
		typeName = self:GetTypeName(),
		members = members,
		--objectMembers = component:ObjectGetMembers
	}

	return json.Marshal(resultObject)
end

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

	return json.Marshal(result)
end

------------------------
-- Noita API wrappers --
------------------------

---
---@param filename string
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- Y coordinate in world (virtual) pixels.
---@return NoitaEntity|nil
function EntityAPI.Load(filename, posX, posY)
	local entityID = EntityLoad(filename, posX, posY)
	if entityID == nil then
		return nil
	end
	return setmetatable({ ID = entityID }, NoitaEntity)
end

---
---@param filename string
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- Y coordinate in world (virtual) pixels.
---@return NoitaEntity|nil
function EntityAPI.LoadEndGameItem(filename, posX, posY)
	local entityID = EntityLoadEndGameItem(filename, posX, posY)
	if entityID == nil then
		return nil
	end
	return setmetatable({ ID = entityID }, NoitaEntity)
end

---
---@param filename string
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- Y coordinate in world (virtual) pixels.
function EntityAPI.LoadCameraBound(filename, posX, posY)
	return EntityLoadCameraBound(filename, posX, posY)
end

---
---@param filename string
---@param entity NoitaEntity
function EntityAPI.LoadToEntity(filename, entity)
	return EntityLoadToEntity(filename, entity)
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
	local entityID = EntityCreateNew(name)
	if entityID == nil then
		return nil
	end
	return setmetatable({ ID = entityID }, NoitaEntity)
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
---@param tableOfComponentValues string[]|nil
---@return NoitaComponent|nil
function NoitaEntity:AddComponent(componentTypeName, tableOfComponentValues)
	local componentID = EntityAddComponent(self.ID, componentTypeName, tableOfComponentValues)
	if componentID == nil then
		return nil
	end
	return setmetatable({ ID = componentID }, NoitaComponent)
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
		table.insert(result, setmetatable({ ID = componentID }, NoitaComponent))
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
		table.insert(result, setmetatable({ ID = componentID }, NoitaComponent))
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
	if componentID == nil then
		return nil
	end
	return setmetatable({ ID = componentID }, NoitaComponent)
end

---Sets the transform of the entity.
---@param x number
---@param y number
---@param rotation number
---@param scaleX number
---@param scaleY number
function NoitaEntity:SetTransform(x, y, rotation, scaleX, scaleY)
	return EntitySetTransform(self.ID, x, y, rotation, scaleX, scaleY)
end

---Sets the transform and tries to immediately refresh components that calculate values based on an entity's transform.
---@param x number
---@param y number
---@param rotation number
---@param scaleX number
---@param scaleY number
function NoitaEntity:SetAndApplyTransform(x, y, rotation, scaleX, scaleY)
	return EntityApplyTransform(self.ID, x, y, rotation, scaleX, scaleY)
end

---Returns the transformation of the entity.
---@return number x, number y, number rotation, number scaleX, number scaleY
function NoitaEntity:GetTransform()
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
		table.insert(result, setmetatable({ ID = entityID }, NoitaEntity))
	end
	return result
end

---
---@return NoitaEntity|nil
function NoitaEntity:GetParent()
	local entityID = EntityGetParent(self.ID)
	if entityID == nil then
		return nil
	end
	return setmetatable({ ID = entityID }, NoitaEntity)
end

---Returns the given entity if it has no parent, otherwise walks up the parent hierarchy to the topmost parent and returns it.
---@return NoitaEntity
function NoitaEntity:GetRootEntity()
	local entityID = EntityGetRootEntity(self.ID)
	return setmetatable({ ID = entityID }, NoitaEntity)
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
	local tagsString = EntityGetTags(self.ID)
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
		table.insert(result, setmetatable({ ID = entityID }, NoitaEntity))
	end
	return result
end

---Returns all entities in 'radius' distance from 'x','y'.
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- X coordinate in world (virtual) pixels.
---@param radius number -- Radius in world (virtual) pixels.
---@return NoitaEntity[]
function EntityAPI.GetInRadius(posX, posY, radius)
	local entityIDs = EntityGetInRadius(posX, posY, radius) or {}
	local result = {}
	for _, entityID in ipairs(entityIDs) do
		table.insert(result, setmetatable({ ID = entityID }, NoitaEntity))
	end
	return result
end

---Returns all entities in 'radius' distance from 'x','y' that have the given tag.
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- X coordinate in world (virtual) pixels.
---@param radius number -- Radius in world (virtual) pixels.
---@param tag string
---@return NoitaEntity[]
function EntityAPI.GetInRadiusWithTag(posX, posY, radius, tag)
	local entityIDs = EntityGetInRadiusWithTag(posX, posY, radius, tag) or {}
	local result = {}
	for _, entityID in ipairs(entityIDs) do
		table.insert(result, setmetatable({ ID = entityID }, NoitaEntity))
	end
	return result
end

---
---@param posX number -- X coordinate in world (virtual) pixels.
---@param posY number -- X coordinate in world (virtual) pixels.
---@return NoitaEntity|nil
function EntityAPI.GetClosest(posX, posY)
	local entityID = EntityGetClosest(posX, posY)
	if entityID == nil then
		return nil
	end
	return setmetatable({ ID = entityID }, NoitaEntity)
end

---
---@param name string
---@return NoitaEntity|nil
function EntityAPI.GetWithName(name)
	local entityID = EntityGetWithName(name)
	if entityID == nil then
		return nil
	end
	return setmetatable({ ID = entityID }, NoitaEntity)
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

---
---@param tag string
function NoitaComponent:AddTag(tag)
	return ComponentAddTag(self.ID, tag)
end

---
---@param tag string
function NoitaComponent:RemoveTag(tag)
	return ComponentRemoveTag(self.ID, tag)
end

---
---@param tag string
---@return boolean
function NoitaComponent:HasTag(tag)
	return ComponentHasTag(self.ID, tag)
end

---Returns one or many values matching the type or subtypes of the requested field.
---Reports error and returns nil if the field type is not supported or field was not found.
---@param fieldName string
---@return any|nil
function NoitaComponent:GetValue(fieldName)
	return ComponentGetValue2(self.ID, fieldName) -- TODO: Rework Noita API to handle vectors, and return a vector instead of some shitty multi value result
end

---Sets the value of a field. Value(s) should have a type matching the field type.
---Reports error if the values weren't given in correct type, the field type is not supported, or the component does not exist.
---@param fieldName string
---@param ... any|nil -- Vectors use one argument per dimension.
function NoitaComponent:SetValue(fieldName, ...)
	return ComponentSetValue2(self.ID, fieldName, ...) -- TODO: Rework Noita API to handle vectors, and use a vector instead of shitty multi value arguments
end

---Returns one or many values matching the type or subtypes of the requested field in a component subobject.
---Reports error and returns nil if the field type is not supported or 'object_name' is not a metaobject.
---
---Reporting errors means that it spams the stdout with messages, instead of using the lua error handling. Thanks Nolla.
---@param objectName string
---@param fieldName string
---@return any|nil
function NoitaComponent:ObjectGetValue(objectName, fieldName)
	return ComponentObjectGetValue2(self.ID, objectName, fieldName) -- TODO: Rework Noita API to handle vectors, and return a vector instead of some shitty multi value result
end

---Sets the value of a field in a component subobject. Value(s) should have a type matching the field type.
---Reports error if the values weren't given in correct type, the field type is not supported or 'object_name' is not a metaobject.
---@param objectName string
---@param fieldName string
---@param ... any|nil -- Vectors use one argument per dimension.
function NoitaComponent:ObjectSetValue(objectName, fieldName, ...)
	return ComponentObjectSetValue2(self.ID, objectName, fieldName, ...) -- TODO: Rework Noita API to handle vectors, and use a vector instead of shitty multi value arguments
end

---Creates a component of type 'component_type_name' and adds it to 'entity_id'.
---'table_of_component_values' should be a string-indexed table, where keys are field names and values are field values of correct type.
---The value setting works like ComponentObjectSetValue2(), with the exception that multivalue types are not supported.
---Additional supported values are _tags:comma_separated_string and _enabled:bool, which basically work like the those fields work in entity XML files.
---Returns the created component, if creation succeeded, or nil.
---@param componentTypeName string
---@param tableOfComponentValues table<string, any>
---@return NoitaComponent|nil
function NoitaEntity:EntityAddComponent(componentTypeName, tableOfComponentValues)
	local componentID = EntityAddComponent2(self.ID, componentTypeName, tableOfComponentValues)
	if componentID == nil then
		return nil
	end
	return setmetatable({ ID = componentID }, NoitaComponent)
end

---
---@param arrayMemberName string
---@param typeStoredInVector "int"|"float"|"string"
---@return number
function NoitaComponent:GetVectorSize(arrayMemberName, typeStoredInVector)
	return ComponentGetVectorSize(self.ID, arrayMemberName, typeStoredInVector)
end

---
---@param arrayName string
---@param typeStoredInVector "int"|"float"|"string"
---@param index number
---@return number|number|string|nil
function NoitaComponent:GetVectorValue(arrayName, typeStoredInVector, index)
	return ComponentGetVectorValue(self.ID, arrayName, typeStoredInVector, index)
end

---
---@param arrayName string
---@param typeStoredInVector "int"|"float"|"string"
---@return number[]|number|string|nil
function NoitaComponent:GetVector(arrayName, typeStoredInVector)
	return ComponentGetVector(self.ID, arrayName, typeStoredInVector)
end

---Returns true if the given component exists and is enabled, else false.
---@return boolean
function NoitaComponent:GetIsEnabled()
	return ComponentGetIsEnabled(self.ID)
end

---Returns a string-indexed table of string.
---@return table<string, string>|nil
function NoitaComponent:GetMembers()
	return ComponentGetMembers(self.ID)
end

---Returns a string-indexed table of string or nil.
---@param objectName string
---@return table<string, string>|nil
function NoitaComponent:ObjectGetMembers(objectName)
	return ComponentObjectGetMembers(self.ID, objectName)
end

---@return string string
function NoitaComponent:GetTypeName()
	return ComponentGetTypeName(self.ID)
end

-- TODO: Add missing Noita API methods and functions.

--------------------
-- Noita API root --
--------------------

---@class NoitaAPI
local api = {
	Component = ComponentAPI,
	Entity = EntityAPI,
	MetaTables = {
		Component = NoitaComponent,
		Entity = NoitaEntity,
	},
}

return api
