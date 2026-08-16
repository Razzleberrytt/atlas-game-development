--!strict

-- Dedicated Main World bootstrap boundary.
--
-- This remains an allowlist contract. It does not activate operation gameplay
-- runtime, map preserved runtime code, or grant authority to recovered assets.
-- StaticSceneStabilization is a narrow pre-runtime safety pass over explicitly
-- classified world roots so recovered presentation geometry cannot fall apart
-- under Roblox physics while RuntimeEnabled remains false.

local Config = {
	Version = "P0.5-MAIN-WORLD-BOOTSTRAP-ALLOWLIST-v2",
	RuntimeEnabled = false,
	DedicatedMainWorldOnly = true,
	CurrentOperationProjectMappingAllowed = false,
	SharedSourceRoot = "games/living-kingdoms/src/shared",
	StaticSceneStabilization = table.freeze({
		Enabled = true,
		WorldRootName = "LivingKingdomsMainWorld",
		StaticRootNames = table.freeze({
			"HubCore",
			"Routes",
			"TraversalRepair",
			"OuterTraversalRepair",
			"GroundSkin",
			"RegionalRoutes",
			"Environment",
			"Structures",
			"Props",
			"Dark",
			"Village",
			"Forest",
			"Castle",
			"Zones",
			"Crystal",
			"Beach",
			"Volcanic",
			"Desert",
			"Swamp",
			"Snow",
			"Jungle",
			"Autumn",
			"Sky",
			"Meadow",
			"Mushroom",
			"Ruins",
			"Ocean",
			"Ice",
			"Bamboo",
			"Geyser",
			"Lavender",
			"Cherry",
			"Tundra",
			"Canyon",
			"Coral",
			"Geothermal",
			"Oasis",
			"CrystalDesert",
		}),
		DynamicRootNames = table.freeze({
			"NPCs",
		}),
	}),
	Server = table.freeze({
		BootstrapRoot = "games/living-kingdoms/src/main-world/server",
		EntryPoint = "MainWorldServer.server.luau",
		AllowedCanonicalOwners = table.freeze({
			"ExpeditionLobbyService",
		}),
		AllowedResponsibilities = table.freeze({
			"static-scene-stabilization",
			"expedition-launch-intent",
			"durable-player-state-adapter",
			"durable-inventory-adapter",
		}),
		ForbiddenOperationOwners = table.freeze({
			"WorldFoundationService",
		}),
	}),
	Client = table.freeze({
		BootstrapRoot = "games/living-kingdoms/src/main-world/client",
		EntryPoint = "MainWorldClient.client.luau",
		AllowedResponsibilities = table.freeze({
			"hub-presentation",
			"interaction-intent",
			"streaming-rebind-presentation",
		}),
		ConsequentialAuthorityAllowed = false,
	}),
	ExcludedActiveSourceRoots = table.freeze({
		"games/living-kingdoms/imports",
		"games/living-kingdoms/src/server",
		"games/living-kingdoms/src/client",
	}),
	Rules = table.freeze({
		ExplicitEntryPointsOnly = true,
		PreservedRuntimeMayNeverBeMapped = true,
		OperationRuntimeRootsMayNotBeMappedWholesale = true,
		CanonicalSharedModulesMayBeRequiredSelectively = true,
		NoPlaceOrUniverseIdsUntilAuthorizedPublishing = true,
	}),
}

return table.freeze(Config)
