--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0106 enemy observability assertion failed", 2)
	end
end

local source = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyObservabilityService.luau")

assert(source:find("EnemyLifecycleService.readAll", 1, true) ~= nil)
assert(source:find("Workspace:FindFirstChild", 1, true) ~= nil)
assert(source:find("GetDescendants", 1, true) ~= nil)
assert(source:find("activeEnemies", 1, true) ~= nil)
assert(source:find("deadEnemies", 1, true) ~= nil)
assert(source:find("ownedModels", 1, true) ~= nil)
assert(source:find("ownedBaseParts", 1, true) ~= nil)
assert(source:find("selectedTargets", 1, true) ~= nil)
assert(source:find("authorizedSchedulerConnectionBudget", 1, true) ~= nil)
assert(source:find("table.freeze", 1, true) ~= nil)
assert(source:find("Heartbeat:Connect", 1, true) == nil)
assert(source:find("task.spawn", 1, true) == nil)
assert(source:find("RemoteEvent", 1, true) == nil)
assert(source:find("OnServerEvent", 1, true) == nil)

print("EnemyObservability source audit passed")
