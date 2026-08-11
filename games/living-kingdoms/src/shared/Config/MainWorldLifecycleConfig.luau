--!strict

-- Patch 0.5 lifecycle semantics for the dedicated Main World.
--
-- This contract names the source-safe state progression and canonical owners
-- without choosing inter-place transport, publishing IDs, or activating the
-- held Main World runtime.

local StateIds = table.freeze({
	Arrival = "Arrival",
	Preparation = "Preparation",
	Expedition = "Expedition",
	Debrief = "Debrief",
})

local Config = {
	Version = "P0.5-MAIN-WORLD-LIFECYCLE-v1",
	RuntimeEnabled = false,
	DedicatedMainWorldOnly = true,
	StateIds = StateIds,
	InitialStateId = StateIds.Arrival,
	Arrival = table.freeze({
		ContentId = "spawn.main_world.arrival",
		SourceContractModule = "RecoveredSpawnLocationConfig",
		SourceContractVersion = "BA-005-SPAWN-LOCATION-v1",
		TargetPath = "Workspace/LivingKingdomsMainWorld/HubCore/Arrival/SpawnLocation",
		ColdJoinStartsHere = true,
		PreparationStateId = StateIds.Preparation,
	}),
	ExpeditionGate = table.freeze({
		ContentId = "portal.expedition.primary",
		SourceContractModule = "RecoveredDungeonPortalConfig",
		SourceContractVersion = "BA-005-DUNGEON-PORTAL-v2",
		LaunchStateId = StateIds.Expedition,
		CanonicalLaunchAuthority = "ExpeditionLobbyService",
	}),
	Debrief = table.freeze({
		StateId = StateIds.Debrief,
		CanonicalResultAuthority = "ExpeditionResultService",
		CanonicalReplayDecisionAuthority = "ExpeditionResultService",
		ReturnDecisionId = "ReturnToPreparation",
		ReplayDecisionId = "Replay",
		ReturnStateId = StateIds.Preparation,
	}),
	OutcomeRouting = table.freeze({
		Completed = table.freeze({
			NextStateId = StateIds.Debrief,
		}),
		Failed = table.freeze({
			NextStateId = StateIds.Debrief,
		}),
		Abandoned = table.freeze({
			NextStateId = StateIds.Debrief,
		}),
	}),
	Transport = table.freeze({
		PolicyDefined = false,
		RequiresAuthorizedPublishedPlaceIds = true,
		TeleportAuthorityOwnedHere = false,
	}),
	Rules = table.freeze({
		LaunchRequiresCanonicalLobbyAcceptance = true,
		ResultMustFinalizeBeforeDebriefDecision = true,
		SuccessAndFailureShareDebriefPath = true,
		ReplayDecisionMustUseCanonicalResultOwner = true,
		ClientConsequentialAuthorityAllowed = false,
		NoTransportGuessing = true,
	}),
}

return table.freeze(Config)
