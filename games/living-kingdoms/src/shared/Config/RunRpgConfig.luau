--!strict

--[[
	Canonical operation-bound RPG configuration through RPG-0106. This file
	locks catalog identity, slot/reward/elite ceilings, global modifier safety
	bounds, and the complete initial elite roster. Entries still marked Planned do
	not grant power, generate rewards, or persist between runs.
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
	maximumTrackedOperativesPerOperation = 4,
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
	maximumIncomingDamageReduction = 0.3,
	maximumLootPickupRadiusBonusStuds = 4.5,
	maximumLootRoundsAdditiveBonus = 6,
	maximumConditionalDamageMultiplier = 1.5,
})

local EliteAssignmentPlanning = table.freeze({
	ordinaryPressureProbabilityMinimum = 0.03,
	ordinaryPressureProbabilityMaximum = 0.06,
	hordePulseProbabilityMinimum = 0.05,
	hordePulseProbabilityMaximum = 0.09,
	protectedOpeningSeconds = 10,
	isRuntimeEnabled = true,
	ordinaryPressureProbability = 0.05,
	hordePulseProbability = 0.07,
	deterministicRollResolution = 10000,
})

local FrenziedRuntime = table.freeze({
	movementSpeedMultiplier = 1.25,
	attackCadenceMultiplier = 0.7,
	maximumHealthMultiplier = 0.85,
	bonusFieldXp = 20,
	highlightFillColor = table.freeze({ 255, 74, 24 }),
	highlightOutlineColor = table.freeze({ 255, 214, 74 }),
	highlightFillTransparency = 0.42,
	highlightOutlineTransparency = 0,
	compatibleHordeRoleIds = table.freeze({
		"horde.role.infected",
		"horde.role.crawler",
		"horde.role.screamer",
		"horde.role.bloater",
		"horde.role.brute",
	}),
})

local ArmoredRuntime = table.freeze({
	damageTakenMultiplierWhileArmored = 0.6,
	armorCapacity = 40,
	bonusFieldXp = 20,
	highlightFillColor = table.freeze({ 65, 91, 114 }),
	highlightOutlineColor = table.freeze({ 190, 224, 255 }),
	highlightFillTransparency = 0.5,
	highlightOutlineTransparency = 0,
	compatibleHordeRoleIds = table.freeze({
		"horde.role.infected",
		"horde.role.runner",
		"horde.role.crawler",
		"horde.role.screamer",
		"horde.role.bloater",
	}),
})

local RegeneratorRuntime = table.freeze({
	damageRecoveryDelaySeconds = 4,
	healingIntervalSeconds = 1,
	healingPerInterval = 5,
	bonusFieldXp = 20,
	highlightFillColor = table.freeze({ 28, 112, 62 }),
	highlightOutlineColor = table.freeze({ 104, 255, 151 }),
	highlightFillTransparency = 0.48,
	highlightOutlineTransparency = 0,
	compatibleHordeRoleIds = table.freeze({
		"horde.role.infected",
		"horde.role.runner",
		"horde.role.crawler",
		"horde.role.screamer",
		"horde.role.bloater",
	}),
})

local VolatileRuntime = table.freeze({
	deathReactionDelaySeconds = 1.25,
	deathReactionRadiusStuds = 12,
	deathReactionDamage = 12,
	bonusFieldXp = 20,
	highlightFillColor = table.freeze({ 121, 37, 139 }),
	highlightOutlineColor = table.freeze({ 244, 134, 255 }),
	highlightFillTransparency = 0.45,
	highlightOutlineTransparency = 0,
	compatibleHordeRoleIds = table.freeze({
		"horde.role.infected",
		"horde.role.runner",
		"horde.role.crawler",
		"horde.role.screamer",
		"horde.role.brute",
	}),
})

local CommanderRuntime = table.freeze({
	auraRadiusStuds = 22,
	auraMovementSpeedMultiplier = 1.1,
	auraAttackCadenceMultiplier = 0.85,
	maximumAuraStacksPerEnemy = 1,
	bonusFieldXp = 20,
	highlightFillColor = table.freeze({ 30, 68, 150 }),
	highlightOutlineColor = table.freeze({ 104, 180, 255 }),
	highlightFillTransparency = 0.42,
	highlightOutlineTransparency = 0,
	compatibleHordeRoleIds = table.freeze({
		"horde.role.infected",
		"horde.role.runner",
		"horde.role.crawler",
	}),
})

