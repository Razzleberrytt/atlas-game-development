--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0106 runtime observability audit assertion failed", 2)
	end
end

local operation = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyOperationIntegrationService.luau")
local observability = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyObservabilityService.luau")

assert(operation:find("function Service.readMetrics", 1, true) ~= nil)
assert(operation:find("attackAttempts += 1", 1, true) ~= nil)
assert(operation:find("attackCommits += 1", 1, true) ~= nil)
assert(operation:find("OperativeLifeService.applyAuthoritativeDamage", 1, true) ~= nil)
assert(operation:find("attackAttempts = 0", 1, true) ~= nil)
assert(operation:find("attackCommits = 0", 1, true) ~= nil)

assert(observability:find("function Service.sample", 1, true) ~= nil)
assert(observability:find("function Service.resetSampling", 1, true) ~= nil)
assert(observability:find("EnemyOperationIntegrationService.readMetrics", 1, true) ~= nil)
assert(observability:find("observedSpawns", 1, true) ~= nil)
assert(observability:find("observedRemovals", 1, true) ~= nil)
assert(observability:find("observedTargetChanges", 1, true) ~= nil)
assert(observability:find("observedModelMoves", 1, true) ~= nil)
assert(observability:find("table.freeze", 1, true) ~= nil)
assert(observability:find("RunService", 1, true) == nil)
assert(observability:find("Heartbeat", 1, true) == nil)
assert(observability:find("task.spawn", 1, true) == nil)
assert(observability:find("RemoteEvent", 1, true) == nil)
