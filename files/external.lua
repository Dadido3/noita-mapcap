-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local ffi = ffi or _G.ffi or require("ffi")

local status, caplib = pcall(ffi.load, "mods/noita-mapcap/bin/capture-b/capture")
if not status then
	print("Error loading capture lib: " .. cap)
end
ffi.cdef [[
	void Capture(int x, int y);
]]

function TriggerCapture(x, y)
	caplib.Capture(x, y)
end
