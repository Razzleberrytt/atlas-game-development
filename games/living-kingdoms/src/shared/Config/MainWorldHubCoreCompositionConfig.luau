--!strict

-- Patch 0.5 source-managed composition for the smallest admitted Main World
-- hub core. This is dormant composition metadata only: it does not create
-- Instances, activate the dedicated place, or own gameplay behavior.

local Config = {
	Version = "P0.5-MAIN-WORLD-HUB-CORE-COMPOSITION-v1",
	ContentId = "main_world.hub_core",
	CoordinateSpaceId = "authored-overworld",
	StreamingGroupId = "main_world.hub_core",
	TargetPath = "Workspace/LivingKingdomsMainWorld/HubCore",
	SourceHold = true,
	RuntimeEnabled = false,
	DedicatedMainWorldOnly = true,
	OperationProjectMappingAllowed = false,
	Components = table.freeze({
		table.freeze({
			id = "spawn.main_world.arrival",
			role = "arrival",
			sourcePath = "Workspace/SpawnLocation",
			sourceContractModule = "RecoveredSpawnLocationConfig",
			sourceContractVersion = "BA-005-SPAWN-LOCATION-v1",
			targetRelativePath = "Arrival/SpawnLocation",
		}),
		table.freeze({
			id = "main_world.hub_core.central_fountain",
			role = "orientation-landmark",
			sourcePath = "Workspace/HubTown/CentralFountain",
			sourceContractModule = "RecoveredCentralFountainConfig",
			sourceContractVersion = "P0.5-CENTRAL-FOUNTAIN-v1",
			targetRelativePath = "Civic/CentralFountain",
		}),
		table.freeze({
			id = "main_world.hub_core.grand_staircase",
			role = "primary-circulation",
			sourcePath = "Workspace/HubTown/GrandStaircase",
			sourceContractModule = "RecoveredGrandStaircaseConfig",
			sourceContractVersion = "P0.5-GRAND-STAIRCASE-v1",
			targetRelativePath = "Civic/GrandStaircase",
		}),
		table.freeze({
			id = "main_world.hub_core.archway",
			role = "orientation-threshold",
			sourcePath = "Workspace/HubTown/HubArchway",
			sourceContractModule = "RecoveredHubArchwayConfig",
			sourceContractVersion = "P0.5-HUB-ARCHWAY-v1",
			targetRelativePath = "Civic/HubArchway",
		}),
		table.freeze({
			id = "portal.expedition.primary",
			role = "expedition-gate-presentation",
			sourcePath = "Workspace/HubTown/DungeonPortal",
			sourceContractModule = "RecoveredDungeonPortalConfig",
			sourceContractVersion = "BA-005-DUNGEON-PORTAL-v2",
			targetRelativePath = "ExpeditionGate/DungeonPortal",
			canonicalGameplayAuthority = "ExpeditionLobbyService",
		}),
	}),
	Authority = table.freeze({
		WorldCompositionOwner = "source-managed-main-world-representation",
		ExpeditionGameplayOwner = "ExpeditionLobbyService",
		RecoveredGameplayAuthorityAllowed = false,
		LegacyBootstrapAllowed = false,
		WorldFoundationServiceAllowed = false,
	}),
	Rules = table.freeze({
		PreserveAuthoredCoordinatesOneToOne = true,
		AllComponentsMustRemainHeldUntilActivationGate = true,
		StableSemanticIdsRequired = true,
		MissingInstancesDoNotChangeGameplayTruth = true,
		DoNotInventUnadmittedWorldContent = true,
	}),
}

function Config.componentById(id: string): any?
	for _, component in Config.Components do
		if component.id == id then
			return component
		end
	end
	return nil
end

return table.freeze(Config)
