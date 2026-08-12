--!strict

-- BA-011: held source-representation contract for the authored Main World.
--
-- This file defines reviewable ownership and placement boundaries only. It does
-- not map recovered content into the active operation project, create geometry,
-- enable streaming, or start an authored-overworld runtime.

local Config = {
	Version = "BA-011-v4-studio-snapshot-placement-parity",
	SourceHold = true,
	RuntimeEnabled = false,
	PlaceBoundary = table.freeze({
		Strategy = "dedicated-main-world-place",
		CurrentOperationProject = "games/living-kingdoms/default.project.json",
		MainWorldProjectStatus = "dedicated-source-project-present-studio-snapshot-mapped",
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
			Status = "coherent-groups-preserved-and-source-mapped",
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
	-- `projectMappingStatus` records whether the dedicated Main World project
	-- source-maps the group's semantic `targetPath` today. A mapped target may be
	-- a literal Rojo node or a semantic descendant preserved inside one coherent
	-- whole-group Studio snapshot mapping. It is declared here so Luau consumers
	-- can read mapping truth without parsing Rojo/model JSON, and fixtures bind it
	-- back to `main-world.project.json` plus the imported model hierarchy.
	-- `Mapped` describes source placement only; it never implies runtime
	-- activation, streaming configuration, or BA-014 acceptance.
	ProjectMappingStatuses = table.freeze({
		Mapped = "Mapped",
		Unmapped = "Unmapped",
	}),
	StreamingGroups = table.freeze({
		table.freeze({
			id = "main_world.hub_core",
			sourceRoots = table.freeze({ "Workspace/HubTown", "Workspace/SpawnLocation" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/HubCore",
			representation = "coherent-model-groups",
			streamingPolicy = "persistent-core-candidate",
			projectMappingStatus = "Mapped",
		}),
		table.freeze({
			id = "main_world.primary_route",
			sourceRoots = table.freeze({ "Workspace/WorldPath" }),
			-- `PrimaryRoute` is a semantic descendant of the coherently imported
			-- `Routes` snapshot rather than a second fine-grained Rojo mapping.
			targetPath = "Workspace/LivingKingdomsMainWorld/Routes/PrimaryRoute",
			representation = "route-data-plus-bounded-render-chunks",
			streamingPolicy = "spatial-chunks",
			projectMappingStatus = "Mapped",
		}),
		table.freeze({
			id = "main_world.resources",
			sourceRoots = table.freeze({ "Workspace/Resources" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/Resources",
			representation = "resource-cluster-models",
			streamingPolicy = "spatial-chunks",
			projectMappingStatus = "Unmapped",
		}),
		table.freeze({
			id = "main_world.structures",
			sourceRoots = table.freeze({ "Workspace/WorldStructures" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/Structures",
			representation = "one-model-per-authored-structure-group",
			streamingPolicy = "per-structure-never-whole-root-atomic",
			projectMappingStatus = "Mapped",
		}),
		table.freeze({
			id = "main_world.atmosphere",
			sourceRoots = table.freeze({ "Workspace/AmbientFireflies", "Workspace/WorldClouds" }),
			targetPath = "Workspace/LivingKingdomsMainWorld/Atmosphere",
			representation = "bounded-local-emitters-plus-environment-profile-data",
			streamingPolicy = "local-volumes-no-global-particle-root",
			projectMappingStatus = "Unmapped",
		}),
	}),
	Anchors = table.freeze({
		Arrival = table.freeze({
			contentId = "spawn.main_world.arrival",
			sourcePath = "Workspace/SpawnLocation",
			coordinateSpaceId = "authored-overworld",
			sourceContractModule = "RecoveredSpawnLocationConfig",
			sourceContractVersion = "BA-005-SPAWN-LOCATION-v1",
			position = table.freeze({ x = 0.0, y = 7.0, z = 30.0 }),
			positionEvidence = "reextracted-property-evidence",
			propertyEvidenceStatus = "complete-selected-instance",
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
		MappedTargetPathMustMatchDedicatedProject = true,
		MappedPlacementDoesNotImplyRuntimeActivation = true,
	}),
}

function Config.isStreamingGroupMapped(groupId: string): boolean
	for _, group in Config.StreamingGroups do
		if group.id == groupId then
			return group.projectMappingStatus == Config.ProjectMappingStatuses.Mapped
		end
	end
	return false
end

-- Ordered so callers that report or iterate the mapped surface stay deterministic.
function Config.mappedStreamingGroupIds(): { string }
	local mapped: { string } = {}
	for _, group in Config.StreamingGroups do
		if group.projectMappingStatus == Config.ProjectMappingStatuses.Mapped then
			table.insert(mapped, group.id)
		end
	end
	return mapped
end

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

-- Module-load invariants: every group declares a known mapping status, every
-- target path stays under the dedicated Main World root, and admitting content
-- to source never flips the held runtime flag.
local seenGroupIds: { [string]: boolean } = {}
for _, group in Config.StreamingGroups do
	assert(not seenGroupIds[group.id], `duplicate streaming group: {group.id}`)
	seenGroupIds[group.id] = true
	assert(
		group.projectMappingStatus == Config.ProjectMappingStatuses.Mapped
			or group.projectMappingStatus == Config.ProjectMappingStatuses.Unmapped,
		`streaming group {group.id} needs a known project mapping status`
	)
	local rootPrefix = `{Config.Root.ParentService}/{Config.Root.Name}`
	assert(
		string.sub(group.targetPath, 1, #rootPrefix) == rootPrefix,
		`streaming group {group.id} places content outside the dedicated Main World root`
	)
end
assert(Config.RuntimeEnabled == false, "BA-011 describes placement; it activates nothing")

return table.freeze(Config)
