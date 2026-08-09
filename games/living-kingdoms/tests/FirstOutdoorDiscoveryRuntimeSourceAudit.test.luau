--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-052 discovery runtime source audit failed", 2)
	end
end

local servicePath = "games/living-kingdoms/src/server/Systems/FirstOutdoorDiscoveryService.luau"
local service = fs.readFile(servicePath)
local liveRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLiveRuntimeService.luau")
local mount = fs.readFile("games/living-kingdoms/src/server/first-outdoor-discovery.server.luau")

assert(string.find(service, "FirstOutdoorDiscoveryConfig", 1, true) ~= nil)
assert(string.find(service, "WorldFoundationConfig", 1, true) ~= nil)
assert(string.find(service, "LookoutDiscoveryCache", 1, true) ~= nil)
assert(string.find(service, "RuinedFloor", 1, true) ~= nil, "cache must anchor to the generated Lookout ruin")
assert(string.find(service, "ProximityPrompt", 1, true) ~= nil, "cache requires a readable world interaction")
assert(string.find(service, "MaximumDistanceStuds", 1, true) ~= nil, "server must revalidate interaction distance")
assert(string.find(service, 'EXPECTED_PHASE_ID = "Approach"', 1, true) ~= nil, "cache must remain Approach-only")
assert(string.find(service, "SecretDiscovered == true", 1, true) ~= nil, "duplicate discovery must be rejected")
assert(string.find(service, "markSecretDiscovered(snapshot.RunId", 1, true) ~= nil, "runtime fact must commit before reward")
assert(
	string.find(service, "offerRelicRewardToParticipants", 1, true) ~= nil,
	"cache must reuse canonical RunBuildService reward fan-out"
)
assert(string.find(service, "DISCOVERY.RewardSourceId", 1, true) ~= nil, "reward source must come from BA-052 config")
assert(string.find(service, "RemoteEvent", 1, true) == nil, "BA-052 cannot create a parallel remote surface")
assert(string.find(service, "RemoteFunction", 1, true) == nil, "BA-052 cannot create a parallel remote surface")
assert(string.find(service, "DataStore", 1, true) == nil, "BA-052 cannot own persistence")
assert(string.find(service, "Touched", 1, true) == nil, "cache must not trust touch events as reward authority")

assert(
	string.find(liveRuntime, "function Service.markSecretDiscovered(expectedRunId: string, expectedPhaseId: string)", 1, true)
		~= nil,
	"live expedition owner must expose a server-only stale-run/stale-phase guarded mutation seam"
)
assert(string.find(liveRuntime, "snapshot.RunId ~= expectedRunId", 1, true) ~= nil)
assert(string.find(liveRuntime, "snapshot.PhaseId ~= expectedPhaseId", 1, true) ~= nil)
assert(string.find(liveRuntime, "bootstrap.Runtime:markSecretDiscovered()", 1, true) ~= nil)

assert(string.find(mount, "WaitForChild(WorldFoundationConfig.WorldRootName", 1, true) ~= nil)
assert(string.find(mount, 'FindFirstChild("LookoutTower", true)', 1, true) ~= nil)
assert(string.find(mount, "FirstOutdoorDiscoveryService.start()", 1, true) ~= nil)
assert(string.find(mount, "FirstOutdoorDiscoveryService.stop()", 1, true) ~= nil)

print("BA-052 FirstOutdoorDiscovery runtime ownership source audit passed")
