--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contractsPath = "games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"
local configPath = "games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"

local contracts = luau.load(fs.readFile(contractsPath), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile(configPath), {
	debugName = "RunRpgConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					RPG = {
						RunRpgContracts = CONTRACTS_TOKEN,
					},
				},
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			error("unexpected RunRpgConfig dependency", 2)
		end,
	},
	injectGlobals = true,
})()

assertThat(
	contracts.RunUpgradeIds.OverpressureRounds == "upgrade.overpressure_rounds",
	"existing upgrade ID must remain stable"
)
assertThat(
	contracts.RunUpgradeIds.FieldDiscipline == "upgrade.field_discipline",
	"planned upgrade ID must remain stable"
)
assertThat(contracts.EliteAffixIds.Frenzied == "elite-affix.frenzied", "Frenzied affix ID must remain stable")
assertThat(contracts.EliteAffixIds.Commander == "elite-affix.commander", "Commander affix ID must remain stable")
assertThat(contracts.RelicIds.BloodBattery == "relic.blood_battery", "Blood Battery ID must remain stable")
assertThat(contracts.RelicIds.SecondWind == "relic.second_wind", "Second Wind ID must remain stable")
assertThat(contracts.RewardSourceIds.EliteKill == "reward-source.elite-kill", "elite reward source must remain stable")
assertThat(
	contracts.RunBuildNetworkOperationIds.Snapshot == "Snapshot",
	"run-build snapshot operation must remain stable"
)
assertThat(
	contracts.RunRpgRejectionReasonIds.RelicNotOffered == "RelicNotOffered",
	"offer rejection must remain stable"
)
assertThat(contracts.EffectStateIds.Starting == nil, "unused Starting state must not enter the initial RPG vocabulary")

local contractsMutationSucceeded = pcall(function()
	contracts.RelicIds.SecondWind = "forged"
end)
assertThat(not contractsMutationSucceeded, "RPG contract vocabularies must be frozen")

assertThat(config.Version == "RPG-0105-v1-frenzied-elite", "RPG config version must identify the Frenzied elite slice")
assertThat(config.Limits.maximumEquippedRelicsPerOperative == 3, "the initial build must have three relic slots")
assertThat(config.Limits.relicChoiceCountPerReward == 2, "relic rewards must present two choices")
assertThat(config.Limits.maximumQueuedRelicRewardsPerOperative == 3, "pending reward queues must be bounded")
assertThat(config.Limits.maximumSimultaneousElites == 3, "simultaneous elites must be bounded")
assertThat(config.Limits.maximumAffixesPerEnemy == 1, "v1 enemies may have only one affix")
assertThat(config.ModifierCeilings.maximumDamageMultiplier == 3, "RPG damage must preserve the existing ceiling")
assertThat(config.ModifierCeilings.minimumCadenceMultiplier == 0.55, "RPG cadence must preserve the existing floor")
assertThat(
	config.ModifierCeilings.maximumAmmunitionConservationChance == 0.5,
	"ammo conservation must preserve scarcity"
)
assertThat(config.ModifierCeilings.maximumMovementSpeedMultiplier == 1.35, "movement growth must remain bounded")
assertThat(config.ModifierCeilings.minimumReloadDurationMultiplier == 0.5, "reload commitment must remain meaningful")
assertThat(
	config.ModifierCeilings.maximumTemporaryArmorFractionOfMaximumHealth == 0.4,
	"temporary armor must be health-relative and bounded"
)
assertThat(config.ModifierCeilings.maximumKillChainExtensionSeconds == 2, "kill-chain extension must be bounded")
assertThat(config.ModifierCeilings.maximumGeneralProcChance == 0.35, "general proc chance must be bounded")
assertThat(config.ModifierCeilings.maximumIncomingDamageReduction == 0.3, "damage reduction must be bounded")
assertThat(config.ModifierCeilings.maximumLootPickupRadiusBonusStuds == 4.5, "pickup radius must be bounded")
assertThat(config.ModifierCeilings.maximumConditionalDamageMultiplier == 1.5, "conditional damage must be bounded")
assertThat(config.EliteAssignmentPlanning.isRuntimeEnabled, "RPG-0105 must enable elite assignment")
assertThat(
	config.EliteAssignmentPlanning.ordinaryPressureProbability == 0.05
		and config.EliteAssignmentPlanning.hordePulseProbability == 0.07,
	"runtime elite probabilities must remain inside their planned bands"
)
assertThat(config.FrenziedRuntime.movementSpeedMultiplier == 1.25, "Frenzied movement tuning drifted")
assertThat(config.FrenziedRuntime.attackCadenceMultiplier == 0.7, "Frenzied cadence tuning drifted")
assertThat(config.FrenziedRuntime.maximumHealthMultiplier == 0.85, "Frenzied durability tradeoff drifted")
assertThat(config.FrenziedRuntime.bonusFieldXp == 20, "Frenzied XP reward drifted")

