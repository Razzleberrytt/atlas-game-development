--!strict

--[[
	HROI-0105 bounded run-only Field XP and squad upgrade configuration. Field XP
	is shared by the current squad, awarded only from server-observed authoritative
	enemy deaths, and reset whenever the server starts a new operation session.
	No permanent account progression is represented here.
]]

local RunProgressionConfig = {
	Version = "HROI-0105-v2-squad-upgrades",
	FieldXpPerConfirmedEnemyDeath = 20,
	BaseXpToLevel = 100,
	XpGrowthPerLevel = 1.3,
	MaximumRunLevel = 20,
	EnemyScanIntervalSeconds = 0.1,
	MaximumTrackedEnemyModels = 64,
	GainDisplaySeconds = 1.2,
	SelectionIntentCooldownSeconds = 0.2,
	MaximumUpgradeStacks = 19,
	MaximumPendingUpgradeSelections = 4,
	UpgradeOrder = table.freeze({
		"upgrade.ballistic_calibration",
		"upgrade.rapid_cycling",
		"upgrade.quick_hands",
	}),
	UpgradeDefinitions = table.freeze({
		["upgrade.ballistic_calibration"] = table.freeze({
			displayName = "BALLISTIC CALIBRATION",
			description = "+5 firearm damage per hit",
		}),
		["upgrade.rapid_cycling"] = table.freeze({
			displayName = "RAPID CYCLING",
			description = "10% faster automatic fire",
		}),
		["upgrade.quick_hands"] = table.freeze({
			displayName = "QUICK HANDS",
			description = "15% faster reloads",
		}),
	}),
	DamageBonusPerStack = 5,
	CadenceMultiplierPerStack = 0.9,
	ReloadMultiplierPerStack = 0.85,
	MinimumCadenceMultiplier = 0.4,
	MinimumReloadMultiplier = 0.35,
}

assert(
	RunProgressionConfig.FieldXpPerConfirmedEnemyDeath > 0
		and RunProgressionConfig.FieldXpPerConfirmedEnemyDeath <= RunProgressionConfig.BaseXpToLevel,
	"confirmed enemy deaths require a positive bounded Field XP award"
)
assert(RunProgressionConfig.BaseXpToLevel > 0, "the first run level requires positive XP")
assert(
	RunProgressionConfig.XpGrowthPerLevel > 1 and RunProgressionConfig.XpGrowthPerLevel <= 2,
	"run-level XP growth must be gradual and bounded"
)
assert(
	RunProgressionConfig.MaximumRunLevel >= 2 and RunProgressionConfig.MaximumRunLevel <= 50,
	"run progression requires a bounded level ceiling"
)
assert(
	RunProgressionConfig.EnemyScanIntervalSeconds >= 0.05 and RunProgressionConfig.EnemyScanIntervalSeconds <= 0.5,
	"enemy-death observation must remain responsive and bounded"
)
assert(
	RunProgressionConfig.MaximumTrackedEnemyModels >= 24 and RunProgressionConfig.MaximumTrackedEnemyModels <= 64,
	"tracking must cover living enemies plus bounded corpse overlap"
)
assert(
	RunProgressionConfig.GainDisplaySeconds > 0 and RunProgressionConfig.GainDisplaySeconds <= 2,
	"Field XP gain feedback must remain brief"
)
assert(
	RunProgressionConfig.SelectionIntentCooldownSeconds >= 0.1
		and RunProgressionConfig.SelectionIntentCooldownSeconds <= 1,
	"upgrade selection requests require a bounded server cooldown"
)
assert(#RunProgressionConfig.UpgradeOrder == 3, "the first run upgrade offer must contain exactly three choices")
assert(
	RunProgressionConfig.MaximumUpgradeStacks >= RunProgressionConfig.MaximumRunLevel - 1
		and RunProgressionConfig.MaximumUpgradeStacks <= 24,
	"every earned run level must retain at least one bounded upgrade stack"
)
assert(
	RunProgressionConfig.MaximumPendingUpgradeSelections >= 1
		and RunProgressionConfig.MaximumPendingUpgradeSelections <= 8,
	"queued level-up selections must remain bounded"
)
for _, upgradeId in RunProgressionConfig.UpgradeOrder do
	assert(RunProgressionConfig.UpgradeDefinitions[upgradeId] ~= nil, "every offered upgrade requires presentation copy")
end
assert(RunProgressionConfig.DamageBonusPerStack > 0 and RunProgressionConfig.DamageBonusPerStack <= 10)
assert(
	RunProgressionConfig.CadenceMultiplierPerStack > 0
		and RunProgressionConfig.CadenceMultiplierPerStack < 1
		and RunProgressionConfig.MinimumCadenceMultiplier > 0
		and RunProgressionConfig.MinimumCadenceMultiplier < 1
)
assert(
	RunProgressionConfig.ReloadMultiplierPerStack > 0
		and RunProgressionConfig.ReloadMultiplierPerStack < 1
		and RunProgressionConfig.MinimumReloadMultiplier > 0
		and RunProgressionConfig.MinimumReloadMultiplier < 1
)

return table.freeze(RunProgressionConfig)
