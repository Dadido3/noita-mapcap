-- Copyright (c) 2019-2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

local Utils = {}

---Returns if the file at filePath exists.
---@param filePath string
---@return boolean
function Utils.FileExists(filePath)
	local f = io.open(filePath, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

function Utils.NoitaSpecialDirectory()
	-- TODO: Implement NoitaSpecialDirectory function
end

return Utils
