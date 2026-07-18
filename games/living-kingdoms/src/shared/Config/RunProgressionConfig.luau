--!strict

--[[
	HROI-0105 bounded run-only Field XP and squad-upgrade configuration. Field
	XP is shared, upgrade offers are generated and validated by the server, and
	all stacks reset whenever the server starts a new operation session. No
	permanent account progression or monetized power is represented here.
]]

local UpgradeDefinitions = table.freeze({
	table.freeze({
		Id = "upgrade.overpressure_rounds",
		Name = "OVERPRESSURE ROUNDS",
		Description = "+20% firearm damage per stack",
		MaximumStacks = 4,
		DamageMultiplierPerStack = 0.2,
	}),
	table.freeze({
		Id = "upgrade.hair_trigger",
		Name = "HAIR TRIGGER",
		Description = "+12% automatic fire rate per stack",
		MaximumStacks = 4,
		CadenceReductionPerStack = 0.12,
	}),
	table.freeze({
		Id = "upgrade.rapid_feed",
		Name = "RAPID FEED",
		Description = "+15% reload speed per stack",
		MaximumStacks = 3,
		ReloadReductionPerStack = 0.15,
	}),
	table.freeze({
		Id = "upgrade.cull_protocol",
		Name = "CULL PROTOCOL",
		Description = "+35% damage to enemies at 30 health or less per stack",
		MaximumStacks = 3,
		CullDamageMultiplierPerStack = 0.35,
	}),
})

local RunProgressionConfig = {
	Version = "HROI-0105-v2-squad-upgrades",
	FieldXpPerConfirmedEnemyDeath = 20,
	BaseXpToLevel = 100,
	XpGrowthPerLevel = 1.3,
	MaximumRunLevel = 20,
	EnemyScanIntervalSeconds = 0.1,
	MaximumTrackedEnemyModels = 64,
	GainDisplaySeconds = 1.2,
	UpgradeChoiceCount = 3,
	UpgradeRequestCooldownSeconds = 0.25,
	MinimumCadenceMultiplier = 0.55,
	MinimumReloadDurationMultiplier = 0.55,
	CullHealthThreshold = 30,
	MaximumDamageMultiplier = 3,
	UpgradeDefinitions = UpgradeDefinitions,
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
	RunProgressionConfig.UpgradeChoiceCount == 3
		and RunProgressionConfig.UpgradeChoiceCount < #RunProgressionConfig.UpgradeDefinitions,
	"the first upgrade pool must offer three choices from a larger bounded pool"
)
assert(
	RunProgressionConfig.UpgradeRequestCooldownSeconds >= 0.1
		and RunProgressionConfig.UpgradeRequestCooldownSeconds <= 1,
	"upgrade requests require a short server-owned throttle"
)
assert(
	RunProgressionConfig.MinimumCadenceMultiplier >= 0.4 and RunProgressionConfig.MinimumCadenceMultiplier <= 1,
	"fire-rate upgrades require a bounded cadence floor"
)
assert(
	RunProgressionConfig.MinimumReloadDurationMultiplier >= 0.4
		and RunProgressionConfig.MinimumReloadDurationMultiplier <= 1,
	"reload upgrades require a bounded duration floor"
)
assert(
	RunProgressionConfig.CullHealthThreshold > 0 and RunProgressionConfig.CullHealthThreshold <= 60,
	"cull protocol requires a bounded wounded-enemy threshold"
)
assert(
	RunProgressionConfig.MaximumDamageMultiplier >= 1 and RunProgressionConfig.MaximumDamageMultiplier <= 3,
	"run damage requires a strict multiplier ceiling"
)

local seenUpgradeIds = {}
for _, definition in RunProgressionConfig.UpgradeDefinitions do
	assert(type(definition.Id) == "string" and definition.Id ~= "", "upgrade ID must be non-empty")
	assert(seenUpgradeIds[definition.Id] == nil, "upgrade IDs must be unique")
	seenUpgradeIds[definition.Id] = true
	assert(type(definition.Name) == "string" and definition.Name ~= "", "upgrade name must be non-empty")
	assert(
		type(definition.Description) == "string" and definition.Description ~= "",
		"upgrade description must be non-empty"
	)
	assert(
		type(definition.MaximumStacks) == "number"
			and definition.MaximumStacks % 1 == 0
			and definition.MaximumStacks >= 1
			and definition.MaximumStacks <= 4,
		"upgrade stack cap must be an integer from one through four"
	)
end

return table.freeze(RunProgressionConfig)
