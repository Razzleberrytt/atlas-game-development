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
	Version = "BA-005-RECOVERY-COVERAGE-v1",
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
			note = "No complete committed property/presentation record exists for either atmosphere group.",
		}),
	}),
	ResumeRequirements = table.freeze({
		"commit or otherwise reviewably expose the checksum-pinned full property artifact",
		"or re-extract the target group's complete supported properties from the canonical place source",
		"then validate one coherent group before adding any new held geometry",
	}),
}

function Config.canPromoteNewGeometry(groupId: string): boolean
	local group = Config.Groups[groupId]
	return group ~= nil and group.newGeometryPromotionAllowed == true
end

return table.freeze(Config)
