-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local ffi = require("ffi")

local MonitorStandby = {}

ffi.cdef([[
	int SetThreadExecutionState(int esFlags);
]])

-- Reset computer and monitor standby timer.
function MonitorStandby.ResetTimer()
	ffi.C.SetThreadExecutionState(3) -- ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
end

return MonitorStandby
