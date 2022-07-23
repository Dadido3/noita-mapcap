-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Noita modding API, but a bit more beautiful.
-- Current modding API version: 7

-- State: Working but incomplete. If something is missing, add it by hand!
-- It would be optimal to generate this API wrapper automatically...

---@type JSONLib
local JSON = dofile_once("mods/noita-mapcap/files/libraries/json.lua")

-------------
-- Classes --
-------------

---@class NoitaComponentAPI
local ComponentAPI = {}

---@class NoitaComponent
---@field ID integer -- Noita component ID.
local NoitaComponent = {}
NoitaComponent.__index = NoitaComponent
ComponentAPI.MetaTable = NoitaComponent

---WrapID wraps the given component ID and returns a Noita component object.
---@param id number
---@return NoitaComponent|nil
function ComponentAPI.WrapID(id)
	if id == nil or type(id) ~= "number" then return nil end
	return setmetatable({ ID = id }, NoitaComponent)
end

------------------------
-- Noita API wrappers --
------------------------

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

---
---@return string string
function NoitaComponent:GetTypeName()
	return ComponentGetTypeName(self.ID)
end

-------------------------
-- JSON Implementation --
-------------------------

---Returns a new table with all arguments stored into keys `1`, `2`, etc. and with a field `"n"` with the total number of arguments.
---@param ... any
---@return table
local function pack(...)
	t = {...}
	t.n = select("#", ...)

	return t
end

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
				local packedResult = pack(self:GetValue(k)) -- Try to get value with correct type. Assuming nil is an error, but this is not always the case... meh.
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

	return JSON.Marshal(resultObject)
end

return ComponentAPI
