--!strict

--[[
	Bounded durable equipment pool and source-specific reward rules.
	Patch 0.9 expands proven weapon, armor, and relic identities while keeping
	power bands narrow and routing all combat consequences through existing owners.
]]

local CombatContracts = require(script.Parent.Parent.Combat.CombatContracts)
local Contracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)
local FirearmConfig = require(script.Parent.FirearmConfig)
local SlotIds = Contracts.SlotIds
local RarityIds = Contracts.RarityIds
local SourceIds = Contracts.SourceIds
local WeaponIds = CombatContracts.WeaponIds

local function item(
	id: string,
	displayName: string,
	slot: string,
	minimumPower: number,
	maximumPower: number,
	rarities,
	tags,
	weaponId: string?
)
	return table.freeze({
		Id = id,
		Version = "1.0.0",
		DisplayName = displayName,
		Slot = slot,
		MinimumPower = minimumPower,
		MaximumPower = maximumPower,
		AllowedRarities = table.freeze(rarities),
		Tags = table.freeze(tags),
		WeaponId = weaponId,
	})
end

local EquipmentRewardConfig = {
	Version = "PATCH-0.9-v3-gear-archetypes",
	Definitions = table.freeze({
		item(
			"frontier-rifle",
			"Frontier Rifle",
			SlotIds.Primary,
			8,
			14,
			{ RarityIds.Common, RarityIds.Uncommon, RarityIds.Rare },
			{ "rifle", "precision" },
			WeaponIds.SniperRifle
		),
		item(
			"breach-shotgun",
			"Breach Shotgun",
			SlotIds.Primary,
			8,
			14,
			{ RarityIds.Common, RarityIds.Uncommon, RarityIds.Rare },
			{ "shotgun", "close-range" },
			WeaponIds.BreachShotgun
		),
		item(
			"blackwater-support-lmg",
			"Blackwater Support LMG",
			SlotIds.Primary,
			8,
			14,
			{ RarityIds.Common, RarityIds.Uncommon, RarityIds.Rare },
			{ "lmg", "sustained-fire", "support" },
			WeaponIds.LightMachineGun
		),
		item(
			"razor-compact-smg",
			"Razor Compact SMG",
			SlotIds.Primary,
			8,
			14,
			{ RarityIds.Common, RarityIds.Uncommon, RarityIds.Rare },
			{ "smg", "close-range", "horde-control" },
			WeaponIds.SubmachineGun
		),
		item(
			"warden-sidearm",
			"Warden Sidearm",
			SlotIds.Secondary,
			7,
			12,
			{ RarityIds.Common, RarityIds.Uncommon },
			{ "sidearm", "reliable" },
			WeaponIds.ServicePistol
		),
		item(
			"delver-plate",
			"Delver Plate",
			SlotIds.Armor,
			8,
			14,
			{ RarityIds.Common, RarityIds.Uncommon, RarityIds.Rare },
			{ "armor", "survival" },
			nil
		),
		item(
			"scout-harness",
			"Scout Harness",
			SlotIds.Armor,
			7,
			13,
			{ RarityIds.Common, RarityIds.Uncommon, RarityIds.Rare },
			{ "armor", "mobility" },
			nil
		),
		item(
			"keeper-sigil",
			"Keeper Sigil",
			SlotIds.Relic,
			10,
			15,
			{ RarityIds.Uncommon, RarityIds.Rare },
			{ "relic", "ability" },
			nil
		),
		item(
			"storm-catalyst",
			"Storm Catalyst",
			SlotIds.Relic,
			9,
			15,
			{ RarityIds.Uncommon, RarityIds.Rare },
			{ "relic", "ability", "offense" },
			nil
		),
	}),
	Sources = table.freeze({
		[SourceIds.Elite] = table.freeze({
			MinimumPower = 8,
			MaximumPower = 12,
			RarityWeights = table.freeze({
				[RarityIds.Common] = 65,
				[RarityIds.Uncommon] = 30,
				[RarityIds.Rare] = 5,
			}),
		}),
		[SourceIds.Boss] = table.freeze({
			MinimumPower = 10,
			MaximumPower = 15,
			RarityWeights = table.freeze({
				[RarityIds.Common] = 25,
				[RarityIds.Uncommon] = 55,
				[RarityIds.Rare] = 20,
			}),
		}),
	}),
}

local ids = {}
local rewardWeaponIds = {}
for _, definition in EquipmentRewardConfig.Definitions do
	assert(ids[definition.Id] == nil, "equipment definition IDs must be unique")
	ids[definition.Id] = true
	assert(
		definition.MinimumPower >= 1 and definition.MaximumPower >= definition.MinimumPower,
		"invalid equipment power bounds"
	)
	assert(#definition.AllowedRarities >= 1, "equipment requires at least one rarity")
	assert(#definition.Tags >= 1, definition.Id .. " requires at least one authoring tag")

	local drivesWeapon = definition.Slot == SlotIds.Primary or definition.Slot == SlotIds.Secondary
	if drivesWeapon then
		assert(type(definition.WeaponId) == "string", definition.Id .. " must name the weapon it equips")
		assert(
			FirearmConfig.isKnownWeaponId(definition.WeaponId),
			definition.Id .. " names an unknown firearm definition"
		)
		rewardWeaponIds[definition.WeaponId] = true
	else
		assert(definition.WeaponId == nil, definition.Id .. " occupies a non-weapon slot and must name no weapon")
	end
end

for _, weaponId in FirearmConfig.DiscoverableWeaponIds do
	assert(rewardWeaponIds[weaponId] == true, "discoverable firearm lacks durable reward representation: " .. weaponId)
end
assert(
	rewardWeaponIds[FirearmConfig.ServicePistol.WeaponId] == true,
	"opening pistol needs a durable sidearm representation"
)

for sourceId, source in EquipmentRewardConfig.Sources do
	assert(source.MinimumPower >= 1 and source.MaximumPower >= source.MinimumPower, "invalid source power bounds")
	local total = 0
	for _, weight in source.RarityWeights do
		assert(
			type(weight) == "number" and weight >= 0 and weight % 1 == 0,
			"rarity weights must be nonnegative integers"
		)
		total += weight
	end
	assert(total == 100, sourceId .. " rarity weights must total 100")
end

return table.freeze(EquipmentRewardConfig)
