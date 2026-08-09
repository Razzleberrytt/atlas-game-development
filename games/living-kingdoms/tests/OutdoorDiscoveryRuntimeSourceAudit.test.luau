--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-052 runtime source audit failed", 2)
	end
end

local liveRuntimeSource = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLiveRuntimeService.luau")
local discoverySource = fs.readFile("games/living-kingdoms/src/server/Systems/OutdoorDiscoveryService.luau")
local mountSource = fs.readFile("games/living-kingdoms/src/server/outdoor-discovery.server.luau")
local routeSource = fs.readFile("games/living-kingdoms/src/shared/Config/FirstOutdoorRouteConfig.luau")

assert(
	string.find(liveRuntimeSource, "function Service.markSecretDiscovered", 1, true) ~= nil,
	"live expedition owner must expose the server-only secret claim seam"
)
assert(
	string.find(liveRuntimeSource, "snapshot.PhaseId ~= PhaseIds.Approach", 1, true) ~= nil,
	"secret claim must be Approach-only"
)
assert(
	string.find(liveRuntimeSource, "snapshot.SecretDiscovered == true", 1, true) ~= nil,
	"secret claim must reject duplicate discovery"
)
assert(
	string.find(liveRuntimeSource, "runtime:markSecretDiscovered()", 1, true) ~= nil,
	"live integration must mutate the existing expedition secret state"
)

assert(string.find(discoverySource, "ProximityPrompt", 1, true) ~= nil, "Lookout Cache must expose a server-owned prompt")
assert(
	string.find(discoverySource, "Discovery.Interaction.MaximumDistanceStuds", 1, true) ~= nil,
	"Lookout Cache must revalidate server-side distance"
)
assert(
	string.find(discoverySource, "ExpeditionLiveRuntimeService.readSnapshot()", 1, true) ~= nil,
	"Lookout Cache must read the authoritative live expedition"
)
assert(
	string.find(discoverySource, "ExpeditionLiveRuntimeService.markSecretDiscovered(snapshot.RunId)", 1, true) ~= nil,
	"Lookout Cache must bind claims to the observed run id"
)
assert(
	string.find(discoverySource, "RunBuildService.offerRelicRewardToParticipants", 1, true) ~= nil,
	"Lookout Cache must reuse the canonical squad relic reward fan-out"
)
assert(
	string.find(discoverySource, "Discovery.RewardSourceId", 1, true) ~= nil,
	"Lookout Cache reward source must remain config-owned"
)
assert(string.find(discoverySource, "FireServer", 1, true) == nil, "discovery runtime cannot trust a client mutation")
assert(string.find(discoverySource, "RemoteEvent", 1, true) == nil, "discovery runtime cannot create a parallel remote")
assert(string.find(discoverySource, "DataStore", 1, true) == nil, "discovery runtime cannot create account persistence")

assert(string.find(mountSource, "OutdoorDiscoveryService.start()", 1, true) ~= nil, "discovery runtime must be mounted")
assert(
	string.find(routeSource, "RuntimeConsumptionActive = false", 1, true) ~= nil,
	"BA-050 imported route geometry must remain held"
)

print("BA-052 OutdoorDiscoveryRuntime source audit passed")
