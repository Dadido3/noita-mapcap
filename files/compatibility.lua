-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- Some code to make noita's lua more conform to standard lua

-- Globally overwrite print function to behave more like expected
local oldPrint = print
function print(...)
	local arg = {...}

	stringArgs = {}

	for i, v in ipairs(arg) do
		table.insert(stringArgs, tostring(v))
	end

	oldPrint(unpack(stringArgs))
end

-- Overwrite print to copy its output into a file
--[[local logFile = io.open("lualog.txt", "w")
function print(...)
	local arg = {...}

	stringArgs = {}

	local result = ""
	for i, v in ipairs(arg) do
		table.insert(stringArgs, tostring(v))
		result = result .. tostring(v) .. "\t"
	end
	result = result .. "\n"
	logFile:write(result)
	logFile:flush()

	oldPrint(unpack(stringArgs))
end]]
