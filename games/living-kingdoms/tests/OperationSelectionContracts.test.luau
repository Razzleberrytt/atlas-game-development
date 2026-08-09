--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "OperationSelectionContracts assertion failed", 2)
	end
end

local contracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Operations/OperationSelectionContracts.luau"), {
		debugName = "OperationSelectionContracts",
		injectGlobals = true,
	})()

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/OperationSelectionConfig.luau"), {
	debugName = "OperationSelectionConfig",
	injectGlobals = true,
})()

local expeditionContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ExpeditionContracts.luau"), {
		debugName = "ExpeditionContracts",
		injectGlobals = true,
	})()

local EXPEDITION_CONTRACTS_TOKEN = {}
local expeditionConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/ExpeditionConfig.luau"), {
	debugName = "ExpeditionConfig",
	injectGlobals = true,
	environment = {
		script = { Parent = { Parent = { Expeditions = { ExpeditionContracts = EXPEDITION_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			check(token == EXPEDITION_CONTRACTS_TOKEN, "unexpected ExpeditionConfig dependency")
			return expeditionContracts
		end,
	},
})()

check(config.Version == "BA-005-OPERATION-SELECTION-v1")
check(config.RuntimeEnabled == false)
check(config.NetworkBindingEnabled == false)
check(config.LaunchHandoffReady == false)
check(config.InitialSelectionStateId == contracts.SelectionStateIds.Held)
check(config.InitialSelectionRevision == 0)
check(config.SelectionMutationPolicyId == "pending-server-policy")
check(config.CanonicalExpeditionAuthority == "ExpeditionLobbyService")
check(config.MissionRuntimeAuthority == "MissionDirectorService")

check(config.Guardrails.PartyLeaderConceptRequired == false)
check(config.Guardrails.PartyLeaderConceptExistsToday == false)
check(config.Guardrails.ClientMayMutateMissionRuntime == false)
check(config.Guardrails.SelectionRequiresServerValidation == true)
check(config.Guardrails.LaunchMustConsumeValidatedOperationDefinition == true)
check(config.Guardrails.QuestBoardBindingEnabled == false)

check(#config.Operations == 1)
local operation = config.Operations[1]
local expedition = expeditionConfig.Definitions.FirstExpedition
check(operation.operationId == expedition.Id)
check(operation.expeditionDefinitionId == expedition.Id)
check(operation.displayName == expedition.DisplayName)
check(operation.minimumPlayers == expedition.MinimumPlayers)
check(operation.maximumPlayers == expedition.MaximumPlayers)
check(operation.targetDurationSeconds == expedition.TargetDurationSeconds)
check(operation.launchCompatible == true)
check(config.InitialSelectedOperationId == expedition.Id)
check(config.getOperation(expedition.Id) == operation)
check(config.getOperation("missing-operation") == nil)
check(config.isKnownOperationId(expedition.Id) == true)
check(config.isKnownOperationId("missing-operation") == false)

local safeSummary = {
	operationId = operation.operationId,
	displayName = operation.displayName,
	minimumPlayers = operation.minimumPlayers,
	maximumPlayers = operation.maximumPlayers,
	targetDurationSeconds = operation.targetDurationSeconds,
	launchCompatible = operation.launchCompatible,
}
check(contracts.validateSafeOperationSummary(safeSummary))

local heldSnapshot = {
	networkOperationId = contracts.NetworkOperationIds.Snapshot,
	catalogRevision = config.CatalogRevision,
	selectionRevision = config.InitialSelectionRevision,
	selectionStateId = config.InitialSelectionStateId,
	selectedOperationId = config.InitialSelectedOperationId,
	operations = { safeSummary },
}
check(contracts.validateSafeSelectionSnapshot(heldSnapshot))

local validIntent = {
	requestId = "operation-selection:123:1",
	operationId = expedition.Id,
	expectedSelectionRevision = 0,
}
check(contracts.validateSelectionIntent(validIntent))
check(not contracts.validateSelectionIntent({
	requestId = "operation-selection:123:1",
	operationId = expedition.Id,
	expectedSelectionRevision = 0,
	extra = true,
}))
check(not contracts.validateSelectionIntent({
	requestId = "",
	operationId = expedition.Id,
	expectedSelectionRevision = 0,
}))
check(not contracts.validateSelectionIntent({
	requestId = "operation-selection:123:1",
	operationId = expedition.Id,
	expectedSelectionRevision = -1,
}))

local rejection = {
	networkOperationId = contracts.NetworkOperationIds.Rejected,
	requestId = validIntent.requestId,
	selectionRevision = 0,
	rejectionReasonId = contracts.RejectionReasonIds.RuntimeDisabled,
}
check(contracts.validateSafeSelectionRejection(rejection))

check(not contracts.validateSafeSelectionSnapshot({
	networkOperationId = contracts.NetworkOperationIds.Snapshot,
	catalogRevision = 1,
	selectionRevision = 0,
	selectionStateId = contracts.SelectionStateIds.Held,
	selectedOperationId = "missing-operation",
	operations = { safeSummary },
}))

check(not contracts.validateSafeSelectionSnapshot({
	networkOperationId = contracts.NetworkOperationIds.Snapshot,
	catalogRevision = 1,
	selectionRevision = 0,
	selectionStateId = contracts.SelectionStateIds.Held,
	selectedOperationId = expedition.Id,
	operations = { safeSummary, safeSummary },
}))
