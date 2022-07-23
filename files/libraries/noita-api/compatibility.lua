-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Some code to make Noita's lua conform more to standard lua.

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
package.path = package.path or "./?.lua;"
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

for k, v in pairs(package.loaded) do
	print(k, v)
end

---Emulated require function in case the Lua API is restricted.
---It's probably good enough for most usecases.
---@param modName string
---@return any
local function customRequire(modName)
	-- Check if package was already loaded, return previous result.
	if package.loaded[modName] then return package.loaded[modName] end

	local notFoundStr = ""

	-- Check if there is an entry in the preload table.
	local preloadFunc = package.preload[modName]
	if preloadFunc then
		local res = preloadFunc(modName)

		if res == nil then res = true end
		package.loaded[modName] = res
		return res
	else
		notFoundStr = notFoundStr .. string.format("\tno field package.preload[%q]\n", modName)
	end

	-- Load and execute scripts.
	-- Iterate over all package.path entries.
	for pathEntry in string.gmatch(package.path, "[^;]+") do
		local modPath = string.gsub(modName, "%.", "/") -- Replace "." with file path delimiter.
		local filePath = string.gsub(pathEntry, "?", modPath, 1) -- Insert modPath into "?" placeholder.
		local fixedPath = string.gsub(filePath, "^%.[\\/]", "") -- Need to remove "./" or ".\" at the beginning, as Noita allows only "data" and "mods".
		if fixedPath:sub(1, 4) == "data" or fixedPath:sub(1, 4) == "mods" then -- Ignore everything other than data and mod root path elements. It's not perfect, but this is just there to prevent console spam.
			local res, err = dofile(fixedPath)
			if res == nil then
				notFoundStr = notFoundStr .. string.format("\tno file %q\n", filePath)
			else
				if res == nil then res = true end
				package.loaded[modName] = res
				return res
			end
		else
			notFoundStr = notFoundStr .. string.format("\tnot allowed %q\n", filePath)
		end
	end

	error(string.format("module %q not found:\n%s", modName, notFoundStr))
end

require = require or customRequire

---Set up some stuff so `require` works as expected.
---@param modName any
local function setup(modName)
	-- Add the files folder of the given mod as base for any `require` lookups.
	package.path = package.path .. "./mods/" .. modName .. "/files/?.lua;"
	--package.path = package.path .. "./mods/" .. modName .. "/files/?/init.lua;"
end

return setup
