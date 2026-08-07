--!strict

--[[
	HROI-0106 bounded run-only recovery loot. The newer EnemyLootService remains
	the sole owner of ammunition drops; this companion table adds only occasional
	Field Dressings and Field Intel without duplicating the hard ammo economy.
	Integer percentages keep deterministic death rolls easy to audit and tune.
]]

local LootDropContracts = require(script.Parent.Parent.Loot.LootDropContracts)

local KindIds = LootDropContracts.LootKindIds

local LootDropConfig = {
	Version = "HROI-0106-v2-recovery-only",
	EnemyScanIntervalSeconds = 0.1,
	MaximumTrackedEnemyModels = 64,
	MaximumActiveDrops = 8,
	DropLifetimeSeconds = 18,
	PickupMaximumDistanceStuds = 8,
	PromptHoldDurationSeconds = 0,
	DropRollPercentByKind = table.freeze({
		[KindIds.AmmunitionBundle] = 0,
		[KindIds.FieldDressing] = 5,
		[KindIds.FieldIntel] = 2,
	}),
	NoDropPercent = 93,
	Rewards = table.freeze({
		AmmunitionRounds = 8,
		HealingAmount = 30,
		FieldIntelXp = 40,
	}),
	Presentation = table.freeze({
		FloatHeightStuds = 1.6,
		PartSizeStuds = 1.35,
		BillboardMaxDistanceStuds = 150,
		LightRangeStuds = 11,
	}),
}

assert(
	LootDropConfig.EnemyScanIntervalSeconds >= 0.05 and LootDropConfig.EnemyScanIntervalSeconds <= 0.5,
	"recovery loot death observation must remain responsive and bounded"
)
assert(
	LootDropConfig.MaximumTrackedEnemyModels >= 24 and LootDropConfig.MaximumTrackedEnemyModels <= 64,
	"recovery loot death observation must cover living enemies and bounded corpse overlap"
)
assert(
	LootDropConfig.MaximumActiveDrops >= 4 and LootDropConfig.MaximumActiveDrops <= 8,
	"recovery loot requires a strict low active ceiling"
)
assert(
	LootDropConfig.DropLifetimeSeconds >= 8 and LootDropConfig.DropLifetimeSeconds <= 30,
	"temporary recovery loot requires a readable bounded lifetime"
)
assert(
	LootDropConfig.PickupMaximumDistanceStuds >= 4 and LootDropConfig.PickupMaximumDistanceStuds <= 12,
	"recovery loot collection distance must remain close and server-verifiable"
)
assert(
	LootDropConfig.DropRollPercentByKind[KindIds.AmmunitionBundle] == 0,
	"recovery loot must never duplicate the authoritative ammunition drop economy"
)
assert(
	LootDropConfig.DropRollPercentByKind[KindIds.FieldDressing] == 5
		and LootDropConfig.DropRollPercentByKind[KindIds.FieldIntel] == 2,
	"recovery loot probabilities must remain rare"
)
local totalPercent = LootDropConfig.NoDropPercent
for _, percent in LootDropConfig.DropRollPercentByKind do
	assert(type(percent) == "number" and percent >= 0 and percent % 1 == 0, "drop weights must be nonnegative integers")
	totalPercent += percent
end
assert(totalPercent == 100, "recovery loot probabilities must total exactly 100 percent")
assert(
	LootDropConfig.Rewards.HealingAmount > 0 and LootDropConfig.Rewards.HealingAmount <= 50,
	"field dressings require a positive bounded healing grant"
)
assert(
	LootDropConfig.Rewards.FieldIntelXp > 0 and LootDropConfig.Rewards.FieldIntelXp <= 100,
	"field intel requires a positive bounded run XP grant"
)

return table.freeze(LootDropConfig)
