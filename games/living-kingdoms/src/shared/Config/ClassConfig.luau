--!strict

--[[
	P7-0101 declaration-only starting values for the three MVP specialist
	classes. Runtime tasks may tune these configuration-backed values, but this
	module owns no assignment, action, health, ammunition, timer, or network state.

	Engineer resupply values remain provisional while the deferred P6 Studio
	evidence matrix is unavailable. They must be revisited before P7 gameplay
	balance is signed off.
]]

local ClassContracts = require(script.Parent.Parent.Classes.ClassContracts)
local AmmunitionScarcityConfig = require(script.Parent.AmmunitionScarcityConfig)
local OperativeLifeConfig = require(script.Parent.OperativeLifeConfig)

local ClassIds = ClassContracts.ClassIds
local ActionIds = ClassContracts.ClassActionIds
local TargetKindIds = ClassContracts.ClassTargetKindIds
local ResourceIds = ClassContracts.ClassResourceIds

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isFinitePositive(value: number): boolean
	return isFinite(value) and value > 0
end

local function isNonnegativeInteger(value: number): boolean
	return isFinite(value) and value >= 0 and value % 1 == 0
end

local Resources = table.freeze({
	MedicalCharge = table.freeze({
		resourceId = ResourceIds.MedicalCharge,
		maximumAmount = 3,
	}),
	ResupplyCharge = table.freeze({
		resourceId = ResourceIds.ResupplyCharge,
		maximumAmount = 2,
	}),
})

local Actions = table.freeze({
	Brace = table.freeze({
		actionId = ActionIds.Brace,
		classId = ClassIds.CombatSpecialist,
		targetKindId = TargetKindIds.None,
		durationSeconds = 6,
		cooldownSeconds = 14,
		movementToleranceStuds = 1.5,
		cadenceIntervalMultiplier = 0.85,
		targetRetentionGraceSeconds = 0.35,
	}),
	FieldTreatment = table.freeze({
		actionId = ActionIds.FieldTreatment,
		classId = ClassIds.Medic,
		targetKindId = TargetKindIds.AliveTeammate,
		resourceId = ResourceIds.MedicalCharge,
		resourceCost = 1,
		channelDurationSeconds = 3,
		cooldownSeconds = 4,
		maximumRangeStuds = OperativeLifeConfig.ReviveRangeStuds,
		movementToleranceStuds = 1.5,
		healAmount = 25,
	}),
	ReviveAssistance = table.freeze({
		actionId = ActionIds.ReviveAssistance,
		classId = ClassIds.Medic,
		targetKindId = TargetKindIds.IncapacitatedTeammate,
		reviveDurationMultiplier = 0.75,
		restoredHealth = 40,
	}),
	FieldResupply = table.freeze({
		actionId = ActionIds.FieldResupply,
		classId = ClassIds.Engineer,
		targetKindId = TargetKindIds.SelfOrAliveTeammate,
		resourceId = ResourceIds.ResupplyCharge,
		resourceCost = 1,
		channelDurationSeconds = 2.5,
		cooldownSeconds = 6,
		maximumRangeStuds = 8,
		movementToleranceStuds = 1.5,
		roundsPerCharge = AmmunitionScarcityConfig.BasicFirearm.AuthoredCacheRounds,
		isScarcityTuningProvisional = true,
	}),
})

local ClassDefinitions = table.freeze({
	table.freeze({
		classId = ClassIds.CombatSpecialist,
		displayName = "Combat Specialist",
		actionIds = table.freeze({ ActionIds.Brace }),
		resourceIds = table.freeze({}),
	}),
	table.freeze({
		classId = ClassIds.Medic,
		displayName = "Medic",
		actionIds = table.freeze({ ActionIds.FieldTreatment, ActionIds.ReviveAssistance }),
		resourceIds = table.freeze({ ResourceIds.MedicalCharge }),
	}),
	table.freeze({
		classId = ClassIds.Engineer,
		displayName = "Engineer",
		actionIds = table.freeze({ ActionIds.FieldResupply }),
		resourceIds = table.freeze({ ResourceIds.ResupplyCharge }),
	}),
})

local Config = {
	Version = "P7-0101-v1",
	Selection = table.freeze({
		allowDuplicateStartingClasses = true,
		startingClassIds = table.freeze({
			ClassIds.CombatSpecialist,
			ClassIds.Medic,
			ClassIds.Engineer,
		}),
	}),
	Resources = Resources,
	Actions = Actions,
	ClassDefinitions = ClassDefinitions,
}

