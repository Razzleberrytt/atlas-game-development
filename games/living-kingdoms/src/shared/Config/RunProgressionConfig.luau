--!strict

--[[
	HROI-0105 bounded run-only Field XP configuration. Field XP is shared by the
	current squad, awarded only from server-observed authoritative enemy deaths,
	and reset whenever the server starts a new operation session. No permanent
	account progression is represented here.
]]

local RunProgressionConfig = {
	Version = "HROI-0105-v1-field-xp",
	FieldXpPerConfirmedEnemyDeath = 20,
	BaseXpToLevel = 100,
	XpGrowthPerLevel = 1.3,
	MaximumRunLevel = 20,
	EnemyScanIntervalSeconds = 0.1,
	MaximumTrackedEnemyModels = 64,
	GainDisplaySeconds = 1.2,
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
	RunProgressionConfig.EnemyScanIntervalSeconds >= 0.05
		and RunProgressionConfig.EnemyScanIntervalSeconds <= 0.5,
	"enemy-death observation must remain responsive and bounded"
)
assert(
	RunProgressionConfig.MaximumTrackedEnemyModels >= 24
		and RunProgressionConfig.MaximumTrackedEnemyModels <= 64,
	"tracking must cover living enemies plus bounded corpse overlap"
)
assert(
	RunProgressionConfig.GainDisplaySeconds > 0 and RunProgressionConfig.GainDisplaySeconds <= 2,
	"Field XP gain feedback must remain brief"
)

return table.freeze(RunProgressionConfig)
