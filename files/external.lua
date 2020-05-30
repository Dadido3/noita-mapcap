-- Copyright (c) 2019-2020 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local ffi = ffi or _G.ffi or require("ffi")

local status, caplib = pcall(ffi.load, "mods/noita-mapcap/bin/capture-b/capture")
if not status then
	print("Error loading capture lib: " .. cap)
end
ffi.cdef [[
	typedef long LONG;
	typedef struct {
		LONG left;
		LONG top;
		LONG right;
		LONG bottom;
	} RECT;

	bool GetRect(RECT* rect);
	bool Capture(int x, int y);

	int SetThreadExecutionState(int esFlags);
]]

function TriggerCapture(x, y)
	return caplib.Capture(x, y)
end

-- Get the client rectangle of the "Main" window of this process in screen coordinates
function GetRect()
	local rect = ffi.new("RECT", 0, 0, 0, 0)
	if not caplib.GetRect(rect) then
		return nil
	end

	return rect
end

-- Reset computer and monitor standby timer
function ResetStandbyTimer()
	ffi.C.SetThreadExecutionState(3) -- ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
end
