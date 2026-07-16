--!strict

-- Standalone declaration/configuration fixtures for LK-0301. Production
-- modules are loaded without Roblox runtime or any server/client bootstrap.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local contractsPath = "games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau"
local configPath = "games/living-kingdoms/src/shared/Config/OperativeLifeConfig.luau"
local combatContractsPath = "games/living-kingdoms/src/shared/Combat/CombatContracts.luau"
local firearmConfigPath = "games/living-kingdoms/src/shared/Config/FirearmConfig.luau"

local function loadStandalone(path: string, debugName: string)
	local loader = luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})
	return loader()
end

local contracts = loadStandalone(contractsPath, "OperativeLifeContracts")
local config = loadStandalone(configPath, "OperativeLifeConfig")

local expectedLifeStateIds = {
	Alive = "Alive",
	Incapacitated = "Incapacitated",
	Dead = "Dead",
}
local lifeStateCount = 0
for key, value in contracts.OperativeLifeStateIds do
	lifeStateCount += 1
	assert(expectedLifeStateIds[key] == value, "unexpected operative life-state ID")
end
assert(lifeStateCount == 3, "operative life-state vocabulary must contain exactly three IDs")
assert(table.isfrozen(contracts), "contract module must be frozen")
assert(table.isfrozen(contracts.OperativeLifeStateIds), "operative life-state IDs must be frozen")
assert(
	table.isfrozen(contracts.OperativeLifeTransitionRejectionReasonIds),
	"operative transition rejection IDs must be frozen"
)
assert(table.isfrozen(contracts.ReviveSessionStatusIds), "revive status IDs must be frozen")
assert(table.isfrozen(contracts.ReviveRejectionReasonIds), "revive rejection IDs must be frozen")

local function assertExactIds(actual: { [string]: string }, expected: { [string]: string }, context: string)
	local count = 0
	for key, value in actual do
		count += 1
		assert(expected[key] == value, context .. ": unexpected ID")
	end
	local expectedCount = 0
	for _ in expected do
		expectedCount += 1
	end
	assert(count == expectedCount, context .. ": wrong ID count")
end

assertExactIds(contracts.OperativeLifeTransitionRejectionReasonIds, {
	InvalidSnapshot = "InvalidSnapshot",
	InvalidHealth = "InvalidHealth",
	InvalidDamage = "InvalidDamage",
	InvalidServerTimestamp = "InvalidServerTimestamp",
	IllegalTransition = "IllegalTransition",
	StaleTransition = "StaleTransition",
	AlreadyResolved = "AlreadyResolved",
}, "operative transition rejection reasons")
assertExactIds(contracts.ReviveSessionStatusIds, {
	Active = "Active",
	Cancelled = "Cancelled",
	Completed = "Completed",
}, "revive session statuses")
assertExactIds(contracts.ReviveRejectionReasonIds, {
	ReviverNotAlive = "ReviverNotAlive",
	TargetNotIncapacitated = "TargetNotIncapacitated",
	SameOperative = "SameOperative",
	TargetBusy = "TargetBusy",
	OutOfRange = "OutOfRange",
	NoLineOfSight = "NoLineOfSight",
	SessionNotActive = "SessionNotActive",
	ReviveNotComplete = "ReviveNotComplete",
	ReviveInterrupted = "ReviveInterrupted",
	InvalidServerTimestamp = "InvalidServerTimestamp",
}, "revive rejection reasons")

local expectedConfig = {
	MaximumHealth = 100,
	BleedOutDurationSeconds = 30,
	ReviveRangeStuds = 8,
	ReviveDurationSeconds = 4,
	ReviveHealth = 30,
	SoloRecoveryDurationSeconds = 8,
	SoloRecoveriesPerOperation = 1,
	SquadFailureGraceSeconds = 3,
}
local configValueCount = 0
for key, value in config do
	configValueCount += 1
	assert(expectedConfig[key] == value, "unexpected operative life configuration value")
