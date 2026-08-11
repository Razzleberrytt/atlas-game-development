--!strict

-- Patch 0.5 source-evaluable readability/streaming expectations for the
-- admitted Main World hub core. These are review targets, not claims that
-- Studio/device evidence has already passed.

local Config = {
	Version = "P0.5-MAIN-WORLD-HUB-CORE-READABILITY-v1",
	ContentId = "main_world.hub_core.readability",
	CompositionVersion = "P0.5-MAIN-WORLD-HUB-CORE-COMPOSITION-v1",
	CoordinateSpaceId = "authored-overworld",
	StreamingGroupId = "main_world.hub_core",
	SourceHold = true,
	RuntimeEnabled = false,
	StudioEvidenceRequired = true,
	StudioEvidenceStatus = "PENDING",
	Nodes = table.freeze({
		table.freeze({
			id = "spawn.main_world.arrival",
			role = "arrival",
			targetRelativePath = "Arrival/SpawnLocation",
			readabilityPurpose = "cold-join-anchor",
			instancePresenceRequiredForConsequentialTruth = false,
		}),
		table.freeze({
			id = "main_world.hub_core.central_fountain",
			role = "orientation-landmark",
			targetRelativePath = "Civic/CentralFountain",
			readabilityPurpose = "central-orientation",
			instancePresenceRequiredForConsequentialTruth = false,
		}),
		table.freeze({
			id = "main_world.hub_core.grand_staircase",
			role = "primary-circulation",
			targetRelativePath = "Civic/GrandStaircase",
			readabilityPurpose = "primary-circulation-cue",
			instancePresenceRequiredForConsequentialTruth = false,
		}),
		table.freeze({
			id = "main_world.hub_core.archway",
			role = "orientation-threshold",
			targetRelativePath = "Civic/HubArchway",
			readabilityPurpose = "threshold-cue",
			instancePresenceRequiredForConsequentialTruth = false,
		}),
		table.freeze({
			id = "portal.expedition.primary",
			role = "expedition-gate-presentation",
			targetRelativePath = "ExpeditionGate/DungeonPortal",
			readabilityPurpose = "expedition-gate-cue",
			instancePresenceRequiredForConsequentialTruth = false,
		}),
	}),
	SourceEvaluableExpectations = table.freeze({
		StableSemanticIds = true,
		SingleBoundedStreamingGroup = true,
		ProjectTargetsMustMatchComposition = true,
		LocallyAbsentInstancesPreserveGameplayTruth = true,
		PortalPresentationDoesNotOwnLaunchAuthority = true,
	}),
	PendingStudioExpectations = table.freeze({
		ArrivalCameraReadability = "PENDING",
		FourPlayerClearance = "PENDING",
		TraversalDeadTravel = "PENDING",
		InteractionVisibility = "PENDING",
		StreamingContinuityAndRebind = "PENDING",
		RepresentativePerformance = "PENDING",
	}),
	Rules = table.freeze({
		DoNotMoveAuthoredGeometryForSourceReadabilityChecks = true,
		DoNotInventNumericAcceptanceThresholds = true,
		DoNotPromotePendingStudioEvidenceToPass = true,
		ResolvePresentationByStableSemanticId = true,
		ConsequentialGameplayTruthMustRemainCanonical = true,
	}),
}

function Config.nodeById(id: string): any?
	for _, node in Config.Nodes do
		if node.id == id then
			return node
		end
	end
	return nil
end

return table.freeze(Config)
