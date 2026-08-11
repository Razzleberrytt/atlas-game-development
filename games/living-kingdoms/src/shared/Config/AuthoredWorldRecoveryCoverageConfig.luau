--!strict

-- BA-005 evidence-coverage boundary for held authored-overworld reconstruction.
--
-- This config records what current committed evidence is sufficient to preserve
-- versus what remains too incomplete for new geometry promotion. It is dormant
-- metadata only and never creates, moves, streams, or activates world content.

local Disposition = table.freeze({
	RecoveredHeld = "RecoveredHeld",
	PartialSampleOnly = "PartialSampleOnly",
	HierarchyOnly = "HierarchyOnly",
})

local Config = {
	Version = "BA-005-RECOVERY-COVERAGE-v2",
	RuntimeEnabled = false,
	CoordinateSpaceId = "authored-overworld",
	SourceRbxlSha256 = "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16",
	Disposition = Disposition,
	Evidence = table.freeze({
		WorkspaceIdentityRows = 1775,
		DecodedPropertyRows = 1699,
		FullPropertyArtifactCommitted = false,
		FullPropertyArtifactBytes = 1546379,
		FullPropertyArtifactSha256 = "078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea",
		RecoveredSourceBundleAuthorsResourceGeometry = false,
		UpdatedHubTownSourceRbxlSha256 = "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b",
		UpdatedHubTownSourceRbxlBytes = 1808699,
		UpdatedCentralFountainPropertyRows = 11,
	}),
	Groups = table.freeze({
		WorldPath = table.freeze({
			sourcePath = "Workspace/WorldPath",
			disposition = Disposition.RecoveredHeld,
			reconstructionModule = "RecoveredWorldPathConfig",
			newGeometryPromotionAllowed = false,
			note = "189-part held reconstruction already exists; do not duplicate it.",
		}),
		DungeonPortal = table.freeze({
			sourcePath = "Workspace/HubTown/DungeonPortal",
			disposition = Disposition.RecoveredHeld,
			reconstructionModule = "RecoveredDungeonPortalConfig",
			newGeometryPromotionAllowed = false,
			note = "Property and selected presentation evidence already preserved behind hold.",
		}),
		QuestBoard = table.freeze({
			sourcePath = "Workspace/HubTown/quest_board",
			disposition = Disposition.RecoveredHeld,
			reconstructionModule = "RecoveredQuestBoardConfig",
			newGeometryPromotionAllowed = false,
			note = "Held reconstruction exists with documented visual-property omissions.",
		}),
		MainWorldArrival = table.freeze({
			sourcePath = "Workspace/SpawnLocation",
			disposition = Disposition.RecoveredHeld,
			reconstructionModule = "RecoveredSpawnLocationConfig",
			newGeometryPromotionAllowed = false,
			note = "Single selected instance is property-backed and linked to the held Main World arrival contract.",
		}),
		UpdatedHubTownCentralFountain = table.freeze({
			sourcePath = "Workspace/HubTown/CentralFountain",
			disposition = Disposition.RecoveredHeld,
			reconstructionModule = "RecoveredHubTownRevisionConfig",
			newGeometryPromotionAllowed = true,
			note = "Checksum-pinned 2026-08-10 RBXL supplies complete decoder-supported properties for the 11-instance fountain; runtime remains held pending representation admission.",
		}),
		Resources = table.freeze({
			sourcePath = "Workspace/Resources",
			disposition = Disposition.PartialSampleOnly,
			reconstructionModule = nil,
			newGeometryPromotionAllowed = false,
			note = "Hierarchy is complete, but committed property detail contains only selected resource children.",
		}),
		WorldStructures = table.freeze({
			sourcePath = "Workspace/WorldStructures",
			disposition = Disposition.PartialSampleOnly,
			reconstructionModule = nil,
			newGeometryPromotionAllowed = false,
			note = "Hierarchy is complete, but committed property detail contains only selected structure children.",
		}),
		Atmosphere = table.freeze({
			sourcePath = "Workspace/AmbientFireflies|Workspace/WorldClouds",
			disposition = Disposition.HierarchyOnly,
			reconstructionModule = nil,
			newGeometryPromotionAllowed = false,
			note = "No complete committed property/presentation record exists for either atmosphere group in the historical source revision.",
		}),
	}),
	ResumeRequirements = table.freeze({
		"use checksum-pinned 2026-08-10 property evidence for UpdatedHubTownCentralFountain",
		"preserve SourceHold until each recovered group is deliberately admitted to the source-managed representation",
		"continue re-extracting GrandStaircase, HubArchway, and other target groups from the updated RBXL rather than guessing missing properties",
	}),
}

function Config.canPromoteNewGeometry(groupId: string): boolean
	local group = Config.Groups[groupId]
	return group ~= nil and group.newGeometryPromotionAllowed == true
end

return table.freeze(Config)
