table.insert( actions,
{
	id          = "SEA_OF_SWAMP",
	name 		= "Sea of swamp",
	description = "How useful",
	sprite 		= "mods/example/files/actions/sea_swamp.png",
	type 		= ACTION_TYPE_MATERIAL,
	spawn_level                       = "0,4,5,6", -- BERSERK_FIELD
	spawn_probability                 = "1,1,1,1", -- BERSERK_FIELD
	price = 350,
	mana = 140,
	max_uses = 3,
	action 		= function()
		add_projectile("mods/example/files/actions/sea_swamp.xml")
		c.fire_rate_wait = c.fire_rate_wait + 15
	end,
} )