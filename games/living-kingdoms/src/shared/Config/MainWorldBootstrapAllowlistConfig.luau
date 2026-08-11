--!strict

-- Patch 0.5 dedicated Main World bootstrap boundary.
--
-- This is an allowlist contract only. Nothing here activates a second place,
-- maps the held world into the operation project, or grants preserved runtime
-- authority. A future dedicated Rojo project may map only these explicit
-- bootstrap roots plus canonical Shared modules.

local Config = {
	Version = "P0.5-MAIN-WORLD-BOOTSTRAP-ALLOWLIST-v1",
	RuntimeEnabled = false,
	DedicatedMainWorldOnly = true,
	CurrentOperationProjectMappingAllowed = false,
	SharedSourceRoot = "games/living-kingdoms/src/shared",
	Server = table.freeze({
		BootstrapRoot = "games/living-kingdoms/src/main-world/server",
		EntryPoint = "MainWorldServer.server.luau",
		AllowedCanonicalOwners = table.freeze({
			"ExpeditionLobbyService",
		}),
		AllowedResponsibilities = table.freeze({
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
