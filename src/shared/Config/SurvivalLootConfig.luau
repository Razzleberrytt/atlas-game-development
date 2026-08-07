--!strict

local Config = {
	Version = "SURVIVAL-LOOT-v2-reward-loop",
	InventoryCapacity = 30,
	ChestCount = 14,
	ChestInteractionDistanceStuds = 10,
	WoodBundleCount = 16,
	WoodPerBundleMinimum = 2,
	WoodPerBundleMaximum = 4,
	AmmoRoundsMinimum = 4,
	AmmoRoundsMaximum = 10,
	-- Every chest contains useful supplies. This chance is only for the exciting
	-- weapon bonus, with a pity guarantee so exploration cannot remain unrewarded.
	ChestWeaponChancePercent = 22,
	GuaranteedWeaponByOpenedChest = 3,
	ChestWoodMinimum = 2,
	ChestWoodMaximum = 4,
	Campfire = table.freeze({
		StartingFuel = 45,
		MaximumFuel = 100,
		FuelPerWood = 12,
		BurnIntervalSeconds = 10,
		SafeLightRangeStuds = 54,
		StableFuelThreshold = 75,
		StableFuelAmmoReward = 8,
		MaximumFuelAmmoReward = 14,
	}),
	DiscoverableWeaponIds = table.freeze({
		"weapon.breach-shotgun",
		"weapon.submachine-gun",
		"weapon.light-machine-gun",
		"weapon.sniper-rifle",
	}),
}

assert(Config.InventoryCapacity >= 24, "survival inventory must be generous by default")
assert(Config.ChestWeaponChancePercent >= 15, "weapon bonuses must be realistically discoverable")
assert(Config.GuaranteedWeaponByOpenedChest <= 4, "early exploration must guarantee a weapon opportunity")

return table.freeze(Config)
