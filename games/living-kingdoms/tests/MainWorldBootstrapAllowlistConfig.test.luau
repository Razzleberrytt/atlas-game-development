--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldBootstrapAllowlistConfig assertion failed", 2)
	end
end

local config =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MainWorldBootstrapAllowlistConfig.luau"), {
		debugName = "MainWorldBootstrapAllowlistConfig",
		injectGlobals = true,
	})()

check(config.Version == "P0.5-MAIN-WORLD-BOOTSTRAP-ALLOWLIST-v1")
check(config.RuntimeEnabled == false)
check(config.DedicatedMainWorldOnly == true)
check(config.CurrentOperationProjectMappingAllowed == false)
check(config.SharedSourceRoot == "games/living-kingdoms/src/shared")
check(config.Server.BootstrapRoot == "games/living-kingdoms/src/main-world/server")
check(config.Server.EntryPoint == "MainWorldServer.server.luau")
check(config.Client.BootstrapRoot == "games/living-kingdoms/src/main-world/client")
check(config.Client.EntryPoint == "MainWorldClient.client.luau")
check(config.Client.ConsequentialAuthorityAllowed == false)

local forbiddenOwners = {}
for _, owner in config.Server.ForbiddenOwners do
	forbiddenOwners[owner] = true
end
check(forbiddenOwners.WorldFoundationService == true)
check(forbiddenOwners.RPGServerBootstrap == true)
check(forbiddenOwners.CombatService == true)
check(forbiddenOwners.EnemyService == true)
check(forbiddenOwners.LootService == true)
check(forbiddenOwners.MonetizationService == true)

local excluded = {}
for _, root in config.ExcludedSourceRoots do
	excluded[root] = true
end
check(excluded["games/living-kingdoms/imports"] == true)
check(excluded["games/living-kingdoms/legacy-src"] == true)
check(excluded["games/living-kingdoms/src/server"] == true)
check(excluded["games/living-kingdoms/src/client"] == true)

check(config.Rules.ExplicitEntryPointsOnly == true)
check(config.Rules.LegacyRuntimeMayNeverBeMapped == true)
check(config.Rules.OperationRuntimeRootsMayNotBeMappedWholesale == true)
check(config.Rules.NoPlaceOrUniverseIdsUntilAuthorizedPublishing == true)

check(fs.isFile("games/living-kingdoms/src/main-world/server/MainWorldServer.server.luau"))
check(fs.isFile("games/living-kingdoms/src/main-world/client/MainWorldClient.client.luau"))

local currentProject = serde.decode("json", fs.readFile("games/living-kingdoms/default.project.json"))
local projectText = serde.encode("json", currentProject)
check(
	string.find(projectText, "src/main%-world", 1) == nil,
	"current operation project must not map Main World bootstrap roots"
)
check(string.find(projectText, "legacy%-src", 1) == nil, "current operation project must not map legacy runtime")
check(string.find(projectText, "imports", 1, true) == nil, "current operation project must not map imports")
