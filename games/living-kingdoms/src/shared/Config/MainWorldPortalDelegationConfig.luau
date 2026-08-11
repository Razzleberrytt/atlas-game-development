--!strict

-- Patch 0.5 held delegation contract for the authored expedition portal.
-- This records only already-established canonical relationships. It is not a
-- prompt, remote, transport policy, eligibility owner, or runtime activation.

local Config = {
	Version = "P0.5-MAIN-WORLD-PORTAL-DELEGATION-v1",
	RuntimeEnabled = false,
	PortalContentId = "portal.expedition.primary",
	MainWorldAnchorId = "hub.anchor.expedition_portal",
	CurrentBridgeAnchorId = "hub.anchor.expedition_terminal",
	InteractionIntentId = "hub.intent.open_expedition_lobby",
	DestinationDefinitionId = "ExpeditionPrimary",
	CanonicalLaunchAuthorityOwnerId = "ExpeditionLobbyService",
	Rules = table.freeze({
		MainWorldSurfaceOwnsConsequentialMutation = false,
		MainWorldSurfaceOwnsEligibility = false,
		MainWorldSurfaceOwnsTransport = false,
		ClientMayGrantJoinReadyOrLaunch = false,
		InterPlaceTransportDefined = false,
		PublishedPlaceIdsRequiredBeforeTransport = true,
		RecoveredPromptInferenceAllowed = false,
		StreamOutMayCompleteInteraction = false,
		DelegationMustMatchCurrentBridgeIntent = true,
		DelegationMustMatchCanonicalLaunchOwner = true,
	}),
}

return table.freeze(Config)
