-- Copyright (c) 2022 David Vogel
-- 
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Allows Noita mods to reload themselves every now and then.
-- This helps dramatically with development, as we don't have to restart Noita for every change.

local LiveReload = {}

---Reloads the mod's init file in the given interval in frames.
---For reloading to work correctly, the mod has to be structured in a special way.
---Like the usage of require, namespaces, correct error handling, ...
---
---Just put this into your `OnWorldPreUpdate` or `OnWorldPostUpdate` callback:
---
---	LiveReload:Reload("mods/your-mod/", 60) -- The trailing path separator is needed!
---@param modPath string
---@param interval integer
function LiveReload:Reload(modPath, interval)
	interval = interval or 60
	self.Counter = (self.Counter or 0) + 1
	if self.Counter < interval then return end
	self.Counter = nil

	dofile(modPath .. "init.lua")
end

return LiveReload
