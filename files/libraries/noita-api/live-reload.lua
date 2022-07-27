-- Copyright (c) 2022 David Vogel
-- 
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Allows Noita mods to reload themselves every now and then.
-- This helps dramatically with development, as we don't have to restart Noita for every change.
-- To accomplish this, we need to override the default behavior of dofile and some other things.

local LiveReload = {}

local oldDofile = dofile
---Overwritten dofile to execute a lua script from disk and cirumvent any caching.
---Noita for some reason caches script files (Or loads them into its virtual filesystem)(Or caches compiled bytecode), so reloading script files from disk does not work without this.
---
---This is not fully conform the the standard lua implementation, but so isn't Noita's implementation.
---@param path string
---@return any result
---@return string|nil err
function dofile(path) ---TODO: Consider moving dofile into compatibility.lua
	local func, err = loadfile(path)
	if not func then return nil, err end

	local status, res = pcall(func)
	if not status then return nil, res end

	return res, nil
end

---Reloads the mod's init file in the given interval in frames.
---For reloading to work correctly, the mod has to be structured in a special way.
---Like the usage of require and namespaces.
---
---Just put this into your `OnWorldPreUpdate` or `OnWorldPostUpdate` callback:
---
---	LiveReload:Reload("mods/your-mod/") -- The trailing path separator is needed!
---@param modPath string
---@param interval integer
function LiveReload:Reload(modPath, interval)
	self.Counter = (self.Counter or 0) + 1
	if self.Counter < interval then return end
	self.Counter = nil

	local res, err = dofile(modPath .. "init.lua")
	if err then
		print(string.format("Error reloading mod: %s", err))
	end
end

return LiveReload
