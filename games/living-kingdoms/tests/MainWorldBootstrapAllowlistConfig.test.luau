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

check(config.Version == "P0.5-MAIN-WORLD-BOOTSTRAP-ALLOWLIST-v2")
check(config.RuntimeEnabled == false)
check(config.DedicatedMainWorldOnly == true)
check(config.CurrentOperationProjectMappingAllowed == false)
check(config.SharedSourceRoot == "games/living-kingdoms/src/shared")
check(config.Server.BootstrapRoot == "games/living-kingdoms/src/main-world/server")
check(config.Server.EntryPoint == "MainWorldServer.server.luau")
check(config.Client.BootstrapRoot == "games/living-kingdoms/src/main-world/client")
check(config.Client.EntryPoint == "MainWorldClient.client.luau")
check(config.Client.ConsequentialAuthorityAllowed == false)

check(#config.Server.AllowedCanonicalOwners == 1)
check(config.Server.AllowedCanonicalOwners[1] == "ExpeditionLobbyService")
local operationForbidden = {}
for _, owner in config.Server.ForbiddenOperationOwners do
	operationForbidden[owner] = true
end
check(operationForbidden.WorldFoundationService == true)

local responsibilities = {}
for _, responsibility in config.Server.AllowedResponsibilities do
	responsibilities[responsibility] = true
end
check(responsibilities["static-scene-stabilization"] == true)
check(responsibilities["expedition-launch-intent"] == true)
check(responsibilities["durable-player-state-adapter"] == true)
check(responsibilities["durable-inventory-adapter"] == true)

check(config.StaticSceneStabilization.Enabled == true)
check(config.StaticSceneStabilization.WorldRootName == "LivingKingdomsMainWorld")
check(#config.StaticSceneStabilization.StaticRootNames == 38)
check(#config.StaticSceneStabilization.DynamicRootNames == 1)
check(config.StaticSceneStabilization.DynamicRootNames[1] == "NPCs")

local classifiedRoots = {}
for _, rootName in config.StaticSceneStabilization.StaticRootNames do
	check(classifiedRoots[rootName] == nil, "duplicate static Main World root classification")
	classifiedRoots[rootName] = "static"
end
for _, rootName in config.StaticSceneStabilization.DynamicRootNames do
	check(classifiedRoots[rootName] == nil, "Main World root cannot be both static and dynamic")
	classifiedRoots[rootName] = "dynamic"
end
check(classifiedRoots.NPCs == "dynamic")

local excluded = {}
for _, root in config.ExcludedActiveSourceRoots do
	excluded[root] = true
end
check(excluded["games/living-kingdoms/imports"] == true)
check(excluded["games/living-kingdoms/src/server"] == true)
check(excluded["games/living-kingdoms/src/client"] == true)

check(config.Rules.ExplicitEntryPointsOnly == true)
check(config.Rules.PreservedRuntimeMayNeverBeMapped == true)
check(config.Rules.OperationRuntimeRootsMayNotBeMappedWholesale == true)
check(config.Rules.NoPlaceOrUniverseIdsUntilAuthorizedPublishing == true)

check(fs.isFile("games/living-kingdoms/src/main-world/server/MainWorldServer.server.luau"))
check(fs.isFile("games/living-kingdoms/src/main-world/server/MainWorldStaticSceneStabilizer.luau"))
check(fs.isFile("games/living-kingdoms/src/main-world/client/MainWorldClient.client.luau"))

local mainWorldProject = serde.decode("json", fs.readFile("games/living-kingdoms/main-world.project.json"))
local mountedWorld = mainWorldProject.tree.Workspace.LivingKingdomsMainWorld
local mountedRootCount = 0
for rootName in mountedWorld do
	if string.sub(rootName, 1, 1) ~= "$" then
		mountedRootCount += 1
		check(classifiedRoots[rootName] ~= nil, "mounted Main World root must be explicitly classified")
	end
end
check(mountedRootCount == 39)
check(mountedRootCount == #config.StaticSceneStabilization.StaticRootNames + #config.StaticSceneStabilization.DynamicRootNames)
check(
	mainWorldProject.tree.ServerScriptService.MainWorldStaticSceneStabilizer["$path"]
		== "src/main-world/server/MainWorldStaticSceneStabilizer.luau"
)

local currentProject = serde.decode("json", fs.readFile("games/living-kingdoms/default.project.json"))
local projectText = serde.encode("json", currentProject)
check(
	string.find(projectText, "src/main%-world", 1) == nil,
	"current operation project must not map Main World bootstrap roots"
)
check(string.find(projectText, "legacy%-src", 1) == nil, "current operation project must not map preserved runtime")
check(string.find(projectText, "imports", 1, true) == nil, "current operation project must not map imports")
