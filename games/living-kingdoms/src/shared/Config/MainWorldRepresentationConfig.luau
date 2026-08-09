--!strict

-- BA-011: held source-representation contract for the authored Main World.
--
-- This file defines reviewable ownership and placement boundaries only. It does
-- not map recovered content into the active operation project, create geometry,
-- enable streaming, or start an authored-overworld runtime.

local Config = {
	Version = "BA-011-v1",
	SourceHold = true,
	RuntimeEnabled = false,
	PlaceBoundary = table.freeze({
		Strategy = "dedicated-main-world-place",
		CurrentOperationProject = "games/living-kingdoms/default.project.json",
		MainWorldProjectStatus = "not-created-until-reviewable-content-exists",
		MainWorldPlaceIdStatus = "unassigned",
		SharedUniverseRequired = true,
		DedicatedLifecycleRequired = true,
	}),
	Root = table.freeze({
		Name = "LivingKingdomsMainWorld",
		ParentService = "Workspace",
		ContentId = "world.hub.primary",
		CoordinateSpaceId = "authored-overworld",
		MayDescendFromOperationRoot = false,
		OperationRootName = "LivingKingdomsWorld",
	}),
	Representations = table.freeze({
		EvidenceData = table.freeze({
			Ownership = "source-managed-luau-config",
			Path = "games/living-kingdoms/src/shared/Config",
			Purpose = "recovered-identities-properties-and-deterministic-placement",
		}),
		ReviewableModels = table.freeze({
			Ownership = "source-managed-model-assets",
			Path = "games/living-kingdoms/assets/recovered-world/models",
			Status = "create-per-coherent-group-after-property-parity-validation",
		}),
		Terrain = table.freeze({
			Ownership = "studio-authored-with-source-manifest",
			Status = "not-recovered-not-authorized",
			ManifestRequired = true,
		}),
		GeneratedBuildOutput = table.freeze({
			Ownership = "generated-not-source",
			MayBeCommitted = false,
		}),
	}),
	StreamingGroups = table.freeze({
		table.freeze({
			id = "main_world.hub_core",
			sourceRoots = table.freeze({ "Workspace/HubTown", "Workspace/SpawnLocation" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/HubCore",
			representation = "coherent-model-groups",
			streamingPolicy = "persistent-core-candidate",
		}),
		table.freeze({
			id = "main_world.primary_route",
			sourceRoots = table.freeze({ "Workspace/WorldPath" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/Routes/Primary",
			representation = "route-data-plus-bounded-render-chunks",
			streamingPolicy = "spatial-chunks",
		}),
		table.freeze({
			id = "main_world.resources",
			sourceRoots = table.freeze({ "Workspace/Resources" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/Resources",
			representation = "resource-cluster-models",
			streamingPolicy = "spatial-chunks",
		}),
		table.freeze({
			id = "main_world.structures",
			sourceRoots = table.freeze({ "Workspace/WorldStructures" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/Structures",
			representation = "one-model-per-authored-structure-group",
			streamingPolicy = "per-structure-never-whole-root-atomic",
		}),
		table.freeze({
			id = "main_world.atmosphere",
			sourceRoots = table.freeze({ "Workspace/AmbientFireflies", "Workspace/WorldClouds" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/Atmosphere",
			representation = "bounded-local-emitters-plus-environment-profile-data",
			streamingPolicy = "local-volumes-no-global-particle-root",
		}),
	}),
	Anchors = table.freeze({
		Arrival = table.freeze({
			contentId = "spawn.main_world.arrival",
			sourcePath = "Workspace/SpawnLocation",
			position = table.freeze({ x = 0.0, y = 7.0, z = 30.0 }),
			positionEvidence = "reextracted-property-evidence",
			status = "evidence-backed-held",
		}),
		Return = table.freeze({
			contentId = "spawn.main_world.return",
			status = "required-before-activation",
			positionStatus = "unassigned-pending-return-flow-composition",
		}),
	}),
	Rules = table.freeze({
		PreserveAuthoredCoordinatesOneToOne = true,
		DoNotMapHeldContentIntoOperationProject = true,
		DoNotCommitGeneratedPlaceFiles = true,
		DoNotCreateOneAtomicModelForEntireWorld = true,
		StreamOutNeverMeansGameplayCompletion = true,
		StableSemanticIdsSurviveMissingInstances = true,
		LegacyServicesRemainInert = true,
		TerrainRequiresManifestAndStudioEvidence = true,
	}),
}

function Config.streamingGroupForSourcePath(path: string): any?
	for _, group in Config.StreamingGroups do
		for _, rootPath in group.sourceRoots do
			if path == rootPath or string.sub(path, 1, #rootPath + 1) == rootPath .. "/" then
				return group
			end
		end
	end
	return nil
end

return table.freeze(Config)
