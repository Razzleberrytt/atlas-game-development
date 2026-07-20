--!strict

--[[
	HROI-0105 bounded run-only Field XP and squad-upgrade configuration. Field
	XP is shared, upgrade offers are generated and validated by the server, and
	all stacks reset whenever the server starts a new operation session. No
	permanent account progression or monetized power is represented here.

	The v3 pacing target is one first upgrade after four confirmed enemy deaths.
	This aligns the reward onset with the gentler additive-horde warmup while a
	steeper post-level growth curve prevents later high-density combat from
	producing upgrade choices faster than players can evaluate them.

	v4 grows the offer pool beyond the four all-offensive picks into two new
	build axes so choices define a run instead of only stacking damage: one
	bounded defensive mitigation (Iron Hide, a squad incoming-damage floor
	consumed at the enemy attack source) and one bounded economy pick (Field
	Promotion, extra Field XP from confirmed kills). Field XP base values and the
	four-kill first-upgrade pacing are unchanged; Field Promotion can never be
	held before the first upgrade, so it only accelerates later choices.
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
		Id = "upgrade.echo_chamber",
		Name = "ECHO CHAMBER",
		Description = "15% chance each shot consumes no ammunition per stack",
		MaximumStacks = 3,
		AmmoConservationChancePerStack = 0.15,
	}),
	table.freeze({
		Id = "upgrade.cull_protocol",
		Name = "CULL PROTOCOL",
		Description = "+35% damage to enemies at 30 health or less per stack",
		MaximumStacks = 3,
		CullDamageMultiplierPerStack = 0.35,
	}),
	table.freeze({
		Id = "upgrade.iron_hide",
		Name = "IRON HIDE",
		Description = "-10% incoming enemy damage per stack",
		MaximumStacks = 3,
		IncomingDamageReductionPerStack = 0.1,
	}),
	table.freeze({
		Id = "upgrade.field_promotion",
		Name = "FIELD PROMOTION",
		Description = "+20% Field XP from confirmed kills per stack",
		MaximumStacks = 3,
		XpGainMultiplierPerStack = 0.2,
	}),
})

local RunProgressionConfig = {
	Version = "HROI-0105-v4-upgrade-pool-expansion",
	FieldXpPerConfirmedEnemyDeath = 20,
	BaseXpToLevel = 80,
	XpGrowthPerLevel = 1.4,
	MaximumRunLevel = 20,
	EnemyScanIntervalSeconds = 0.1,
	MaximumTrackedEnemyModels = 64,
	GainDisplaySeconds = 1.2,
	UpgradeChoiceCount = 3,
	UpgradeRequestCooldownSeconds = 0.25,
	MinimumCadenceMultiplier = 0.55,
	MaximumAmmoConservationChance = 0.45,
	CullHealthThreshold = 30,
	MaximumDamageMultiplier = 3,
	MaximumIncomingDamageReduction = 0.3,
	MaximumXpGainMultiplier = 1.6,
	UpgradeDefinitions = UpgradeDefinitions,
}

assert(
	RunProgressionConfig.FieldXpPerConfirmedEnemyDeath > 0
		and RunProgressionConfig.FieldXpPerConfirmedEnemyDeath <= RunProgressionConfig.BaseXpToLevel,
	"confirmed enemy deaths require a positive bounded Field XP award"
)
assert(RunProgressionConfig.BaseXpToLevel > 0, "the first run level requires positive XP")
assert(
	RunProgressionConfig.BaseXpToLevel % RunProgressionConfig.FieldXpPerConfirmedEnemyDeath == 0
		and RunProgressionConfig.BaseXpToLevel / RunProgressionConfig.FieldXpPerConfirmedEnemyDeath == 4,
	"the first upgrade must arrive after exactly four ordinary confirmed deaths"
)
assert(
	RunProgressionConfig.XpGrowthPerLevel >= 1.35 and RunProgressionConfig.XpGrowthPerLevel <= 2,
	"post-first-upgrade XP growth must slow later choices while remaining bounded"
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
	RunProgressionConfig.MaximumAmmoConservationChance >= 0
		and RunProgressionConfig.MaximumAmmoConservationChance <= 0.5,
	"ammo conservation must preserve ammunition pressure"
)
assert(
	RunProgressionConfig.CullHealthThreshold > 0 and RunProgressionConfig.CullHealthThreshold <= 60,
	"cull protocol requires a bounded wounded-enemy threshold"
)
assert(
	RunProgressionConfig.MaximumDamageMultiplier >= 1 and RunProgressionConfig.MaximumDamageMultiplier <= 3,
	"run damage requires a strict multiplier ceiling"
)
assert(
	RunProgressionConfig.MaximumIncomingDamageReduction > 0
		and RunProgressionConfig.MaximumIncomingDamageReduction <= 0.5,
	"incoming-damage mitigation must help the squad without trivializing enemy attacks"
)
assert(
	RunProgressionConfig.MaximumXpGainMultiplier > 1 and RunProgressionConfig.MaximumXpGainMultiplier <= 2,
	"Field XP economy upgrades must accelerate later choices within a bounded ceiling"
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
	if definition.IncomingDamageReductionPerStack ~= nil then
		assert(
			type(definition.IncomingDamageReductionPerStack) == "number"
				and definition.IncomingDamageReductionPerStack > 0
				and definition.IncomingDamageReductionPerStack * definition.MaximumStacks
					<= RunProgressionConfig.MaximumIncomingDamageReduction + 1e-9,
			"iron hide mitigation per stack must stay within the configured reduction ceiling"
		)
	end
	if definition.XpGainMultiplierPerStack ~= nil then
		assert(
			type(definition.XpGainMultiplierPerStack) == "number"
				and definition.XpGainMultiplierPerStack > 0
				and 1 + definition.XpGainMultiplierPerStack * definition.MaximumStacks
					<= RunProgressionConfig.MaximumXpGainMultiplier + 1e-9,
			"field promotion XP gain per stack must stay within the configured economy ceiling"
		)
	end
end

return table.freeze(RunProgressionConfig)
