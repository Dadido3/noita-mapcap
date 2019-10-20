-- Copyright (c) 2019 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

function splitStringByLength(string, length)
	local chunks = {}
	for i = 1, #string, length do
		table.insert(chunks, string:sub(i, i + length - 1))
	end
	return chunks
end

-- Improved version of GamePrint, that behaves more like print.
function IngamePrint(...)
	local arg = {...}

	local result = ""

	for i, v in ipairs(arg) do
		result = result .. tostring(v) .. "    "
	end

	for line in result:gmatch("[^\r\n]+") do
		for i, v in ipairs(splitStringByLength(line, 100)) do
			GamePrint(v)
		end
	end
end

-- Globally overwrite print function and write output into a logfile
local logFile = io.open("lualog.txt", "w")
function print(...)
	local arg = {...}

	local result = ""
	for i, v in ipairs(arg) do
		result = result .. tostring(v) .. "\t"
	end
	result = result .. "\n"

	logFile:write(result)
	logFile:flush()
end