assertThat(#config.UpgradeCatalog == 17, "the planned RPG upgrade vocabulary must contain seventeen definitions")
assertThat(#config.EliteAffixCatalog == 5, "the initial elite vocabulary must contain five affixes")
assertThat(#config.RelicCatalog == 12, "the initial relic vocabulary must contain twelve relics")
assertThat(#config.RewardSourceCatalog == 6, "the RPG reward vocabulary must contain six sources")

local implementedUpgradeCount = 0
local seenUpgradeIds = {}
for _, definition in config.UpgradeCatalog do
	assertThat(not seenUpgradeIds[definition.upgradeId], "upgrade catalog IDs must be unique")
	seenUpgradeIds[definition.upgradeId] = true
	if definition.implementationStateId == contracts.ImplementationStateIds.Implemented then
		implementedUpgradeCount += 1
	end
end
assertThat(implementedUpgradeCount == 12, "the twelve live RPG-0103 upgrades must be marked implemented")

local implementedAffixCount = 0
for _, definition in config.EliteAffixCatalog do
	assertThat(definition.maximumPerEnemy == 1, "elite definitions must preserve one-affix v1")
	assertThat(definition.requiresTelegraph, "every elite affix must require a telegraph")
	assertThat(not definition.bossEligible, "initial elite affixes must exclude bosses")
	if definition.implementationStateId == contracts.ImplementationStateIds.Implemented then
		implementedAffixCount += 1
		assertThat(definition.affixId == contracts.EliteAffixIds.Frenzied, "only Frenzied may be implemented")
	else
		assertThat(definition.implementationStateId == contracts.ImplementationStateIds.Planned, "invalid affix state")
	end
end
assertThat(implementedAffixCount == 1, "RPG-0105 must implement exactly one affix")

local relicById = {}
for _, definition in config.RelicCatalog do
	assertThat(relicById[definition.relicId] == nil, "relic catalog IDs must be unique")
	relicById[definition.relicId] = definition
	assertThat(definition.maximumStacks == 1, "initial relics must be non-stackable")
	assertThat(definition.slotCost == 1, "initial relics must consume one slot")
	assertThat(
		definition.implementationStateId == contracts.ImplementationStateIds.Planned,
		"relics must remain planned"
	)
end
assertThat(
	relicById[contracts.RelicIds.BloodBattery].counterThreshold == 8,
	"Blood Battery must declare its bounded kill counter"
)
assertThat(
	relicById[contracts.RelicIds.SecondWind].maximumCharges == 1,
	"Second Wind must declare one operation charge"
)
assertThat(
	relicById[contracts.RelicIds.BreachDoctrine].compatibilityId == contracts.RelicCompatibilityIds.Shotgun,
	"Breach Doctrine must remain shotgun-specific"
)
assertThat(
	relicById[contracts.RelicIds.LongwatchDoctrine].compatibilityId == contracts.RelicCompatibilityIds.Sniper,
	"Longwatch Doctrine must remain sniper-specific"
)

assertThat(
	contracts.validateRelicChoiceIntent({
		requestId = "request-1",
		operationGeneration = 2,
		rewardSequence = 7,
		relicId = contracts.RelicIds.BloodBattery,
	}),
	"minimal relic choice intent must validate"
)
assertThat(
	contracts.validateRelicChoiceIntent({
		requestId = "request-unknown",
		operationGeneration = 2,
		rewardSequence = 7,
		relicId = "unknown-relic",
	}),
	"shape validation must preserve UnknownRelic resolver feedback"
)
assertThat(not contracts.validateRelicChoiceIntent({
	requestId = "request-forged",
	operationGeneration = 2,
	rewardSequence = 7,
	relicId = contracts.RelicIds.BloodBattery,
	operativeEntityId = "forged",
}), "relic choice intent must reject extra identity fields")
assertThat(
	contracts.validateRelicReplacementIntent({
		requestId = "request-2",
		operationGeneration = 2,
		rewardSequence = 8,
		relicId = contracts.RelicIds.SecondWind,
		replaceSlotIndex = 2,
	}),
	"minimal replacement intent must validate"
)
assertThat(not contracts.validateRelicReplacementIntent({
	requestId = "request-3",
	operationGeneration = 2,
	rewardSequence = 8,
	relicId = contracts.RelicIds.SecondWind,
	replaceSlotIndex = 0,
}), "replacement slot indices must be positive")

local validSnapshot = {
	operationId = contracts.RunBuildNetworkOperationIds.Snapshot,
	operationGeneration = 3,
	revision = 4,
	replacementStateId = contracts.ReplacementStateIds.None,
	upgradeStacks = {
		[contracts.RunUpgradeIds.OverpressureRounds] = 2,
	},
	relicSlots = {
		{
			slotIndex = 1,
			slotStateId = contracts.RelicSlotStateIds.Equipped,
			relicId = contracts.RelicIds.BloodBattery,
			effectStateId = contracts.EffectStateIds.Ready,
			chargeCount = 0,
			counterValue = 3,
			cooldownEndServerTimestamp = nil,
			revision = 1,
		},
		{
			slotIndex = 2,
			slotStateId = contracts.RelicSlotStateIds.Empty,
			relicId = nil,
			effectStateId = contracts.EffectStateIds.Inactive,
			chargeCount = 0,
			counterValue = 0,
			cooldownEndServerTimestamp = nil,
			revision = 0,
		},
		{
			slotIndex = 3,
			slotStateId = contracts.RelicSlotStateIds.Empty,
			relicId = nil,
			effectStateId = contracts.EffectStateIds.Inactive,
			chargeCount = 0,
			counterValue = 0,
			cooldownEndServerTimestamp = nil,
			revision = 0,
		},
	},
	pendingRewards = {
		{
			rewardSequence = 9,
			sourceId = contracts.RewardSourceIds.EliteKill,
			stateId = contracts.RewardChoiceStateIds.Pending,
			offeredRelicIds = {
				contracts.RelicIds.ChoirBreaker,
				contracts.RelicIds.LastLight,
			},
			expiresAtServerTimestamp = nil,
		},
	},
}
assertThat(contracts.validateSafeRunBuildSnapshot(validSnapshot), "valid run-build snapshot must validate")

local duplicateRelicSnapshot = table.clone(validSnapshot)
duplicateRelicSnapshot.relicSlots = {
	validSnapshot.relicSlots[1],
	{
		slotIndex = 2,
		slotStateId = contracts.RelicSlotStateIds.Equipped,
		relicId = contracts.RelicIds.BloodBattery,
		effectStateId = contracts.EffectStateIds.Ready,
		chargeCount = 0,
		counterValue = 0,
		cooldownEndServerTimestamp = nil,
		revision = 1,
	},
}
assertThat(
	not contracts.validateSafeRunBuildSnapshot(duplicateRelicSnapshot),
	"safe snapshots must reject duplicate equipped relics"
)

assertThat(
	contracts.validateSafeRunBuildRejection({
		operationId = contracts.RunBuildNetworkOperationIds.Rejected,
		operationGeneration = 3,
		revision = 4,
		rejectionReasonId = contracts.RunRpgRejectionReasonIds.RelicNotOffered,
		requestId = "request-4",
		rewardSequence = 9,
	}),
	"safe RPG rejection must validate"
)

local configMutationSucceeded = pcall(function()
	config.Limits.maximumEquippedRelicsPerOperative = 99
end)
assertThat(not configMutationSucceeded, "RPG limits must be frozen")

local combinedDeclarations = fs.readFile(contractsPath) .. "\n" .. fs.readFile(configPath)
for _, forbidden in
	{
		"game:GetService",
		"Instance.new",
		"RemoteEvent",
		"RemoteFunction",
		"Heartbeat",
		"RenderStepped",
		"task.delay",
		"task.spawn",
		"FireServer",
		"FireClient",
		"OnServerEvent",
		"DataStoreService",
	}
do
	assertThat(
		not string.find(combinedDeclarations, forbidden, 1, true),
		"RPG declarations must not contain " .. forbidden
	)
end
