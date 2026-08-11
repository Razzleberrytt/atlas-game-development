--!strict

-- BA-005 / Patch 0.5 evidence-coverage boundary for held authored-overworld reconstruction.
-- Historical recovery evidence remains immutable. Newer Studio revisions are
-- admitted additively and checksum-pinned per review unit. Dormant metadata only.

local Disposition = table.freeze({
	RecoveredHeld = "RecoveredHeld",
	PartialSampleOnly = "PartialSampleOnly",
	HierarchyOnly = "HierarchyOnly",
})

local Config = {
	Version = "BA-005-RECOVERY-COVERAGE-v2",
	RuntimeEnabled = false,
	CoordinateSpaceId = "authored-overworld",
	-- Compatibility alias for historical recovery modules; do not rewrite provenance.
	SourceRbxlSha256 = "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16",
	LatestAuthoredRevisionSha256 = "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b",
	Disposition = Disposition,
	Evidence = table.freeze({
		WorkspaceIdentityRows = 1775,
		DecodedPropertyRows = 1699,
		FullPropertyArtifactCommitted = false,
		FullPropertyArtifactBytes = 1546379,
		FullPropertyArtifactSha256 = "078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea",
		RecoveredSourceBundleAuthorsResourceGeometry = false,
	}),
	SourceRevisions = table.freeze({
		HistoricalRecovery = table.freeze({
			sourceRbxlSha256 = "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16",
			workspaceIdentityRows = 1775,
			decodedPropertyRows = 1699,
			fullPropertyArtifactBytes = 1546379,
			fullPropertyArtifactSha256 = "078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea",
		}),
		AuthoredRevision20260810 = table.freeze({
			sourceRbxlSha256 = "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b",
			sourceRbxlBytes = 1808699,
			declaredInstances = 2342,
			parsedInstances = 2342,
			reviewEvidenceCommitted = true,
		}),
	}),
	Groups = table.freeze({
		WorldPath = table.freeze({ sourcePath = "Workspace/WorldPath", disposition = Disposition.RecoveredHeld, reconstructionModule = "RecoveredWorldPathConfig", newGeometryPromotionAllowed = false, note = "189-part held reconstruction already exists; do not duplicate it." }),
		DungeonPortal = table.freeze({ sourcePath = "Workspace/HubTown/DungeonPortal", disposition = Disposition.RecoveredHeld, reconstructionModule = "RecoveredDungeonPortalConfig", newGeometryPromotionAllowed = false, note = "Historical property/presentation evidence is preserved behind hold; newer revision parity may be admitted additively." }),
		QuestBoard = table.freeze({ sourcePath = "Workspace/HubTown/quest_board", disposition = Disposition.RecoveredHeld, reconstructionModule = "RecoveredQuestBoardConfig", newGeometryPromotionAllowed = false, note = "Held reconstruction exists with documented visual-property omissions." }),
		MainWorldArrival = table.freeze({ sourcePath = "Workspace/SpawnLocation", disposition = Disposition.RecoveredHeld, reconstructionModule = "RecoveredSpawnLocationConfig", newGeometryPromotionAllowed = false, note = "Single selected instance is property-backed and linked to the held Main World arrival contract." }),
		CentralFountain = table.freeze({ sourcePath = "Workspace/HubTown/CentralFountain", disposition = Disposition.RecoveredHeld, reconstructionModule = "RecoveredCentralFountainConfig", newGeometryPromotionAllowed = false, evidenceRevision = "AuthoredRevision20260810", note = "First Patch 0.5 civic review unit; 11-instance bounded evidence is committed and checksum-pinned." }),
		Resources = table.freeze({ sourcePath = "Workspace/Resources", disposition = Disposition.PartialSampleOnly, reconstructionModule = nil, newGeometryPromotionAllowed = false, note = "Hierarchy is complete, but committed property detail contains only selected resource children." }),
		WorldStructures = table.freeze({ sourcePath = "Workspace/WorldStructures", disposition = Disposition.PartialSampleOnly, reconstructionModule = nil, newGeometryPromotionAllowed = false, note = "Hierarchy is complete, but committed property detail contains only selected structure children." }),
		Atmosphere = table.freeze({ sourcePath = "Workspace/AmbientFireflies|Workspace/WorldClouds", disposition = Disposition.HierarchyOnly, reconstructionModule = nil, newGeometryPromotionAllowed = false, note = "No complete committed property/presentation record exists for either atmosphere group." }),
	}),
	ResumeRequirements = table.freeze({
		"pin every newly admitted authored revision or review artifact by SHA256",
		"extract a bounded exact-path review unit before adding a held reconstruction module",
		"validate property parity for each coherent group before any later runtime mapping or activation",
	}),
}

function Config.canPromoteNewGeometry(groupId: string): boolean
	local group = Config.Groups[groupId]
	return group ~= nil and group.newGeometryPromotionAllowed == true
end

return table.freeze(Config)
