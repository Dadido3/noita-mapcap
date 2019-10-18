function OnModPreInit()
	-- print("Mod - OnModPreInit()") -- first this is called for all mods
end

function OnModInit()
	-- print("Mod - OnModInit()") -- after that this is called for all mods
end

function OnModPostInit()
	-- print("Mod - OnModPostInit()") -- then this is called for all mods
end

function OnPlayerSpawned(player_entity)
end

-- this code runs when all mods' filesystems are registered
ModLuaFileAppend("data/scripts/director_init.lua", "mods/noita-mapcap/files/capture.lua")
ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic_numbers.xml") -- override some game constants
