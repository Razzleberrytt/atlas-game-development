--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "enemy validation probe fixture assertion failed", 2)
	end
end

local probePath = "games/living-kingdoms/src/server/Systems/EnemyValidationProbeService.luau"
local directorPath = "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau"
local probe = fs.readFile(probePath)
local director = fs.readFile(directorPath)

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

-- The probe must stay Studio-only and server-local. It is evidence tooling, not
-- a second gameplay/network authority.
assert(contains(probe, "RunService:IsStudio()"), "probe must remain Studio-only")
assert(contains(probe, "BindableFunction"), "probe should expose only server-local bindables")
assert(not contains(probe, "RemoteEvent"), "probe must not create a RemoteEvent")
assert(not contains(probe, "RemoteFunction"), "probe must not create a RemoteFunction")
assert(not contains(probe, "Heartbeat"), "probe must not add a heartbeat sampler")
assert(not contains(probe, "RenderStepped"), "probe must not add a render-loop sampler")
assert(not contains(probe, "Stepped"), "probe must not add a stepped-loop sampler")

-- The probe reads the canonical director instead of inventing a second crowd
-- count or pressure owner.
assert(contains(probe, "EnemyDirectorService.readPressureState()"), "probe must read canonical pressure state")
assert(
	contains(probe, "EnemyDirectorService.readEnemyCombatFacts()"),
	"probe must read canonical combat-fact state"
)
assert(contains(director, "function EnemyDirectorService.readPressureState()"), "director pressure read API drifted")
assert(
	contains(director, "function EnemyDirectorService.readEnemyCombatFacts()"),
	"director combat-fact read API drifted"
)

-- Repeated explicit samples retain the first useful crowd-pressure summary for
-- HROI validation without running a hidden background scheduler.
for _, token in {
	"sampleCount",
	"baselineActiveEnemyCount",
	"baselinePendingSpawnCount",
	"baselineEscalationLevel",
	"peakActiveEnemyCount",
	"peakPendingSpawnCount",
	"peakEscalationLevel",
	"averageActiveEnemyCount",
	"averagePendingSpawnCount",
	"ResetMetrics",
} do
	assert(contains(probe, token), "missing retained pressure metric: " .. token)
end

assert(contains(probe, "math.max(peakActiveEnemyCount"), "active-enemy peak must be monotonic within a window")
assert(contains(probe, "math.max(peakPendingSpawnCount"), "pending-spawn peak must be monotonic within a window")
assert(contains(probe, "math.max(peakEscalationLevel"), "escalation peak must be monotonic within a window")
assert(contains(probe, "totalActiveEnemyCount / sampleCount"), "active-enemy average must derive from samples")
assert(contains(probe, "totalPendingSpawnCount / sampleCount"), "pending-spawn average must derive from samples")

print("EnemyValidationProbeService retained pressure metrics fixture passed")
