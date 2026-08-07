--!strict

--[[
	VS-0107 bounded first-slice equipment pool and source-specific reward rules.
	Power is intentionally narrow. Boss rewards improve odds and floor rather than
	introducing an unbounded tier jump that would make elite rewards irrelevant.
]]

local CombatContracts = require(script.Parent.Parent.Combat.CombatContracts)
local Contracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)
local SlotIds = Contracts.SlotIds
local RarityIds = Contracts.RarityIds
local SourceIds = Contracts.SourceIds
local WeaponIds = CombatContracts.WeaponIds

--[[
	`WeaponId` is the authored link from an equipment definition to the combat
	weapon it drives when equipped. It lives on the definition rather than in a
	handoff service so that adding an item cannot silently produce something that
	equips but changes nothing. Armor and relic slots carry no weapon.
]]
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
	Version = "VS-0107-v1",
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
			{ "armor", "survival" }
		),
		item(
			"keeper-sigil",
			"Keeper Sigil",
			SlotIds.Relic,
			10,
			15,
			{ RarityIds.Uncommon, RarityIds.Rare },
			{ "relic", "ability" }
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
for _, definition in EquipmentRewardConfig.Definitions do
	assert(ids[definition.Id] == nil, "equipment definition IDs must be unique")
	ids[definition.Id] = true
	assert(
		definition.MinimumPower >= 1 and definition.MaximumPower >= definition.MinimumPower,
		"invalid equipment power bounds"
	)
	assert(#definition.AllowedRarities >= 1, "equipment requires at least one rarity")

	-- A weapon slot that drives no weapon would equip and change nothing, and a
	-- weapon on armor would have no runtime meaning. Both are authoring errors.
	local drivesWeapon = definition.Slot == SlotIds.Primary or definition.Slot == SlotIds.Secondary
	if drivesWeapon then
		assert(type(definition.WeaponId) == "string", definition.Id .. " must name the weapon it equips")
	else
		assert(definition.WeaponId == nil, definition.Id .. " occupies a non-weapon slot and must name no weapon")
	end
end

-- Every authored weapon link must resolve to a real combat weapon id.
local knownWeaponIds = {}
for _, weaponId in WeaponIds do
	knownWeaponIds[weaponId] = true
end
for _, definition in EquipmentRewardConfig.Definitions do
	if definition.WeaponId ~= nil then
		assert(knownWeaponIds[definition.WeaponId] == true, definition.Id .. " names an unknown weapon")
	end
end

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