end
assert(configValueCount == 8, "operative life configuration must contain exactly eight values")
assert(table.isfrozen(config), "operative life configuration must be frozen")
assert(config.MaximumHealth > 0, "MaximumHealth must be positive")
assert(config.ReviveHealth > 0 and config.ReviveHealth <= config.MaximumHealth, "ReviveHealth is invalid")
for _, duration in
	{
		config.BleedOutDurationSeconds,
		config.ReviveDurationSeconds,
		config.SoloRecoveryDurationSeconds,
		config.SquadFailureGraceSeconds,
	}
do
	assert(duration == duration and duration ~= math.huge and duration > 0, "duration must be positive and finite")
end
assert(
	config.ReviveRangeStuds == config.ReviveRangeStuds
		and config.ReviveRangeStuds ~= math.huge
		and config.ReviveRangeStuds > 0,
	"ReviveRangeStuds must be positive and finite"
)
assert(config.SoloRecoveriesPerOperation == 1, "SoloRecoveriesPerOperation must be exactly one")

type OperativeHealthState = {
	currentHealth: number,
	maximumHealth: number,
}
type IncapacitationState = {
	startedAtServerTimestamp: number,
	bleedOutDeadlineServerTimestamp: number,
}
type SoloRecoveryState = {
	isEligible: boolean,
	recoveriesUsed: number,
	recoveryStartedAtServerTimestamp: number?,
	recoveryCompletionServerTimestamp: number?,
}
type OperativeLifeStateSnapshot = {
	operativeEntityId: string,
	lifeStateId: "Alive" | "Incapacitated" | "Dead",
	healthState: OperativeHealthState,
	incapacitationState: IncapacitationState?,
	soloRecoveryState: SoloRecoveryState,
	processedDamageEventIds: { [string]: boolean },
}
type OperativeLifeTransitionResult = {
	didTransition: boolean,
	rejectionReasonId: string?,
	lifeStateIdBefore: ("Alive" | "Incapacitated" | "Dead")?,
	lifeStateIdAfter: ("Alive" | "Incapacitated" | "Dead")?,
	transitionServerTimestamp: number?,
	damageEventId: string?,
	snapshotAfter: OperativeLifeStateSnapshot,
}
type ReviveSessionState = {
	reviverOperativeEntityId: string,
	targetOperativeEntityId: string,
	statusId: "Active" | "Cancelled" | "Completed",
	startedAtServerTimestamp: number,
	completionServerTimestamp: number,
}
type ReviveTransitionResult = {
	didTransition: boolean,
	rejectionReasonId: string?,
	sessionStateAfter: ReviveSessionState?,
	targetSnapshotAfter: OperativeLifeStateSnapshot,
}
type SquadViabilitySnapshot = {
	activeOperativeCount: number,
	hasAliveOperative: boolean,
	hasPendingSoloRecovery: boolean,
	isViable: boolean,
	failureGraceStartedAtServerTimestamp: number?,
	failureDeadlineServerTimestamp: number?,
}

