function OnModPreInit()
	print("Mod - OnModPreInit()") -- first this is called for all mods
end

function OnModInit()
	print("Mod - OnModInit()") -- after that this is called for all mods
end

function OnModPostInit()
	print("Mod - OnModPostInit()") -- then this is called for all mods
end

function OnPlayerSpawned( player_entity ) -- this 
	GamePrint( "Mods says: Player entity id: " .. tostring(player_entity) )
end


-- this code runs when all mods' filesystems are registered
ModLuaFileAppend( "data/scripts/gun/gun_actions.lua", "mods/example/files/actions.lua" ) -- basically dofile("mods/example/files/actions.lua") will appear at the end of gun_actions.lua
ModMagicNumbersFileAdd( "mods/example/files/magic_numbers.xml" ) -- will override some magic numbers using the specified file
print("Example mod init done")
