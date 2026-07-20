--!strict

--[[
	RPG-0103 bounded run-only Field XP and squad-upgrade configuration. Field
	XP is shared, upgrade offers are generated and validated by the server, and
	all stacks reset whenever the server starts a new operation session. No
	permanent account progression or monetized power is represented here.

	The v3 pacing target is one first upgrade after four confirmed enemy deaths.
	This aligns the reward onset with the gentler additive-horde warmup while a
	steeper post-level growth curve prevents later high-density combat from
	producing upgrade choices faster than players can evaluate them.

	v5 completes RPG-0103 by growing the offer pool to twelve picks across new build
	axes so choices define a run instead of only stacking damage: bounded
	defensive mitigation (Trauma Plating, a squad incoming-damage floor consumed
	at the enemy attack source), a bounded economy pick (Field Discipline, extra
	Field XP), a bounded reload axis (Combat Loader, reduced reload duration
	consumed by ReloadResolver), and a bounded pattern axis (Pattern Amplifier,
	which raises cleave/pierce secondary damage toward full primary damage in
	DamageResolver's pattern path). Field XP base values and the four-kill
	first-upgrade pacing are unchanged; Field Discipline can never be held before
	the first upgrade, so it only accelerates later choices.

	All twelve definitions use catalog IDs and display names reserved by RPG-0101
	(`RunRpgConfig` / `RunRpgContracts`), and every shared modifier ceiling remains
	inside the canonical global bounds. `RunRpgReconciliation` locks this.

	Interim mechanics: RPG-PLAN-001 describes Trauma Plating as post-level
	temporary armor and Field Discipline as bonus XP from cooperative actions
	(revive/treatment/resupply). Those forms depend on systems not yet built (a
	temporary-armor buffer and cooperative-action XP sources), so this slice ships
	simpler functional mechanics (flat squad mitigation; confirmed-kill XP) and
	the doc records the divergence. Combat Loader matches its planned mechanic.
	Specialist Munitions uses server-owned special-role identity; Expanded Feed
	preserves total ammunition while increasing magazine capacity; Scavenger
	Reach widens only the automatic server collection radius; Last Magazine uses
	the authoritative reserve carried by the accepted shot. Pattern Amplifier is
	offered only when a squad weapon supports cleave or pierce.
]]

local UpgradeDefinitions = table.freeze({
	table.freeze({
		Id = "upgrade.overpressure_rounds",
		Name = "OVERPRESSURE ROUNDS",
		Description = "+20% firearm damage per stack",
		FamilyId = "Firepower",
		IsBroadlyUseful = true,
		MaximumStacks = 4,
		DamageMultiplierPerStack = 0.2,
	}),
	table.freeze({
		Id = "upgrade.hair_trigger",
		Name = "HAIR TRIGGER",
		Description = "+12% automatic fire rate per stack",
		FamilyId = "Firepower",
		IsBroadlyUseful = true,
		MaximumStacks = 4,
		CadenceReductionPerStack = 0.12,
	}),
	table.freeze({
		Id = "upgrade.echo_chamber",
		Name = "ECHO CHAMBER",
		Description = "15% chance each shot consumes no ammunition per stack",
		FamilyId = "AmmunitionReload",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		AmmoConservationChancePerStack = 0.15,
	}),
	table.freeze({
		Id = "upgrade.cull_protocol",
		Name = "CULL PROTOCOL",
		Description = "+35% damage to enemies at 30 health or less per stack",
		FamilyId = "Firepower",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		CullDamageMultiplierPerStack = 0.35,
	}),
	table.freeze({
		Id = "upgrade.trauma_plating",
		Name = "TRAUMA PLATING",
		Description = "-10% incoming enemy damage per stack",
		FamilyId = "Survival",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		IncomingDamageReductionPerStack = 0.1,
	}),
	table.freeze({
		Id = "upgrade.field_discipline",
		Name = "FIELD DISCIPLINE",
		Description = "+15% Field XP from confirmed kills per stack",
		FamilyId = "CooperativeUtility",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		XpGainMultiplierPerStack = 0.15,
	}),
	table.freeze({
		Id = "upgrade.combat_loader",
		Name = "COMBAT LOADER",
		Description = "-12% reload time per stack",
		FamilyId = "AmmunitionReload",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		ReloadDurationReductionPerStack = 0.12,
	}),
	table.freeze({
		Id = "upgrade.pattern_amplifier",
		Name = "PATTERN AMPLIFIER",
		Description = "+15% cleave/pierce secondary damage per stack, up to full primary damage",
		FamilyId = "Firepower",
		IsBroadlyUseful = false,
		CompatibleWeaponIds = table.freeze({ "weapon.breach-shotgun", "weapon.sniper-rifle" }),
		MaximumStacks = 3,
		PatternDamageMultiplierPerStack = 0.15,
	}),
	table.freeze({
		Id = "upgrade.specialist_munitions",
		Name = "SPECIALIST MUNITIONS",
		Description = "+20% damage to Screamer, Bloater, and Brute enemies per stack",
		FamilyId = "Firepower",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		SpecialEnemyDamageMultiplierPerStack = 0.2,
	}),
	table.freeze({
		Id = "upgrade.expanded_feed",
		Name = "EXPANDED FEED",
		Description = "+15% magazine capacity per stack; rounds move from reserve to fill new slots",
		FamilyId = "AmmunitionReload",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		MagazineCapacityMultiplierPerStack = 0.15,
	}),
	table.freeze({
		Id = "upgrade.scavenger_reach",
		Name = "SCAVENGER REACH",
		Description = "+1.5 studs automatic enemy-loot collection radius per stack",
		FamilyId = "AmmunitionReload",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		LootPickupRadiusBonusStudsPerStack = 1.5,
	}),
	table.freeze({
		Id = "upgrade.last_magazine",
		Name = "LAST MAGAZINE",
		Description = "+15% damage per stack while reserve ammunition is at or below 20%",
		FamilyId = "AmmunitionReload",
		IsBroadlyUseful = true,
		MaximumStacks = 3,
		LastMagazineDamageMultiplierPerStack = 0.15,
	}),
})

local RunProgressionConfig = {
	Version = "RPG-0103-v1-twelve-upgrade-pool",
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
	MaximumXpGainMultiplier = 1.5,
	MinimumReloadDurationMultiplier = 0.5,
	MaximumPatternDamageMultiplier = 2,
	MaximumSpecialEnemyDamageMultiplier = 2,
	MaximumMagazineCapacityMultiplier = 1.75,
	MaximumLootPickupRadiusBonusStuds = 4.5,
	MaximumLastMagazineDamageMultiplier = 1.5,
	LastMagazineReserveFraction = 0.2,
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
	#RunProgressionConfig.UpgradeDefinitions >= 12 and #RunProgressionConfig.UpgradeDefinitions <= 16,
	"RPG-0103 requires a bounded twelve-to-sixteen-upgrade pool"
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
assert(
	RunProgressionConfig.MinimumReloadDurationMultiplier >= 0.5
		and RunProgressionConfig.MinimumReloadDurationMultiplier <= 1,
	"reload upgrades may not erase the reload commitment"
)
assert(
	RunProgressionConfig.MaximumPatternDamageMultiplier >= 1
		and RunProgressionConfig.MaximumPatternDamageMultiplier <= 2,
	"pattern-damage upgrades must remain within the bounded secondary-damage ceiling"
)
assert(
	RunProgressionConfig.MaximumSpecialEnemyDamageMultiplier >= 1
		and RunProgressionConfig.MaximumSpecialEnemyDamageMultiplier <= 2,
	"special-enemy damage must remain within the RPG ceiling"
)
assert(
	RunProgressionConfig.MaximumMagazineCapacityMultiplier >= 1
		and RunProgressionConfig.MaximumMagazineCapacityMultiplier <= 1.75,
	"magazine growth must remain within the RPG ceiling"
)
assert(
	RunProgressionConfig.MaximumLootPickupRadiusBonusStuds > 0
		and RunProgressionConfig.MaximumLootPickupRadiusBonusStuds <= 4.5,
	"loot collection must remain local"
)
assert(
	RunProgressionConfig.MaximumLastMagazineDamageMultiplier >= 1
		and RunProgressionConfig.MaximumLastMagazineDamageMultiplier <= 1.5,
	"low-reserve damage must remain bounded"
)
assert(
	RunProgressionConfig.LastMagazineReserveFraction > 0 and RunProgressionConfig.LastMagazineReserveFraction <= 0.25,
	"Last Magazine must activate only under critical reserve scarcity"
)

local seenUpgradeIds = {}
local knownFamilyIds = {
	Firepower = true,
	AmmunitionReload = true,
	Survival = true,
	CooperativeUtility = true,
}
for _, definition in RunProgressionConfig.UpgradeDefinitions do
	assert(type(definition.Id) == "string" and definition.Id ~= "", "upgrade ID must be non-empty")
	assert(seenUpgradeIds[definition.Id] == nil, "upgrade IDs must be unique")
	seenUpgradeIds[definition.Id] = true
	assert(type(definition.Name) == "string" and definition.Name ~= "", "upgrade name must be non-empty")
	assert(knownFamilyIds[definition.FamilyId] == true, "upgrade family must use the canonical RPG vocabulary")
	assert(type(definition.IsBroadlyUseful) == "boolean", "upgrade breadth must be explicit")
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
			"trauma plating mitigation per stack must stay within the configured reduction ceiling"
		)
	end
	if definition.XpGainMultiplierPerStack ~= nil then
		assert(
			type(definition.XpGainMultiplierPerStack) == "number"
				and definition.XpGainMultiplierPerStack > 0
				and 1 + definition.XpGainMultiplierPerStack * definition.MaximumStacks
					<= RunProgressionConfig.MaximumXpGainMultiplier + 1e-9,
			"field discipline XP gain per stack must stay within the configured economy ceiling"
		)
	end
	if definition.ReloadDurationReductionPerStack ~= nil then
		assert(
			type(definition.ReloadDurationReductionPerStack) == "number"
				and definition.ReloadDurationReductionPerStack > 0
				and 1 - definition.ReloadDurationReductionPerStack * definition.MaximumStacks
					>= RunProgressionConfig.MinimumReloadDurationMultiplier - 1e-9,
			"combat loader reload reduction per stack must respect the configured duration floor"
		)
	end
	if definition.PatternDamageMultiplierPerStack ~= nil then
		assert(
			type(definition.PatternDamageMultiplierPerStack) == "number"
				and definition.PatternDamageMultiplierPerStack > 0
				and 1 + definition.PatternDamageMultiplierPerStack * definition.MaximumStacks
					<= RunProgressionConfig.MaximumPatternDamageMultiplier + 1e-9,
			"pattern amplifier per stack must stay within the configured pattern-damage ceiling"
		)
	end
	if definition.SpecialEnemyDamageMultiplierPerStack ~= nil then
		assert(
			type(definition.SpecialEnemyDamageMultiplierPerStack) == "number"
				and definition.SpecialEnemyDamageMultiplierPerStack > 0
				and 1 + definition.SpecialEnemyDamageMultiplierPerStack * definition.MaximumStacks
					<= RunProgressionConfig.MaximumSpecialEnemyDamageMultiplier + 1e-9,
			"Specialist Munitions must respect the special-enemy damage ceiling"
		)
	end
	if definition.MagazineCapacityMultiplierPerStack ~= nil then
		assert(
			type(definition.MagazineCapacityMultiplierPerStack) == "number"
				and definition.MagazineCapacityMultiplierPerStack > 0
				and 1 + definition.MagazineCapacityMultiplierPerStack * definition.MaximumStacks
					<= RunProgressionConfig.MaximumMagazineCapacityMultiplier + 1e-9,
			"Expanded Feed must respect the magazine-capacity ceiling"
		)
	end
	if definition.LootPickupRadiusBonusStudsPerStack ~= nil then
		assert(
			type(definition.LootPickupRadiusBonusStudsPerStack) == "number"
				and definition.LootPickupRadiusBonusStudsPerStack > 0
				and definition.LootPickupRadiusBonusStudsPerStack * definition.MaximumStacks
					<= RunProgressionConfig.MaximumLootPickupRadiusBonusStuds + 1e-9,
			"Scavenger Reach must respect the local collection ceiling"
		)
	end
	if definition.LastMagazineDamageMultiplierPerStack ~= nil then
		assert(
			type(definition.LastMagazineDamageMultiplierPerStack) == "number"
				and definition.LastMagazineDamageMultiplierPerStack > 0
				and 1 + definition.LastMagazineDamageMultiplierPerStack * definition.MaximumStacks
					<= RunProgressionConfig.MaximumLastMagazineDamageMultiplier + 1e-9,
			"Last Magazine must respect its conditional damage ceiling"
		)
	end
	if definition.CompatibleWeaponIds ~= nil then
		assert(#definition.CompatibleWeaponIds > 0, "weapon-specific upgrades require compatible weapons")
		local seenCompatibleWeaponIds = {}
		for _, weaponId in definition.CompatibleWeaponIds do
			assert(type(weaponId) == "string" and weaponId ~= "", "compatible weapon IDs must be non-empty")
			assert(not seenCompatibleWeaponIds[weaponId], "compatible weapon IDs must be unique")
			seenCompatibleWeaponIds[weaponId] = true
		end
	end
end

return table.freeze(RunProgressionConfig)
