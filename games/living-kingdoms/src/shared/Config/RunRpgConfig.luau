--!strict

--[[
	RPG-0101 configuration for the proposed operation-bound RPG layer. This file
	locks catalog identity, slot/reward/elite ceilings, and global modifier safety
	bounds before runtime integration. Planned entries are declarations only and
	do not grant power, assign elites, generate rewards, or persist between runs.
]]

local RunRpgContracts = require(script.Parent.Parent.RPG.RunRpgContracts)

local UpgradeIds = RunRpgContracts.RunUpgradeIds
local UpgradeFamilyIds = RunRpgContracts.RunUpgradeFamilyIds
local AffixIds = RunRpgContracts.EliteAffixIds
local RelicIds = RunRpgContracts.RelicIds
local ModifierIds = RunRpgContracts.ModifierCategoryIds
local TriggerIds = RunRpgContracts.EffectTriggerIds
local CompatibilityIds = RunRpgContracts.RelicCompatibilityIds
local ImplementationStateIds = RunRpgContracts.ImplementationStateIds
local RewardSourceIds = RunRpgContracts.RewardSourceIds

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isFinitePositive(value: number): boolean
	return isFinite(value) and value > 0
end

local function isNonnegativeInteger(value: number): boolean
	return isFinite(value) and value >= 0 and value % 1 == 0
end

local Limits = table.freeze({
	maximumEquippedRelicsPerOperative = 3,
	relicChoiceCountPerReward = 2,
	maximumQueuedRelicRewardsPerOperative = 3,
	maximumSimultaneousElites = 3,
	maximumAffixesPerEnemy = 1,
	maximumUpgradeStacksPerDefinition = 4,
	maximumProcessedRequestIdsPerOperative = 64,
	maximumProcessedRewardIdsPerOperation = 128,
	minimumChoiceRequestIntervalSeconds = 0.2,
})

local ModifierCeilings = table.freeze({
	maximumDamageMultiplier = 3,
	minimumCadenceMultiplier = 0.55,
	maximumAmmunitionConservationChance = 0.5,
	maximumMagazineCapacityMultiplier = 1.75,
	minimumReloadDurationMultiplier = 0.5,
	maximumMovementSpeedMultiplier = 1.35,
	maximumAutomaticHealingPerTrigger = 25,
	maximumTemporaryArmorFractionOfMaximumHealth = 0.4,
	maximumLootChanceAdditiveBonus = 0.15,
	maximumFieldXpMultiplier = 1.5,
	maximumKillChainExtensionSeconds = 2,
	maximumPatternDamageMultiplier = 2,
	maximumSpecialEnemyDamageMultiplier = 2,
	maximumGeneralProcChance = 0.35,
})

local EliteAssignmentPlanning = table.freeze({
	ordinaryPressureProbabilityMinimum = 0.03,
	ordinaryPressureProbabilityMaximum = 0.06,
	hordePulseProbabilityMinimum = 0.05,
	hordePulseProbabilityMaximum = 0.09,
	protectedOpeningSeconds = 10,
	isRuntimeEnabled = false,
})

