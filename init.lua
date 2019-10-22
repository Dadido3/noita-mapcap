dofile("mods/noita-mapcap/files/init.lua")

function OnPlayerSpawned(player_entity)
	--EntityLoad("mods/noita-mapcap/files/luacomponent.xml") -- ffi isn't accessible from inside lua components, scrap that idea
	modGUI = GuiCreate()
end

function OnWorldPostUpdate() -- this is called every time the game has finished updating the world
	wake_up_waiting_threads(1) -- Coroutines aren't run every frame in this sandbox, do it manually here.
end

ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic_numbers.xml") -- override some game constants

-- Only works up to the 16-10-2019 version of noita. And even then, ffi and other nice stuff is only accessible here.
--ModLuaFileAppend("data/scripts/director_init.lua", "mods/noita-mapcap/files/init.lua")
