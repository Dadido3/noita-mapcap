-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

--local host, port = "127.0.0.1", "46789"
--local socket = require("socket")
--local tcp = assert(socket.tcp())

--package.path = package.path .. ";" .. "mods/noita-mapcap/libs/lua/" .. "?.lua"
--package.cpath = package.cpath .. ";" .. "mods/noita-mapcap/libs/" .. "?.dll" -- TODO: Make it OS aware

local ffi = ffi or _G.ffi or require("ffi")

-- Don't let lua garbage collect and unload the lib, it will cause crashes later on!
-- Blah, this causes random crashes anyways. Probably the go runtime that interferes with something else in noita.
local status, caplib = pcall(ffi.load, "mods/noita-mapcap/bin/capture-b/capture")
if not status then
	print("Error loading capture lib: " .. cap)
end
ffi.cdef [[
	void Capture(int x, int y);
]]

function TriggerCapture(x, y)
	--IngamePrint(os.execute(string.format("mods/noita-mapcap/bin/capture/capture.exe -x %i -y %i", x, y)))
	--IngamePrint("a", os.execute("capture.exe"))
	--os.execute("screenshots")
	--IngamePrint("b", os.execute("../bin/capture/capture.exe"))
	--local handle = io.popen("mods/noita-mapcap/bin/capture/capture.exe")
	--local result = handle:read("*a")
	--IngamePrint(result)
	--handle:close()
	--IngamePrint(os.execute("echo test"))

	--print("trace", "A")

	caplib.Capture(x, y)

	--print("trace", "B")
end

--[[function TriggerCapture(x, y)
	local status, lib = pcall(require, "socket")
	if not status then
		IngamePrint("Error loading socket lib: " .. lib)
	end

	IngamePrint("DEBUG - Capture")
	tcp:connect(host, port)
	IngamePrint("DEBUG - Connected")

	tcp:send(string.format("x: %i\n", x))
	tcp:send(string.format("y: %i\n", y))
	tcp:send(string.format("\n", y))

	IngamePrint("DEBUG - Sent")

	local result, error = tcp:receive("*l")
	-- Ignore error or result for now, the function blocks until a newline character is received.

	IngamePrint("DEBUG - Received")

	tcp:close()

	IngamePrint("DEBUG - Closed")
end]]
