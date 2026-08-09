--!strict

-- Contract-only pre-launch operation catalog.
--
-- Runtime integration is intentionally disabled because the current expedition
-- runtime still launches one hardcoded definition and does not consume a
-- validated operation ID. This module exists to make that future seam explicit
-- before any authored-overworld quest-board interaction is wired.

local Config = {
	Version = "BA-005-OPERATION-SELECTION-v1",
	RuntimeEnabled = false,
	NetworkBindingEnabled = false,
	LaunchHandoffReady = false,
	CatalogRevision = 1,
	InitialSelectionRevision = 0,
	InitialSelectionStateId = "Held",
	InitialSelectedOperationId = "first-expedition",
	SelectionMutationPolicyId = "pending-server-policy",
	CanonicalExpeditionAuthority = "ExpeditionLobbyService",
	MissionRuntimeAuthority = "MissionDirectorService",
	Operations = table.freeze({
		table.freeze({
			operationId = "first-expedition",
			displayName = "The First Descent",
			minimumPlayers = 1,
			maximumPlayers = 4,
			targetDurationSeconds = 480,
			launchCompatible = true,
			expeditionDefinitionId = "first-expedition",
		}),
	}),
	Guardrails = table.freeze({
		PartyLeaderConceptRequired = false,
		PartyLeaderConceptExistsToday = false,
		ClientMayMutateMissionRuntime = false,
		SelectionRequiresServerValidation = true,
		LaunchMustConsumeValidatedOperationDefinition = true,
		QuestBoardBindingEnabled = false,
	}),
}

function Config.getOperation(operationId: string): any?
	for _, operation in Config.Operations do
		if operation.operationId == operationId then
			return operation
		end
	end
	return nil
end

function Config.isKnownOperationId(operationId: string): boolean
	return Config.getOperation(operationId) ~= nil
end

return table.freeze(Config)