local UpgradeCatalog = table.freeze({
	table.freeze({
		upgradeId = UpgradeIds.OverpressureRounds,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "OVERPRESSURE ROUNDS",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.HairTrigger,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "HAIR TRIGGER",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.EchoChamber,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "ECHO CHAMBER",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.CullProtocol,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "CULL PROTOCOL",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.PatternAmplifier,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "PATTERN AMPLIFIER",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.SpecialistMunitions,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "SPECIALIST MUNITIONS",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.CombatLoader,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "COMBAT LOADER",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.ExpandedFeed,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "EXPANDED FEED",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.ScavengerReach,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "SCAVENGER REACH",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.LastMagazine,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "LAST MAGAZINE",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.TraumaPlating,
		familyId = UpgradeFamilyIds.Survival,
		displayName = "TRAUMA PLATING",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.AdrenalResponse,
		familyId = UpgradeFamilyIds.Survival,
		displayName = "ADRENAL RESPONSE",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.SecondPulse,
		familyId = UpgradeFamilyIds.Survival,
		displayName = "SECOND PULSE",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.RescueInstinct,
		familyId = UpgradeFamilyIds.Survival,
		displayName = "RESCUE INSTINCT",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.SharedMomentum,
		familyId = UpgradeFamilyIds.CooperativeUtility,
		displayName = "SHARED MOMENTUM",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.CoveringFire,
		familyId = UpgradeFamilyIds.CooperativeUtility,
		displayName = "COVERING FIRE",
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		upgradeId = UpgradeIds.FieldDiscipline,
		familyId = UpgradeFamilyIds.CooperativeUtility,
		displayName = "FIELD DISCIPLINE",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
})

local EliteAffixCatalog = table.freeze({
	table.freeze({
		affixId = AffixIds.Armored,
		displayName = "ARMORED",
		modifierCategoryIds = table.freeze({ ModifierIds.Damage }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		affixId = AffixIds.Frenzied,
		displayName = "FRENZIED",
		modifierCategoryIds = table.freeze({ ModifierIds.Cadence, ModifierIds.MovementSpeed }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		affixId = AffixIds.Regenerator,
		displayName = "REGENERATOR",
		modifierCategoryIds = table.freeze({ ModifierIds.Healing }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		affixId = AffixIds.Volatile,
		displayName = "VOLATILE",
		modifierCategoryIds = table.freeze({ ModifierIds.Damage }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		affixId = AffixIds.Commander,
		displayName = "COMMANDER",
		modifierCategoryIds = table.freeze({ ModifierIds.Damage, ModifierIds.Cadence }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Planned,
	}),
})

local RelicCatalog = table.freeze({
	table.freeze({
		relicId = RelicIds.BloodBattery,
		displayName = "BLOOD BATTERY",
		triggerId = TriggerIds.ConfirmedKill,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Healing }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 8,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.GraveMomentum,
		displayName = "GRAVE MOMENTUM",
		triggerId = TriggerIds.KillChainActive,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.KillChainWindow }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.ChoirBreaker,
		displayName = "CHOIR BREAKER",
		triggerId = TriggerIds.EnemySpecialWindup,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.SpecialEnemyDamage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.LastLight,
		displayName = "LAST LIGHT",
		triggerId = TriggerIds.LowReserveAmmunition,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Damage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.EmergencyChamber,
		displayName = "EMERGENCY CHAMBER",
		triggerId = TriggerIds.ReloadAccepted,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.ReloadDuration }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.SalvagersMark,
		displayName = "SALVAGER'S MARK",
		triggerId = TriggerIds.AmmunitionLootResolved,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Loot }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.ExecutionProtocol,
		displayName = "EXECUTION PROTOCOL",
		triggerId = TriggerIds.EnemyBelowHealthThreshold,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Damage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.BreachDoctrine,
		displayName = "BREACH DOCTRINE",
		triggerId = TriggerIds.ShotgunSecondaryImpact,
		compatibilityId = CompatibilityIds.Shotgun,
		modifierCategoryIds = table.freeze({ ModifierIds.PatternDamage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.LongwatchDoctrine,
		displayName = "LONGWATCH DOCTRINE",
		triggerId = TriggerIds.SniperSecondaryImpact,
		compatibilityId = CompatibilityIds.Sniper,
		modifierCategoryIds = table.freeze({ ModifierIds.PatternDamage, ModifierIds.SpecialEnemyDamage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.SuppressionEngine,
		displayName = "SUPPRESSION ENGINE",
		triggerId = TriggerIds.SustainedAutomaticFire,
		compatibilityId = CompatibilityIds.Automatic,
		modifierCategoryIds = table.freeze({ ModifierIds.Cadence, ModifierIds.Damage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 6,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.GuardianSignal,
		displayName = "GUARDIAN SIGNAL",
		triggerId = TriggerIds.TeammateRevived,
		compatibilityId = CompatibilityIds.Cooperative,
		modifierCategoryIds = table.freeze({ ModifierIds.TemporaryArmor }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		relicId = RelicIds.SecondWind,
		displayName = "SECOND WIND",
		triggerId = TriggerIds.IncomingIncapacitation,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Healing }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 1,
		implementationStateId = ImplementationStateIds.Planned,
	}),
})

local RewardSourceCatalog = table.freeze({
	table.freeze({ sourceId = RewardSourceIds.EliteKill, implementationStateId = ImplementationStateIds.Planned }),
	table.freeze({
		sourceId = RewardSourceIds.SpecialInterrupt,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		sourceId = RewardSourceIds.ObjectiveCompletion,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		sourceId = RewardSourceIds.AuthoredContainer,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({ sourceId = RewardSourceIds.HordeClear, implementationStateId = ImplementationStateIds.Planned }),
	table.freeze({ sourceId = RewardSourceIds.BossMilestone, implementationStateId = ImplementationStateIds.Planned }),
})

local Config = {
	Version = "RPG-0101-v1-contracts-only",
	Limits = Limits,
	ModifierCeilings = ModifierCeilings,
	EliteAssignmentPlanning = EliteAssignmentPlanning,
	UpgradeCatalog = UpgradeCatalog,
	EliteAffixCatalog = EliteAffixCatalog,
	RelicCatalog = RelicCatalog,
	RewardSourceCatalog = RewardSourceCatalog,
}

assert(Limits.maximumEquippedRelicsPerOperative == 3, "the initial run build requires exactly three relic slots")
assert(Limits.relicChoiceCountPerReward == 2, "relic rewards require exactly two choices")
assert(Limits.maximumQueuedRelicRewardsPerOperative == 3, "pending relic rewards require a strict queue ceiling")
assert(Limits.maximumSimultaneousElites == 3, "the initial elite population requires a strict ceiling")
assert(Limits.maximumAffixesPerEnemy == 1, "v1 enemies may carry exactly one affix at most")
assert(
	Limits.maximumUpgradeStacksPerDefinition >= 1 and Limits.maximumUpgradeStacksPerDefinition <= 4,
	"upgrade stacks must remain bounded"
)
assert(
	isNonnegativeInteger(Limits.maximumProcessedRequestIdsPerOperative)
		and Limits.maximumProcessedRequestIdsPerOperative > 0
		and Limits.maximumProcessedRequestIdsPerOperative <= 256,
	"RPG request replay history must remain bounded"
)
assert(
	isNonnegativeInteger(Limits.maximumProcessedRewardIdsPerOperation)
		and Limits.maximumProcessedRewardIdsPerOperation > 0
		and Limits.maximumProcessedRewardIdsPerOperation <= 512,
	"RPG reward replay history must remain bounded"
)
assert(
	isFinitePositive(Limits.minimumChoiceRequestIntervalSeconds) and Limits.minimumChoiceRequestIntervalSeconds <= 1,
	"RPG choice requests require a responsive server-owned throttle"
)

assert(ModifierCeilings.maximumDamageMultiplier == 3, "RPG damage must share the existing strict three-times ceiling")
assert(
	ModifierCeilings.minimumCadenceMultiplier >= 0.4 and ModifierCeilings.minimumCadenceMultiplier <= 1,
	"RPG cadence must preserve a bounded interval floor"
)
assert(
	ModifierCeilings.maximumAmmunitionConservationChance >= 0
		and ModifierCeilings.maximumAmmunitionConservationChance <= 0.5,
	"RPG ammunition conservation must preserve scarcity"
)
assert(
	ModifierCeilings.maximumMagazineCapacityMultiplier >= 1 and ModifierCeilings.maximumMagazineCapacityMultiplier <= 2,
	"RPG magazine growth must remain bounded"
)
assert(
	ModifierCeilings.minimumReloadDurationMultiplier >= 0.5 and ModifierCeilings.minimumReloadDurationMultiplier <= 1,
	"RPG reload effects may not erase the reload commitment"
)
assert(
	ModifierCeilings.maximumMovementSpeedMultiplier >= 1 and ModifierCeilings.maximumMovementSpeedMultiplier <= 1.35,
	"RPG movement must preserve encounter geometry"
)
assert(
	ModifierCeilings.maximumAutomaticHealingPerTrigger > 0 and ModifierCeilings.maximumAutomaticHealingPerTrigger <= 25,
	"automatic RPG healing must not replace finite treatment"
)
assert(
	ModifierCeilings.maximumTemporaryArmorFractionOfMaximumHealth > 0
		and ModifierCeilings.maximumTemporaryArmorFractionOfMaximumHealth <= 0.4,
	"temporary armor requires a strict health-relative ceiling"
)
assert(
	ModifierCeilings.maximumLootChanceAdditiveBonus >= 0 and ModifierCeilings.maximumLootChanceAdditiveBonus <= 0.15,
	"RPG loot modifiers must preserve reward scarcity"
)
assert(
	ModifierCeilings.maximumFieldXpMultiplier >= 1 and ModifierCeilings.maximumFieldXpMultiplier <= 1.5,
	"RPG Field XP modifiers must not create level spam"
)
assert(
	ModifierCeilings.maximumKillChainExtensionSeconds >= 0 and ModifierCeilings.maximumKillChainExtensionSeconds <= 2,
	"RPG kill-chain extension requires a strict ceiling"
)
assert(
	ModifierCeilings.maximumPatternDamageMultiplier >= 1 and ModifierCeilings.maximumPatternDamageMultiplier <= 2,
	"pattern damage must remain bounded"
)
assert(
	ModifierCeilings.maximumSpecialEnemyDamageMultiplier >= 1
		and ModifierCeilings.maximumSpecialEnemyDamageMultiplier <= 2,
	"special-enemy damage must remain bounded"
)
assert(
	ModifierCeilings.maximumGeneralProcChance >= 0 and ModifierCeilings.maximumGeneralProcChance <= 0.35,
	"general RPG proc chance requires a strict ceiling"
)

assert(
	EliteAssignmentPlanning.ordinaryPressureProbabilityMinimum >= 0
		and EliteAssignmentPlanning.ordinaryPressureProbabilityMaximum <= 0.06
		and EliteAssignmentPlanning.ordinaryPressureProbabilityMinimum
			<= EliteAssignmentPlanning.ordinaryPressureProbabilityMaximum,
	"ordinary elite planning range must remain bounded"
)
assert(
	EliteAssignmentPlanning.hordePulseProbabilityMinimum >= 0
		and EliteAssignmentPlanning.hordePulseProbabilityMaximum <= 0.09
		and EliteAssignmentPlanning.hordePulseProbabilityMinimum
			<= EliteAssignmentPlanning.hordePulseProbabilityMaximum,
	"horde elite planning range must remain bounded"
)
assert(
	isFinitePositive(EliteAssignmentPlanning.protectedOpeningSeconds)
		and EliteAssignmentPlanning.protectedOpeningSeconds <= 20,
	"elite assignment requires a bounded protected opening"
)
assert(not EliteAssignmentPlanning.isRuntimeEnabled, "RPG-0101 must not enable elite runtime behavior")

local function countVocabulary(values: { [string]: string }): number
	local count = 0
	for _ in values do
		count += 1
	end
	return count
end

local seenUpgradeIds = {}
local implementedUpgradeCount = 0
for _, definition in UpgradeCatalog do
	assert(not seenUpgradeIds[definition.upgradeId], "RPG upgrade catalog IDs must be unique")
	seenUpgradeIds[definition.upgradeId] = true
	assert(RunRpgContracts.isKnownRunUpgradeId(definition.upgradeId), "RPG upgrade catalog contains an unknown ID")
	assert(definition.displayName ~= "", "RPG upgrades require display names")
	assert(definition.familyId ~= nil, "RPG upgrades require a family")
	if definition.implementationStateId == ImplementationStateIds.Implemented then
		implementedUpgradeCount += 1
	else
		assert(definition.implementationStateId == ImplementationStateIds.Planned, "upgrade state must be stable")
	end
end
assert(#UpgradeCatalog == countVocabulary(UpgradeIds), "every RPG upgrade ID requires exactly one catalog entry")
assert(
	implementedUpgradeCount == 7,
	"the implemented catalog must match the seven live run upgrades (four original plus Trauma Plating, Field Discipline, and Combat Loader)"
)

local seenAffixIds = {}
for _, definition in EliteAffixCatalog do
	assert(not seenAffixIds[definition.affixId], "elite affix IDs must be unique")
	seenAffixIds[definition.affixId] = true
	assert(RunRpgContracts.isKnownEliteAffixId(definition.affixId), "elite catalog contains an unknown ID")
	assert(definition.displayName ~= "", "elite affixes require display names")
	assert(definition.maximumPerEnemy == 1, "v1 affixes cannot stack on one enemy")
	assert(definition.requiresTelegraph, "every elite affix requires readable telegraphing")
	assert(not definition.bossEligible, "v1 affixes cannot be assigned to bosses")
	assert(definition.implementationStateId == ImplementationStateIds.Planned, "RPG-0101 affixes remain declarations")
	assert(#definition.modifierCategoryIds >= 1, "every elite affix requires a declared modifier category")
end
assert(#EliteAffixCatalog == countVocabulary(AffixIds), "every elite affix ID requires exactly one catalog entry")

local seenRelicIds = {}
for _, definition in RelicCatalog do
	assert(not seenRelicIds[definition.relicId], "relic IDs must be unique")
	seenRelicIds[definition.relicId] = true
	assert(RunRpgContracts.isKnownRelicId(definition.relicId), "relic catalog contains an unknown ID")
	assert(definition.displayName ~= "", "relics require display names")
	assert(definition.maximumStacks == 1, "initial relics must remain non-stackable")
	assert(definition.slotCost == 1, "initial relics must consume one slot")
	assert(isNonnegativeInteger(definition.counterThreshold), "relic counter thresholds must be whole")
	assert(isNonnegativeInteger(definition.maximumCharges), "relic charges must be whole")
	assert(definition.implementationStateId == ImplementationStateIds.Planned, "RPG-0101 relics remain declarations")
	assert(#definition.modifierCategoryIds >= 1, "every relic requires a modifier category")
end
assert(#RelicCatalog == countVocabulary(RelicIds), "every relic ID requires exactly one catalog entry")

local seenRewardSourceIds = {}
for _, definition in RewardSourceCatalog do
	assert(not seenRewardSourceIds[definition.sourceId], "reward source IDs must be unique")
	seenRewardSourceIds[definition.sourceId] = true
	assert(
		definition.implementationStateId == ImplementationStateIds.Planned,
		"RPG-0101 reward sources remain declarations"
	)
end
assert(#RewardSourceCatalog == countVocabulary(RewardSourceIds), "every reward source requires one catalog entry")

return table.freeze(Config)
