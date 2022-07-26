-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Some code to make Noita's lua conform more to standard lua.

-- TODO: Make Noita-API module to work with several mods using it

-- Stupid way to prevent this code from being called more than once per sandbox.
-- Calling this lua file with dofile_once would still cause the setup function to be called multiple times.
if _NoitaAPICompatibilityWrapperGuard_ then return function(dummy) end end
_NoitaAPICompatibilityWrapperGuard_ = true

-- Override print function to behave more like the standard lua one.
local oldPrint = print
function print(...)
	local arg = { ... }
	local stringArgs = {}

	for i, v in ipairs(arg) do
		table.insert(stringArgs, tostring(v))
	end

	oldPrint(unpack(stringArgs))
end

-- Package doesn't exist when the Lua API is restricted.
-- Therefore we create it here and apply some default values.
package = package or {}
package.path = package.path or "./?.lua;" -- Allow paths relative to the working directory.
package.preload = package.preload or {}
package.loaded = package.loaded or {
	_G = _G,
	bit = bit,
	coroutine = coroutine,
	debug = debug,
	math = math,
	package = package,
	string = string,
	table = table,
	--io = io,
	--jit = jit,
	--os = os,
}

local oldRequire = require

local recursionSet = {}
local recursionLast

---Emulated require function in case the Lua API is restricted.
---It's probably good enough for most usecases.
---
---We need to override the default require in any case, as only dofile can access stuff in the virtual filesystem.
---@param modName string
---@return any
function require(modName)
	-- Check if package was already loaded, return previous result.
	if package.loaded[modName] ~= nil then return package.loaded[modName] end

	if recursionSet[modName] then
		error(string.format("Cyclic dependency with module %q called by %q", modName, recursionLast))
	end
	recursionSet[modName], recursionLast = true, modName

	local notFoundStr = ""

	-- Check if there is an entry in the preload table.
	local preloadFunc = package.preload[modName]
	if preloadFunc then
		local res = preloadFunc(modName)

		if res == nil then res = true end
		package.loaded[modName] = res
		recursionSet[modName], recursionLast = nil, nil
		return res
	else
		notFoundStr = notFoundStr .. string.format("\tno field package.preload['%s']\n", modName)
	end

	-- Load and execute scripts.
	-- Iterate over all package.path entries.
	for pathEntry in string.gmatch(package.path, "[^;]+") do
		local modPath = string.gsub(modName, "%.", "/") -- Replace "." with file path delimiter.
		local filePath = string.gsub(pathEntry, "?", modPath, 1) -- Insert modPath into "?" placeholder.
		local fixedPath = string.gsub(filePath, "^%.[\\/]", "") -- Need to remove "./" or ".\" at the beginning, as Noita allows only "data" and "mods".
		if fixedPath:sub(1, 4) == "data" or fixedPath:sub(1, 4) == "mods" then -- Ignore everything other than data and mod root path elements. It's not perfect, but this is just there to prevent console spam.
			local res, err = dofile(fixedPath)
			if err then
				notFoundStr = notFoundStr .. string.format("\tno file '%s'\n", filePath)
			else
				if res == nil then res = true end
				package.loaded[modName] = res
				recursionSet[modName], recursionLast = nil, nil
				return res
			end
		else
			notFoundStr = notFoundStr .. string.format("\tnot allowed '%s'\n", filePath)
		end
	end

	-- Fall back to the original require, if it exists.
	if oldRequire then
		local ok, res = pcall(oldRequire, modName)
		if ok then
			recursionSet[modName], recursionLast = nil, nil
			return res
		else
			notFoundStr = notFoundStr .. string.format("\toriginal require:%s", res)
		end
	end

	recursionSet[modName], recursionLast = nil, nil
	error(string.format("module %q not found:\n%s", modName, notFoundStr))
end

---Set up some stuff so `require` works as expected.
---@param libPath any -- Path to the libraries directory of this mod.
local function setup(libPath)
	-- Add the files folder of the given mod as base for any `require` lookups.
	package.path = package.path .. "./" .. libPath .. "?.lua;"
	package.path = package.path .. "./" .. libPath .. "?/init.lua;"

	-- Add the library directory of Noita itself.
	package.path = package.path .. "./data/scripts/lib/?.lua;"
end

return setup