local EliteAffixRuntimeById = table.freeze({
	[AffixIds.Armored] = ArmoredRuntime,
	[AffixIds.Frenzied] = FrenziedRuntime,
	[AffixIds.Regenerator] = RegeneratorRuntime,
	[AffixIds.Volatile] = VolatileRuntime,
	[AffixIds.Commander] = CommanderRuntime,
})

local UpgradeCatalog = table.freeze({
	table.freeze({
		upgradeId = UpgradeIds.OverpressureRounds,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "HEAVY ROUNDS",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.HairTrigger,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "FASTER FIRING",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.EchoChamber,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "AMMO SAVER",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.CullProtocol,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "FINISHER",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.PatternAmplifier,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "PATTERN AMPLIFIER",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.SpecialistMunitions,
		familyId = UpgradeFamilyIds.Firepower,
		displayName = "MONSTER HUNTER",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.CombatLoader,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "QUICK RELOAD",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.ExpandedFeed,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "BIGGER MAGAZINE",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.ScavengerReach,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "LOOT MAGNET",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.LastMagazine,
		familyId = UpgradeFamilyIds.AmmunitionReload,
		displayName = "LAST STAND",
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		upgradeId = UpgradeIds.TraumaPlating,
		familyId = UpgradeFamilyIds.Survival,
		displayName = "THICK SKIN",
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
		displayName = "FAST LEARNER",
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
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		affixId = AffixIds.Frenzied,
		displayName = "FRENZIED",
		modifierCategoryIds = table.freeze({ ModifierIds.Cadence, ModifierIds.MovementSpeed }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		affixId = AffixIds.Regenerator,
		displayName = "REGENERATOR",
		modifierCategoryIds = table.freeze({ ModifierIds.Healing }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		affixId = AffixIds.Volatile,
		displayName = "VOLATILE",
		modifierCategoryIds = table.freeze({ ModifierIds.Damage }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		affixId = AffixIds.Commander,
		displayName = "COMMANDER",
		modifierCategoryIds = table.freeze({ ModifierIds.Damage, ModifierIds.Cadence }),
		maximumPerEnemy = 1,
		requiresTelegraph = true,
		bossEligible = false,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
})

local RelicCatalog = table.freeze({
	table.freeze({
		relicId = RelicIds.BloodBattery,
		displayName = "BLOOD BATTERY",
		description = "Every 8 confirmed kills restore 6 health.",
		triggerId = TriggerIds.ConfirmedKill,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Healing }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 8,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.GraveMomentum,
		displayName = "GRAVE MOMENTUM",
		description = "Your kill-chain window lasts 1.5 seconds longer.",
		triggerId = TriggerIds.KillChainActive,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.KillChainWindow }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.ChoirBreaker,
		displayName = "CHOIR BREAKER",
		description = "Deal 30% more damage to enemies charging a special attack.",
		triggerId = TriggerIds.EnemySpecialWindup,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.SpecialEnemyDamage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.LastLight,
		displayName = "LAST LIGHT",
		description = "Deal 25% more damage while reserve ammunition is critically low.",
		triggerId = TriggerIds.LowReserveAmmunition,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Damage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.EmergencyChamber,
		displayName = "EMERGENCY CHAMBER",
		description = "Reload 25% faster while at 35% health or less.",
		triggerId = TriggerIds.ReloadAccepted,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.ReloadDuration }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.SalvagersMark,
		displayName = "SALVAGER'S MARK",
		description = "Every ammunition pickup grants 4 additional rounds.",
		triggerId = TriggerIds.AmmunitionLootResolved,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Loot }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.ExecutionProtocol,
		displayName = "EXECUTION PROTOCOL",
		description = "Deal 40% more damage to enemies below 30% health.",
		triggerId = TriggerIds.EnemyBelowHealthThreshold,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Damage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.BreachDoctrine,
		displayName = "BREACH DOCTRINE",
		description = "Shotgun cone-cleave damage gains 40% power.",
		triggerId = TriggerIds.ShotgunSecondaryImpact,
		compatibilityId = CompatibilityIds.Shotgun,
		modifierCategoryIds = table.freeze({ ModifierIds.PatternDamage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.LongwatchDoctrine,
		displayName = "LONGWATCH DOCTRINE",
		description = "Sniper pierce gains 35% damage and special enemies take 25% more.",
		triggerId = TriggerIds.SniperSecondaryImpact,
		compatibilityId = CompatibilityIds.Sniper,
		modifierCategoryIds = table.freeze({ ModifierIds.PatternDamage, ModifierIds.SpecialEnemyDamage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.SuppressionEngine,
		displayName = "SUPPRESSION ENGINE",
		description = "After 6 automatic shots, fire faster and deal 20% more damage.",
		triggerId = TriggerIds.SustainedAutomaticFire,
		compatibilityId = CompatibilityIds.Automatic,
		modifierCategoryIds = table.freeze({ ModifierIds.Cadence, ModifierIds.Damage }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 6,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.GuardianSignal,
		displayName = "GUARDIAN SIGNAL",
		description = "Revives grant both operatives temporary armor for 12 seconds.",
		triggerId = TriggerIds.TeammateRevived,
		compatibilityId = CompatibilityIds.Cooperative,
		modifierCategoryIds = table.freeze({ ModifierIds.TemporaryArmor }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 0,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		relicId = RelicIds.SecondWind,
		displayName = "SECOND WIND",
		description = "Once per expedition, lethal damage leaves you alive at 20 health.",
		triggerId = TriggerIds.IncomingIncapacitation,
		compatibilityId = CompatibilityIds.Any,
		modifierCategoryIds = table.freeze({ ModifierIds.Healing }),
		maximumStacks = 1,
		slotCost = 1,
		counterThreshold = 0,
		maximumCharges = 1,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
})

local RewardSourceCatalog = table.freeze({
	table.freeze({ sourceId = RewardSourceIds.EliteKill, implementationStateId = ImplementationStateIds.Implemented }),
	table.freeze({
		sourceId = RewardSourceIds.SpecialInterrupt,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
	table.freeze({
		sourceId = RewardSourceIds.ObjectiveCompletion,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({
		sourceId = RewardSourceIds.AuthoredContainer,
		implementationStateId = ImplementationStateIds.Planned,
	}),
	table.freeze({ sourceId = RewardSourceIds.HordeClear, implementationStateId = ImplementationStateIds.Implemented }),
	table.freeze({
		sourceId = RewardSourceIds.BossMilestone,
		implementationStateId = ImplementationStateIds.Implemented,
	}),
})

local Config = {
	Version = "RPG-0106-v1-complete-elite-roster",
	Limits = Limits,
	ModifierCeilings = ModifierCeilings,
	EliteAssignmentPlanning = EliteAssignmentPlanning,
	FrenziedRuntime = FrenziedRuntime,
	ArmoredRuntime = ArmoredRuntime,
	RegeneratorRuntime = RegeneratorRuntime,
	VolatileRuntime = VolatileRuntime,
	CommanderRuntime = CommanderRuntime,
	EliteAffixRuntimeById = EliteAffixRuntimeById,
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
assert(Limits.maximumTrackedOperativesPerOperation == 4, "the run-build owner is bounded to the four-operative MVP")
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
	ModifierCeilings.maximumIncomingDamageReduction >= 0 and ModifierCeilings.maximumIncomingDamageReduction <= 0.3,
	"incoming damage reduction must preserve enemy pressure"
)
assert(
	ModifierCeilings.maximumLootRoundsAdditiveBonus >= 0
		and ModifierCeilings.maximumLootRoundsAdditiveBonus <= 6
		and ModifierCeilings.maximumLootRoundsAdditiveBonus % 1 == 0,
	"salvaged ammunition bonuses must remain whole and tightly bounded"
)
assert(
	ModifierCeilings.maximumLootPickupRadiusBonusStuds >= 0
		and ModifierCeilings.maximumLootPickupRadiusBonusStuds <= 4.5,
	"loot pickup radius growth must remain spatially bounded"
)
assert(
	ModifierCeilings.maximumConditionalDamageMultiplier >= 1
		and ModifierCeilings.maximumConditionalDamageMultiplier <= 1.5,
	"conditional damage must remain below the global damage ceiling"
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
assert(EliteAssignmentPlanning.isRuntimeEnabled, "RPG-0106 must enable server-owned elite assignment")
assert(
	EliteAssignmentPlanning.ordinaryPressureProbability >= EliteAssignmentPlanning.ordinaryPressureProbabilityMinimum
		and EliteAssignmentPlanning.ordinaryPressureProbability
			<= EliteAssignmentPlanning.ordinaryPressureProbabilityMaximum,
	"ordinary elite runtime probability must remain inside its planning range"
)
assert(
	EliteAssignmentPlanning.hordePulseProbability >= EliteAssignmentPlanning.hordePulseProbabilityMinimum
		and EliteAssignmentPlanning.hordePulseProbability <= EliteAssignmentPlanning.hordePulseProbabilityMaximum,
	"horde elite runtime probability must remain inside its planning range"
)
assert(
	isNonnegativeInteger(EliteAssignmentPlanning.deterministicRollResolution)
		and EliteAssignmentPlanning.deterministicRollResolution >= 1000
		and EliteAssignmentPlanning.deterministicRollResolution <= 100000,
	"elite assignment requires a bounded deterministic roll resolution"
)
assert(
	FrenziedRuntime.movementSpeedMultiplier > 1
		and FrenziedRuntime.movementSpeedMultiplier <= ModifierCeilings.maximumMovementSpeedMultiplier,
	"Frenzied movement must be consequential and globally bounded"
)
assert(
	FrenziedRuntime.attackCadenceMultiplier >= ModifierCeilings.minimumCadenceMultiplier
		and FrenziedRuntime.attackCadenceMultiplier < 1,
	"Frenzied cadence must preserve a readable attack interval"
)
assert(
	FrenziedRuntime.maximumHealthMultiplier >= 0.5 and FrenziedRuntime.maximumHealthMultiplier < 1,
	"Frenzied durability tradeoff must remain survivable and consequential"
)
assert(
	isNonnegativeInteger(FrenziedRuntime.bonusFieldXp) and FrenziedRuntime.bonusFieldXp > 0,
	"Frenzied deaths require a positive bounded Field XP bonus"
)
assert(
	ArmoredRuntime.damageTakenMultiplierWhileArmored >= 0.5
		and ArmoredRuntime.damageTakenMultiplierWhileArmored < 1
		and isNonnegativeInteger(ArmoredRuntime.armorCapacity)
		and ArmoredRuntime.armorCapacity > 0,
	"Armored must reduce rather than erase damage behind finite armor"
)
assert(
	RegeneratorRuntime.damageRecoveryDelaySeconds >= 3
		and RegeneratorRuntime.healingIntervalSeconds >= 0.5
		and RegeneratorRuntime.healingPerInterval > 0
		and RegeneratorRuntime.healingPerInterval <= ModifierCeilings.maximumAutomaticHealingPerTrigger,
	"Regenerator healing must have a pressure-reset delay and bounded ticks"
)
assert(
	VolatileRuntime.deathReactionDelaySeconds >= 1
		and VolatileRuntime.deathReactionRadiusStuds > 0
		and VolatileRuntime.deathReactionRadiusStuds < 20
		and VolatileRuntime.deathReactionDamage > 0
		and VolatileRuntime.deathReactionDamage < 18,
	"Volatile must remain delayed, bounded, and distinct from the Bloater"
)
assert(
	CommanderRuntime.auraRadiusStuds > 0
		and CommanderRuntime.auraRadiusStuds <= 24
		and CommanderRuntime.auraMovementSpeedMultiplier > 1
		and CommanderRuntime.auraMovementSpeedMultiplier <= ModifierCeilings.maximumMovementSpeedMultiplier
		and CommanderRuntime.auraAttackCadenceMultiplier >= ModifierCeilings.minimumCadenceMultiplier
		and CommanderRuntime.auraAttackCadenceMultiplier < 1
		and CommanderRuntime.maximumAuraStacksPerEnemy == 1,
	"Commander aura must be spatially bounded, consequential, and non-stacking"
)
for affixId, runtime in EliteAffixRuntimeById do
	assert(RunRpgContracts.isKnownEliteAffixId(affixId), "elite runtime contains an unknown affix")
	assert(#runtime.compatibleHordeRoleIds >= 1, "every elite affix requires compatible roles")
	assert(
		isNonnegativeInteger(runtime.bonusFieldXp) and runtime.bonusFieldXp > 0 and runtime.bonusFieldXp <= 40,
		"every elite affix requires a bounded XP reward"
	)
end

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
assert(implementedUpgradeCount == 12, "the implemented catalog must match the twelve-upgrade RPG-0103 live pool")

local seenAffixIds = {}
local implementedAffixCount = 0
for _, definition in EliteAffixCatalog do
	assert(not seenAffixIds[definition.affixId], "elite affix IDs must be unique")
	seenAffixIds[definition.affixId] = true
	assert(RunRpgContracts.isKnownEliteAffixId(definition.affixId), "elite catalog contains an unknown ID")
	assert(definition.displayName ~= "", "elite affixes require display names")
	assert(definition.maximumPerEnemy == 1, "v1 affixes cannot stack on one enemy")
	assert(definition.requiresTelegraph, "every elite affix requires readable telegraphing")
	assert(not definition.bossEligible, "v1 affixes cannot be assigned to bosses")
	if definition.implementationStateId == ImplementationStateIds.Implemented then
		implementedAffixCount += 1
	else
		assert(definition.implementationStateId == ImplementationStateIds.Planned, "unknown affix implementation state")
	end
	assert(#definition.modifierCategoryIds >= 1, "every elite affix requires a declared modifier category")
end
assert(#EliteAffixCatalog == countVocabulary(AffixIds), "every elite affix ID requires exactly one catalog entry")
assert(implementedAffixCount == 5, "RPG-0106 requires the complete five-affix elite roster")

local seenRelicIds = {}
local implementedRelicCount = 0
for _, definition in RelicCatalog do
	assert(not seenRelicIds[definition.relicId], "relic IDs must be unique")
	seenRelicIds[definition.relicId] = true
	assert(RunRpgContracts.isKnownRelicId(definition.relicId), "relic catalog contains an unknown ID")
	assert(definition.displayName ~= "", "relics require display names")
	assert(
		type(definition.description) == "string" and definition.description ~= "",
		"relics require player-facing rules"
	)
	assert(definition.maximumStacks == 1, "initial relics must remain non-stackable")
	assert(definition.slotCost == 1, "initial relics must consume one slot")
	assert(isNonnegativeInteger(definition.counterThreshold), "relic counter thresholds must be whole")
	assert(isNonnegativeInteger(definition.maximumCharges), "relic charges must be whole")
	assert(
		definition.implementationStateId == ImplementationStateIds.Implemented
			or definition.implementationStateId == ImplementationStateIds.Planned,
		"relic catalog contains an invalid implementation state"
	)
	if definition.implementationStateId == ImplementationStateIds.Implemented then
		implementedRelicCount += 1
	end
	assert(#definition.modifierCategoryIds >= 1, "every relic requires a modifier category")
end
assert(#RelicCatalog == countVocabulary(RelicIds), "every relic ID requires exactly one catalog entry")
assert(
	implementedRelicCount == #RelicCatalog,
	"every declared relic must carry a runtime effect now that RPG-0108 and RPG-0109 are implemented"
)

local seenRewardSourceIds = {}
local implementedRewardSourceCount = 0
for _, definition in RewardSourceCatalog do
	assert(not seenRewardSourceIds[definition.sourceId], "reward source IDs must be unique")
	seenRewardSourceIds[definition.sourceId] = true
	assert(
		definition.implementationStateId == ImplementationStateIds.Implemented
			or definition.implementationStateId == ImplementationStateIds.Planned,
		"reward source catalog contains an invalid implementation state"
	)
	if definition.implementationStateId == ImplementationStateIds.Implemented then
		implementedRewardSourceCount += 1
	end
end
-- RPG-0110 connects the original three live sources. First Descent now also
-- consumes BossMilestone through the authoritative Boss -> Rewards transition;
-- authored objectives and authored containers remain planned.
assert(implementedRewardSourceCount == 4, "exactly the live reward sources may be implemented")
assert(#RewardSourceCatalog == countVocabulary(RewardSourceIds), "every reward source requires one catalog entry")

return table.freeze(Config)