local representativeSnapshot: OperativeLifeStateSnapshot = {
	operativeEntityId = "operative.alpha",
	lifeStateId = "Incapacitated",
	healthState = { currentHealth = 0, maximumHealth = config.MaximumHealth },
	incapacitationState = {
		startedAtServerTimestamp = 10,
		bleedOutDeadlineServerTimestamp = 10 + config.BleedOutDurationSeconds,
	},
	soloRecoveryState = {
		isEligible = true,
		recoveriesUsed = 0,
		recoveryStartedAtServerTimestamp = 10,
		recoveryCompletionServerTimestamp = 10 + config.SoloRecoveryDurationSeconds,
	},
	processedDamageEventIds = {},
}
local representativeTransition: OperativeLifeTransitionResult = {
	didTransition = true,
	rejectionReasonId = nil,
	lifeStateIdBefore = "Alive",
	lifeStateIdAfter = "Incapacitated",
	transitionServerTimestamp = 10,
	damageEventId = "damage.fixture",
	snapshotAfter = representativeSnapshot,
}
local representativeRevive: ReviveTransitionResult = {
	didTransition = false,
	rejectionReasonId = "ReviveNotComplete",
	sessionStateAfter = {
		reviverOperativeEntityId = "operative.bravo",
		targetOperativeEntityId = representativeSnapshot.operativeEntityId,
		statusId = "Active",
		startedAtServerTimestamp = 11,
		completionServerTimestamp = 11 + config.ReviveDurationSeconds,
	},
	targetSnapshotAfter = representativeSnapshot,
}
local representativeViability: SquadViabilitySnapshot = {
	activeOperativeCount = 1,
	hasAliveOperative = false,
	hasPendingSoloRecovery = true,
	isViable = true,
	failureGraceStartedAtServerTimestamp = nil,
	failureDeadlineServerTimestamp = nil,
}
assert(representativeTransition.snapshotAfter == representativeSnapshot, "representative transition did not load")
assert(representativeRevive.sessionStateAfter ~= nil, "representative revive session did not load")
assert(representativeViability.isViable, "representative squad viability did not load")
assert(not table.isfrozen(representativeSnapshot), "runtime snapshots must remain mutable values")
assert(not table.isfrozen(representativeSnapshot.healthState), "runtime health state must remain mutable")

local contractsReloaded = loadStandalone(contractsPath, "OperativeLifeContractsReloaded")
local configReloaded = loadStandalone(configPath, "OperativeLifeConfigReloaded")
for _, tableName in
	{
		"OperativeLifeStateIds",
		"OperativeLifeTransitionRejectionReasonIds",
		"ReviveSessionStatusIds",
		"ReviveRejectionReasonIds",
	}
do
	for key, value in contracts[tableName] do
		assert(contractsReloaded[tableName][key] == value, tableName .. " changed across loads")
	end
end
for key, value in config do
	assert(configReloaded[key] == value, "configuration changed across loads")
end

local combatContracts = loadStandalone(combatContractsPath, "CombatContracts")
local COMBAT_CONTRACTS_TOKEN = {}
local firearmLoader = luau.load(fs.readFile(firearmConfigPath), {
	debugName = "FirearmConfig",
	environment = {
		script = { Parent = { Parent = { Combat = { CombatContracts = COMBAT_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == COMBAT_CONTRACTS_TOKEN, "unexpected FirearmConfig dependency")
			return combatContracts
		end,
	},
	injectGlobals = true,
})
local firearmConfig = firearmLoader()
assert(combatContracts.OperativeCombatStateIds.Ready == "Ready", "P2 combat contract changed")
assert(combatContracts.OperativeCombatStateIds.Incapacitated == "Incapacitated", "P2 combat state changed")
assert(firearmConfig.BasicFirearm.WeaponId == "weapon.basic_firearm", "P2 weapon ID changed")
assert(firearmConfig.BasicFirearm.DamageTypeId == "Ballistic", "P2 damage type changed")
assert(firearmConfig.BasicFirearm.RangeStuds == 80, "P2 range changed")
assert(firearmConfig.BasicFirearm.CadenceSeconds == 0.2, "P2 cadence changed")
assert(firearmConfig.BasicFirearm.MagazineCapacity == 12, "P2 magazine capacity changed")
assert(firearmConfig.BasicFirearm.PrototypeInitialLoadedRounds == 12, "P2 loaded rounds changed")
assert(firearmConfig.BasicFirearm.PrototypeInitialReserveRounds == 24, "P2 reserve rounds changed")
assert(firearmConfig.BasicFirearm.ReloadDurationSeconds == 2, "P2 reload duration changed")
assert(firearmConfig.BasicFirearm.DamagePerHit == 20, "P2 damage changed")

print(
	"OperativeLifeContracts: vocabulary, frozen IDs/config, invariants, shapes, reload stability, and P2 compatibility passed"
)
