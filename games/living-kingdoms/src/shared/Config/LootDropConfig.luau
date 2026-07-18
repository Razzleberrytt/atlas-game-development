--!strict

--[[
	HROI-0106 bounded run-only loot values. Drops are temporary server-owned world
	objects and never represent permanent inventory, rarity, crafting, or paid
	power.
]]

local LootDropContracts = require(script.Parent.Parent.Loot.LootDropContracts)

local KindIds = LootDropContracts.LootKindIds

local LootDropConfig = {
	Version = "HROI-0106-v1",
	EnemyScanIntervalSeconds = 0.1,
	MaximumTrackedEnemyModels = 64,
	MaximumActiveDrops = 20,
	DropLifetimeSeconds = 18,
	PickupMaximumDistanceStuds = 8,
	PromptHoldDurationSeconds = 0,
	DropRollPercentByKind = table.freeze({
		[KindIds.AmmunitionBundle] = 45,
		[KindIds.FieldDressing] = 25,
		[KindIds.FieldIntel] = 10,
	}),
	NoDropPercent = 20,
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
	"loot death observation must remain responsive and bounded"
)
assert(
	LootDropConfig.MaximumTrackedEnemyModels >= 24 and LootDropConfig.MaximumTrackedEnemyModels <= 64,
	"loot death observation must cover living enemies and bounded corpse overlap"
)
assert(
	LootDropConfig.MaximumActiveDrops >= 8 and LootDropConfig.MaximumActiveDrops <= 24,
	"active loot must remain visible but bounded"
)
assert(
	LootDropConfig.DropLifetimeSeconds >= 8 and LootDropConfig.DropLifetimeSeconds <= 30,
	"temporary loot requires a readable bounded lifetime"
)
assert(
	LootDropConfig.PickupMaximumDistanceStuds >= 4 and LootDropConfig.PickupMaximumDistanceStuds <= 12,
	"loot collection distance must remain close and server-verifiable"
)
local totalPercent = LootDropConfig.NoDropPercent
for _, percent in LootDropConfig.DropRollPercentByKind do
	assert(type(percent) == "number" and percent > 0 and percent % 1 == 0, "drop weights must be positive integers")
	totalPercent += percent
end
assert(totalPercent == 100, "loot probabilities must total exactly 100 percent")
assert(
	LootDropConfig.Rewards.AmmunitionRounds > 0 and LootDropConfig.Rewards.AmmunitionRounds <= 24,
	"ammunition drops require a positive bounded round grant"
)
assert(
	LootDropConfig.Rewards.HealingAmount > 0 and LootDropConfig.Rewards.HealingAmount <= 50,
	"field dressings require a positive bounded healing grant"
)
assert(
	LootDropConfig.Rewards.FieldIntelXp > 0 and LootDropConfig.Rewards.FieldIntelXp <= 100,
	"field intel requires a positive bounded run XP grant"
)

return table.freeze(LootDropConfig)
