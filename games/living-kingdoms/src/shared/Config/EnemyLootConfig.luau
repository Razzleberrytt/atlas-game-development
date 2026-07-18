--!strict

--[[
	HROI-0106 run-only enemy ammunition loot. Confirmed enemy deaths may create
	one short-lived server-owned pickup at the corpse position. The pickup pool,
	grant sizes, lifetime, collection radius, guaranteed reward cadence, and
	evaluation cadence are all bounded here; no permanent inventory or account
	reward is represented.
]]

local EnemyLootConfig = {
	Version = "HROI-0106-v2-guaranteed-salvage",
	EvaluationIntervalSeconds = 0.1,
	MaximumTrackedEnemyModels = 64,
	MaximumActiveDrops = 16,
	PickupRadiusStuds = 5.5,
	MaximumVerticalPickupDistanceStuds = 8,
	DropRollModulo = 20,
	RareDropRolls = 1,
	CommonDropRolls = 6,
	GuaranteeFirstConfirmedDeath = true,
	GuaranteedCommonDropEveryDeaths = 5,
	HoverHeightStuds = 1.35,
	BobAmplitudeStuds = 0.22,
	BobRadiansPerSecond = 3.2,
	SpinRadiansPerSecond = 1.8,
	Definitions = table.freeze({
		Common = table.freeze({
			LootKindId = "LooseRounds",
			RarityId = "Common",
			DisplayName = "SALVAGED ROUNDS",
			Rounds = 8,
			LifetimeSeconds = 16,
		}),
		Rare = table.freeze({
			LootKindId = "AmmoCase",
			RarityId = "Rare",
			DisplayName = "HEAVY AMMO CASE",
			Rounds = 20,
			LifetimeSeconds = 24,
		}),
	}),
}

assert(
	EnemyLootConfig.EvaluationIntervalSeconds >= 0.05 and EnemyLootConfig.EvaluationIntervalSeconds <= 0.25,
	"enemy loot evaluation must remain responsive and bounded"
)
assert(
	EnemyLootConfig.MaximumTrackedEnemyModels >= 24 and EnemyLootConfig.MaximumTrackedEnemyModels <= 64,
	"enemy loot death observation must cover bounded corpse overlap"
)
assert(
	EnemyLootConfig.MaximumActiveDrops >= 4 and EnemyLootConfig.MaximumActiveDrops <= 24,
	"enemy loot requires a strict active pickup ceiling"
)
assert(
	EnemyLootConfig.PickupRadiusStuds > 0 and EnemyLootConfig.PickupRadiusStuds <= 8,
	"enemy loot automatic collection radius must remain local"
)
assert(
	EnemyLootConfig.RareDropRolls > 0
		and EnemyLootConfig.CommonDropRolls > 0
		and EnemyLootConfig.RareDropRolls + EnemyLootConfig.CommonDropRolls < EnemyLootConfig.DropRollModulo,
	"enemy loot probabilities must leave a no-drop outcome"
)
assert(
	type(EnemyLootConfig.GuaranteeFirstConfirmedDeath) == "boolean",
	"first-death guarantee must be an explicit bounded product decision"
)
assert(
	EnemyLootConfig.GuaranteedCommonDropEveryDeaths >= 3
		and EnemyLootConfig.GuaranteedCommonDropEveryDeaths <= 12
		and EnemyLootConfig.GuaranteedCommonDropEveryDeaths % 1 == 0,
	"guaranteed salvage cadence must remain useful and bounded"
)
for _, definition in EnemyLootConfig.Definitions do
	assert(definition.Rounds > 0 and definition.Rounds <= 24, "enemy loot ammunition grants must remain bounded")
	assert(
		definition.LifetimeSeconds >= 8 and definition.LifetimeSeconds <= 30,
		"enemy loot lifetime must remain brief"
	)
end

return table.freeze(EnemyLootConfig)
