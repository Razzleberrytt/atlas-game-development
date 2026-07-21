--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local cache = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau")
local telemetry = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionScarcityTelemetryService.luau")
local probe = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionScarcityValidationProbeService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

check(string.find(cache, "readCollectionState", 1, true) ~= nil, "cache collection state read missing")
check(string.find(cache, "grantedRoundsByCacheId", 1, true) ~= nil, "exact grant map missing")
check(string.find(cache, "table.freeze(table.clone(processed))", 1, true) ~= nil, "processed history read must copy")
check(string.find(cache, "table.freeze(table.clone(granted))", 1, true) ~= nil, "grant history read must copy")

local commitPosition = string.find(cache, "commitReviveCombatState", 1, true)
local historyPosition = string.find(cache, "processedByPlayer[player] = table.clone", 1, true)
local grantPosition = string.find(cache, "grantedSetFor(player)[definition.cacheId]", 1, true)
check(
	commitPosition ~= nil and historyPosition ~= nil and commitPosition < historyPosition,
	"history must follow combat commit"
)
check(
	historyPosition ~= nil and grantPosition ~= nil and historyPosition < grantPosition,
	"grant telemetry must follow history"
)

check(
	string.find(telemetry, "starting rounds + committed cache grants - current rounds", 1, true) ~= nil,
	"derivation contract missing"
)
check(
	string.find(telemetry, "initialTotalRounds + cacheRoundsGranted - totalRounds", 1, true) ~= nil,
	"shot derivation missing"
)
check(string.find(telemetry, "function Service.sample", 1, true) ~= nil, "explicit sampling missing")
check(string.find(telemetry, "dryAmmunitionTransitionCount", 1, true) ~= nil, "dry transition metric missing")
check(string.find(telemetry, "remainingCacheOpportunityCount", 1, true) ~= nil, "remaining opportunity metric missing")
check(string.find(telemetry, "RemoteEvent", 1, true) == nil, "telemetry must not add a remote")
check(string.find(telemetry, "RemoteFunction", 1, true) == nil, "telemetry must not add a remote function")
check(string.find(telemetry, "Heartbeat", 1, true) == nil, "telemetry must not add a scheduler")
check(string.find(telemetry, "task.", 1, true) == nil, "telemetry must not add task scheduling")
check(string.find(telemetry, "RunService", 1, true) == nil, "telemetry sampling must remain caller-driven")

check(string.find(probe, "RunService:IsStudio()", 1, true) ~= nil, "probe must be Studio-only")
check(string.find(probe, "ServerStorage", 1, true) ~= nil, "probe must remain server-only")
check(string.find(probe, 'Instance.new("BindableFunction")', 1, true) ~= nil, "probe read controls missing")
check(string.find(probe, "ReadSnapshot", 1, true) ~= nil, "snapshot function missing")
check(string.find(probe, "ResetSampling", 1, true) ~= nil, "reset function missing")
check(string.find(probe, "RemoteEvent", 1, true) == nil, "probe must not add a remote")
check(string.find(probe, "RemoteFunction", 1, true) == nil, "probe must not add a remote function")
check(string.find(probe, "Heartbeat", 1, true) == nil, "probe must not add a scheduler")
check(string.find(probe, "task.", 1, true) == nil, "probe must not add task scheduling")

check(
	string.find(bootstrap, "AmmunitionScarcityValidationProbeService", 1, true) ~= nil,
	"scarcity validation probe not bootstrapped"
)
check(
	string.find(bootstrap, "AmmunitionScarcityValidationProbeService.start()", 1, true) ~= nil,
	"scarcity validation probe not started"
)

print("P6 scarcity telemetry source audit passed")
