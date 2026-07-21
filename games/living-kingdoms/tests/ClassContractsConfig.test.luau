--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contractsPath = "games/living-kingdoms/src/shared/Classes/ClassContracts.luau"
local configPath = "games/living-kingdoms/src/shared/Config/ClassConfig.luau"

local contracts = luau.load(fs.readFile(contractsPath), {
	debugName = "ClassContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local AMMUNITION_CONFIG_TOKEN = {}
local LIFE_CONFIG_TOKEN = {}
local MISSION_CONTRACTS_TOKEN = {}

local ammunitionConfig = {
	BasicFirearm = {
		InitialLoadedRounds = 12,
		InitialReserveRounds = 24,
		MaximumReserveRounds = 48,
		AuthoredCacheRounds = 12,
	},
}

local lifeConfig = {
	MaximumHealth = 100,
	ReviveRangeStuds = 8,
	ReviveDurationSeconds = 4,
	ReviveHealth = 30,
}

local missionContracts = {
	MissionPhaseIds = {
		Insertion = "Insertion",
		Infiltration = "Infiltration",
		Resolved = "Resolved",
	},
}

local config = luau.load(fs.readFile(configPath), {
	debugName = "ClassConfig",
	environment = {
		script = {
			Parent = {
				AmmunitionScarcityConfig = AMMUNITION_CONFIG_TOKEN,
				OperativeLifeConfig = LIFE_CONFIG_TOKEN,
				Parent = {
					Classes = {
						ClassContracts = CONTRACTS_TOKEN,
					},
					Mission = {
						MissionContracts = MISSION_CONTRACTS_TOKEN,
					},
				},
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == AMMUNITION_CONFIG_TOKEN then
				return ammunitionConfig
			elseif token == LIFE_CONFIG_TOKEN then
				return lifeConfig
			elseif token == MISSION_CONTRACTS_TOKEN then
				return missionContracts
			end
			error("unexpected ClassConfig dependency", 2)
		end,
	},
	injectGlobals = true,
})()

assertThat(contracts.ClassIds.CombatSpecialist == "class.combat-specialist", "combat class ID must be stable")
assertThat(contracts.ClassIds.Medic == "class.medic", "medic class ID must be stable")
assertThat(contracts.ClassIds.Engineer == "class.engineer", "engineer class ID must be stable")
assertThat(contracts.ClassActionIds.Brace == "class-action.brace", "Brace ID must be stable")
assertThat(contracts.ClassActionIds.FieldTreatment == "class-action.field-treatment", "treatment ID must be stable")
assertThat(contracts.ClassActionIds.ReviveAssistance == "class-action.revive-assistance", "revive ID must be stable")
assertThat(contracts.ClassActionIds.FieldResupply == "class-action.field-resupply", "resupply ID must be stable")
assertThat(contracts.ClassSelectionNetworkOperationIds.Snapshot == "Snapshot", "snapshot operation ID must be stable")
assertThat(contracts.ClassSelectionNetworkOperationIds.Rejected == "Rejected", "rejection operation ID must be stable")
assertThat(contracts.ClassActionRejectionReasonIds.RateLimited == "RateLimited", "rate-limit reason must be stable")
assertThat(contracts.ClassActionStateIds.Starting == nil, "unused Starting state must not enter the initial vocabulary")

local contractsMutationSucceeded = pcall(function()
	contracts.ClassIds.Engineer = "forged"
end)
assertThat(not contractsMutationSucceeded, "class ID vocabulary must be frozen")

assertThat(config.Version == "P7-0104-v1-medic", "class config version must identify medic integration")
assertThat(config.ActionRequests.minimumRequestIntervalSeconds == 0.15, "action rate limit must be configured")
assertThat(config.ActionRequests.maximumProcessedRequestIdsPerOperative == 64, "action replay history must be bounded")
assertThat(config.Selection.allowDuplicateStartingClasses, "duplicate starting classes must remain allowed")
assertThat(
	config.Selection.defaultClassId == contracts.ClassIds.CombatSpecialist,
	"fallback class must be deterministic"
)
assertThat(config.Selection.openMissionPhaseId == "Insertion", "selection must use the bounded insertion window")
assertThat(config.Selection.minimumRequestIntervalSeconds == 0.15, "selection rate limit must be configured")
assertThat(config.Selection.maximumProcessedRequestIdsPerOperative == 64, "selection replay history must be bounded")
assertThat(#config.Selection.startingClassIds == 3, "exactly three starting classes must be declared")
assertThat(#config.ClassDefinitions == 3, "each starting class requires one definition")
assertThat(config.Resources.MedicalCharge.maximumAmount == 3, "medical supply must be finite")
assertThat(config.Resources.ResupplyCharge.maximumAmount == 2, "resupply supply must be finite")
assertThat(config.Actions.Brace.targetKindId == contracts.ClassTargetKindIds.None, "Brace must not trust a target")
assertThat(config.Actions.Brace.durationSeconds == 6, "Brace duration must remain configuration-driven")
assertThat(config.Actions.Brace.cooldownSeconds == 14, "Brace cooldown must remain configuration-driven")
assertThat(config.Actions.Brace.cadenceIntervalMultiplier == 0.85, "Brace cadence gain must remain bounded")
assertThat(config.Actions.Brace.interruptOnReload, "Brace must end when an accepted reload begins")
assertThat(config.Actions.FieldTreatment.healAmount == 25, "treatment starting heal must be configuration-driven")
assertThat(
	config.Actions.ReviveAssistance.restoredHealth > lifeConfig.ReviveHealth,
	"medic revive benefit must improve but not replace base revive"
)
assertThat(
	config.Actions.FieldResupply.roundsPerCharge == ammunitionConfig.BasicFirearm.AuthoredCacheRounds,
	"provisional resupply must use one bounded cache-sized grant"
)
assertThat(
	config.Actions.FieldResupply.isScarcityTuningProvisional,
	"engineer resupply must remain visibly provisional while P6 evidence is deferred"
)

assertThat(
	contracts.validateClassSelectionIntent({ requestId = "request-1", classId = contracts.ClassIds.Medic }),
	"minimal selection intent must validate"
)
assertThat(not contracts.validateClassSelectionIntent({
	requestId = "request-1",
	classId = contracts.ClassIds.Medic,
	operativeEntityId = "forged",
}), "selection intent must reject extra identity fields")
assertThat(
	contracts.validateClassSelectionIntent({ requestId = "request-2", classId = "unknown-class" }),
	"shape validation must preserve UnknownClass resolver feedback"
)

local assignment = table.freeze({
	operativeEntityId = "operative.player:1",
	classId = contracts.ClassIds.Medic,
	selectionStateId = contracts.ClassSelectionStateIds.Open,
	revision = 2,
})
local idleActionState = table.freeze({
	actionStateId = contracts.ClassActionStateIds.Idle,
	actionId = nil,
	targetOperativeEntityId = nil,
	startedAtServerTimestamp = nil,
	completionServerTimestamp = nil,
	cooldownEndServerTimestamp = nil,
	statusReasonId = nil,
	revision = 1,
})
assertThat(contracts.validateAuthoritativeClassAssignment(assignment), "valid assignment must validate")
assertThat(contracts.validateAuthoritativeClassActionState(idleActionState), "valid action state must validate")
assertThat(
	contracts.validateClassActionIntent({
		requestId = "brace-1",
		actionId = contracts.ClassActionIds.Brace,
		phaseId = contracts.ClassActionPhaseIds.Begin,
	}),
	"minimal Brace intent must validate"
)
assertThat(not contracts.validateClassActionIntent({
	requestId = "brace-2",
	actionId = contracts.ClassActionIds.Brace,
	phaseId = contracts.ClassActionPhaseIds.Begin,
	serverTimestamp = 12,
}), "action intent must reject client authority fields")
assertThat(
	contracts.validateSafeClassSelectionSnapshot({
		operationId = contracts.ClassSelectionNetworkOperationIds.Snapshot,
		rosterRevision = 3,
		selectionStateId = contracts.ClassSelectionStateIds.Open,
		ownerAssignment = assignment,
		ownerActionState = idleActionState,
		ownerResources = {},
		squadMembers = {
			{
				operativeEntityId = assignment.operativeEntityId,
				classId = assignment.classId,
				actionStateId = contracts.ClassActionStateIds.Idle,
				actionId = nil,
			},
		},
	}),
	"safe selection snapshot must validate"
)
assertThat(
	contracts.validateSafeClassSelectionRejection({
		operationId = contracts.ClassSelectionNetworkOperationIds.Rejected,
		rosterRevision = 3,
		rejectionReasonId = contracts.ClassActionRejectionReasonIds.SelectionClosed,
		requestId = "request-2",
	}),
	"safe selection rejection must validate"
)

local configMutationSucceeded = pcall(function()
	config.Actions.FieldResupply.roundsPerCharge = 999
end)
assertThat(not configMutationSucceeded, "class action configuration must be frozen")

local seenClasses = {}
local seenActions = {}
local seenResources = {}
for _, definition in config.ClassDefinitions do
	assertThat(not seenClasses[definition.classId], "class definitions must be unique")
	seenClasses[definition.classId] = true
	assertThat(#definition.actionIds > 0, "every starting class needs a frequent contribution")
	for _, actionId in definition.actionIds do
		assertThat(not seenActions[actionId], "each action must have one owning class")
		seenActions[actionId] = true
	end
	for _, resourceId in definition.resourceIds do
		assertThat(not seenResources[resourceId], "each resource must have one owning class")
		seenResources[resourceId] = true
	end
end

for _, classId in config.Selection.startingClassIds do
	assertThat(seenClasses[classId], "every selectable class requires a definition")
end

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
	}
do
	assertThat(
		not string.find(combinedDeclarations, forbidden, 1, true),
		"shared declarations must not contain " .. forbidden
	)
end
