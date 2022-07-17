-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Simple library to marshal JSON values.

---@type NoitaAPI
local noitaAPI = dofile_once("mods/noita-mapcap/files/noita-api.lua")

---@class JSONLib
local lib = {}

---Maps single characters to escaped strings.
---
---Copyright (c) 2020 rxi
---@see [github.com/rxi/json.lua](https://github.com/rxi/json.lua/blob/master/json.lua)
local escapeCharacters = {
	["\\"] = "\\",
	["\""] = "\"",
	["\b"] = "b",
	["\f"] = "f",
	["\n"] = "n",
	["\r"] = "r",
	["\t"] = "t",
}

---escapeRune returns the escaped string for a given rune.
---
---Copyright (c) 2020 rxi
---@see [github.com/rxi/json.lua](https://github.com/rxi/json.lua/blob/master/json.lua)
---@param rune string
---@return string
local function escapeCharacter(rune)
	return "\\" .. (escapeCharacters[rune] or string.format("u%04x", rune:byte()))
end

---escapeString returns the escaped version of the given string.
---
---Copyright (c) 2020 rxi
---@see [github.com/rxi/json.lua](https://github.com/rxi/json.lua/blob/master/json.lua)
---@param str string
---@return string
local function escapeString(str)
	local result, count = str:gsub('[%z\1-\31\\"]', escapeCharacter)
	return result
end

---MarshalString returns the JSON representation of a string value.
---@param val string
---@return string
function lib.MarshalString(val)
	return string.format("%q", escapeString(val)) -- TODO: Escape strings correctly.
end

---MarshalNumber returns the JSON representation of a number value.
---@param val number
---@return string
function lib.MarshalNumber(val)
	-- TODO: Marshal NaN, +Inf, -Inf, ... correctly

	return tostring(val)
end

---MarshalBoolean returns the JSON representation of a boolean value.
---@param val number
---@return string
function lib.MarshalBoolean(val)
	return tostring(val)
end

---MarshalObject returns the JSON representation of a table object.
---
---This only works with string keys. Number keys will be converted into strings.
---@param val table<string,any>
---@return string
function lib.MarshalObject(val)
	local result = "{"

	for k, v in pairs(val) do
		result = result .. lib.MarshalString(k) .. ": " .. lib.Marshal(v)
		-- Append character depending on whether this is the last element or not.
		if next(val, k) == nil then
			result = result .. "}"
		else
			result = result .. ", "
		end
	end

	return result
end

---MarshalArray returns the JSON representation of an array object.
---
---@param val table<number,any>
---@param customMarshalFunction function|nil -- Custom function for marshalling the array values.
---@return string
function lib.MarshalArray(val, customMarshalFunction)
	local result = "["

	-- TODO: Check if the type of all array entries is the same.

	local length = #val
	for i, v in ipairs(val) do
		if customMarshalFunction then
			result = result .. customMarshalFunction(v)
		else
			result = result .. lib.Marshal(v)
		end
		-- Append character depending on whether this is the last element or not.
		if i == length then
			result = result .. "]"
		else
			result = result .. ", "
		end
	end

	return result
end

---MarshalNoitaComponent returns the JSON representation of the given Noita component.
---@param component NoitaComponent
---@return string
function lib.MarshalNoitaComponent(component)
	local resultObject = {
		typeName = component:GetTypeName(),
		members = component:GetMembers(),
		--objectMembers = component:ObjectGetMembers
	}

	return lib.Marshal(resultObject)
end

---MarshalNoitaEntity returns the JSON representation of the given Noita entity.
---@param entity NoitaEntity
---@return string
function lib.MarshalNoitaEntity(entity)
	local result = {
		name = entity:GetName(),
		filename = entity:GetFilename(),
		tags = entity:GetTags(),
		children = entity:GetAllChildren(),
		components = entity:GetAllComponents(),
		transform = {},
	}

	result.transform.x, result.transform.y, result.transform.rotation, result.transform.scaleX, result.transform.scaleY = entity:GetTransform()

	return lib.Marshal(result)
end

---Marshal marshals any value into JSON representation.
---@param val any
---@return string
function lib.Marshal(val)
	local t = type(val)

	if t == "nil" then
		return "null"
	elseif t == "number" then
		return lib.MarshalNumber(val)
	elseif t == "string" then
		return lib.MarshalString(val)
	elseif t == "boolean" then
		return lib.MarshalBoolean(val)
	elseif t == "table" then
		-- Check if object is instance of class...
		if getmetatable(val) == noitaAPI.MetaTables.Component then
			return lib.MarshalNoitaComponent(val)
		elseif getmetatable(val) == noitaAPI.MetaTables.Entity then
			return lib.MarshalNoitaEntity(val)
		end

		-- If not, fall back to array or object handling.
		local commonKeyType, commonValueType
		for k, v in pairs(val) do
			local keyType, valueType = type(k), type(v)
			commonKeyType = commonKeyType or keyType
			if commonKeyType ~= keyType then
				-- Different types detected, abort.
				commonKeyType = "mixed"
				break
			end
			commonValueType = commonValueType or valueType
			if commonValueType ~= valueType then
				-- Different types detected, abort.
				commonValueType = "mixed"
				break
			end
		end

		-- Decide based on common types.
		if commonKeyType == "number" and commonValueType ~= "mixed" then
			return lib.MarshalArray(val) -- This will falsely detect sparse integer key maps as arrays. But meh.
		elseif commonKeyType == "string" then
			return lib.MarshalObject(val) -- This will not detect if there are number keys, which would work with MarshalObject.
		elseif commonKeyType == nil and commonValueType == nil then
			return "null" -- Fallback in case of empty table. There is no other way than using null, as we don't have type information without table elements.
		end

		error(string.format("unsupported table type. CommonKeyType = %s. CommonValueType = %s. MetaTable = %s", commonKeyType or "nil", commonValueType or "nil", getmetatable(val) or "nil"))
	end

	error(string.format("unsupported type %q", t))
end

return lib
