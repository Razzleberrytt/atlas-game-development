--!strict

local Config = {
	Version = "SURVIVAL-LOOT-v3-melee-opening-recovery",
	InventoryCapacity = 30,
	ChestCount = 14,
	ChestInteractionDistanceStuds = 10,
	WoodBundleCount = 16,
	WoodPerBundleMinimum = 2,
	WoodPerBundleMaximum = 4,
	AmmoRoundsMinimum = 4,
	AmmoRoundsMaximum = 10,
	-- A fresh melee operative recovers the humble Service Pistol from their first
	-- personally opened chest. This is the canonical stable weapon ID; runtime
	-- ownership still resolves it through FirearmConfig before equipping. Stronger
	-- firearms remain in the separate upgrade pool below.
	OpeningRecoveryWeaponId = "weapon.service-pistol",
	OpeningRecoveryByOpenedChest = 1,
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
assert(Config.OpeningRecoveryWeaponId == "weapon.service-pistol", "opening recovery ID must remain the humble sidearm")
assert(Config.OpeningRecoveryByOpenedChest == 1, "the melee opening must not depend on random firearm luck")
assert(Config.ChestWeaponChancePercent >= 15, "weapon bonuses must be realistically discoverable")
assert(Config.GuaranteedWeaponByOpenedChest <= 4, "early exploration must guarantee a weapon opportunity")
for _, weaponId in Config.DiscoverableWeaponIds do
	assert(
		weaponId ~= Config.OpeningRecoveryWeaponId,
		"opening pistol must remain separate from stronger weapon upgrades"
	)
end

return table.freeze(Config)