local seenClassIds = {}
local seenActionIds = {}
local seenResourceIds = {}

for _, definition in ClassDefinitions do
	assert(not seenClassIds[definition.classId], "starting class IDs must be unique")
	seenClassIds[definition.classId] = true
	assert(definition.displayName ~= "", "starting classes require a display name")
	assert(#definition.actionIds > 0, "every starting class requires at least one action")
	for _, actionId in definition.actionIds do
		assert(not seenActionIds[actionId], "class action IDs must belong to exactly one starting class")
		seenActionIds[actionId] = true
	end
	for _, resourceId in definition.resourceIds do
		assert(not seenResourceIds[resourceId], "class resource IDs must belong to exactly one starting class")
		seenResourceIds[resourceId] = true
	end
end

for _, classId in Config.Selection.startingClassIds do
	assert(seenClassIds[classId], "every starting class ID requires one definition")
end

assert(Config.Selection.allowDuplicateStartingClasses, "MVP starting-class duplication must remain allowed")

assert(isFinitePositive(Actions.Brace.durationSeconds), "Brace duration must be finite and positive")
assert(isFinitePositive(Actions.Brace.cooldownSeconds), "Brace cooldown must be finite and positive")
assert(isFinitePositive(Actions.Brace.movementToleranceStuds), "Brace movement tolerance must be positive")
assert(
	isFinitePositive(Actions.Brace.cadenceIntervalMultiplier) and Actions.Brace.cadenceIntervalMultiplier <= 1,
	"Brace cadence multiplier must be in (0, 1]"
)
assert(Actions.Brace.targetRetentionGraceSeconds >= 0, "Brace retention grace must be nonnegative")

assert(isNonnegativeInteger(Resources.MedicalCharge.maximumAmount), "medical charges must be a whole amount")
assert(Resources.MedicalCharge.maximumAmount > 0, "medical charges must be finite")
assert(isFinitePositive(Actions.FieldTreatment.channelDurationSeconds), "treatment channel must be positive")
assert(isFinitePositive(Actions.FieldTreatment.cooldownSeconds), "treatment cooldown must be positive")
assert(isFinitePositive(Actions.FieldTreatment.maximumRangeStuds), "treatment range must be positive")
assert(isFinitePositive(Actions.FieldTreatment.healAmount), "treatment heal must be positive")
assert(Actions.FieldTreatment.healAmount <= OperativeLifeConfig.MaximumHealth, "treatment heal exceeds max health")
assert(Actions.FieldTreatment.resourceCost <= Resources.MedicalCharge.maximumAmount, "treatment cost exceeds supply")
assert(
	isFinitePositive(Actions.ReviveAssistance.reviveDurationMultiplier)
		and Actions.ReviveAssistance.reviveDurationMultiplier <= 1,
	"medic revive duration multiplier must be in (0, 1]"
)
assert(
	Actions.ReviveAssistance.restoredHealth >= OperativeLifeConfig.ReviveHealth
		and Actions.ReviveAssistance.restoredHealth <= OperativeLifeConfig.MaximumHealth,
	"medic revive health must improve the base revive without exceeding maximum health"
)

assert(isNonnegativeInteger(Resources.ResupplyCharge.maximumAmount), "resupply charges must be a whole amount")
assert(Resources.ResupplyCharge.maximumAmount > 0, "resupply charges must be finite")
assert(isFinitePositive(Actions.FieldResupply.channelDurationSeconds), "resupply channel must be positive")
assert(isFinitePositive(Actions.FieldResupply.cooldownSeconds), "resupply cooldown must be positive")
assert(isFinitePositive(Actions.FieldResupply.maximumRangeStuds), "resupply range must be positive")
assert(isNonnegativeInteger(Actions.FieldResupply.roundsPerCharge), "resupply rounds must be whole")
assert(Actions.FieldResupply.roundsPerCharge > 0, "resupply must grant positive rounds")
assert(
	Actions.FieldResupply.roundsPerCharge <= AmmunitionScarcityConfig.BasicFirearm.MaximumReserveRounds,
	"one resupply charge must fit the reserve cap"
)
assert(Actions.FieldResupply.resourceCost <= Resources.ResupplyCharge.maximumAmount, "resupply cost exceeds supply")
assert(Actions.FieldResupply.isScarcityTuningProvisional, "engineer scarcity tuning must remain provisional")

return table.freeze(Config)
