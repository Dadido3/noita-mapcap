dofile("mods/noita-mapcap/files/init.lua")

function OnPlayerSpawned(player_entity)
	--EntityLoad("mods/noita-mapcap/files/luacomponent.xml") -- ffi isn't accessible from inside lua components, scrap that idea
	modGUI = GuiCreate()
	GameSetCameraFree(true)
end

function OnWorldPostUpdate() -- this is called every time the game has finished updating the world
	wake_up_waiting_threads(1) -- Coroutines aren't run every frame in this sandbox, do it manually here.
end

ModMagicNumbersFileAdd("mods/noita-mapcap/files/magic_numbers.xml") -- override some game constants
