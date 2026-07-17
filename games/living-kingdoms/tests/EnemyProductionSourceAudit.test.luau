--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0104 source audit assertion failed", 2)
	end
end

local function read(path: string): string
	return fs.readFile(path)
end

local bootstrap = read("games/living-kingdoms/src/server/init.server.luau")
local lifecycle = read("games/living-kingdoms/src/server/Systems/EnemyLifecycleService.luau")
local operation = read("games/living-kingdoms/src/server/Systems/EnemyOperationIntegrationService.luau")
local combat = read("games/living-kingdoms/src/server/Systems/ProductionAutomaticCombatService.luau")
local mission = read("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")

assert(bootstrap:find("ProductionAutomaticCombatService", 1, true) ~= nil)
assert(bootstrap:find("AutomaticCombatDevelopmentHarness.start", 1, true) == nil)
assert(combat:find("EnemyLifecycleService.applyAuthoritativeDamage", 1, true) ~= nil)
assert(combat:find("AutomaticFireResolver.resolve", 1, true) ~= nil)
assert(combat:find("FirearmHitResolver.resolve", 1, true) ~= nil)
assert(combat:find("TargetCandidateSelector.select", 1, true) ~= nil)
assert(operation:find("OperativeLifeService.applyAuthoritativeDamage", 1, true) ~= nil)
assert(operation:find("spawnMissionHostile", 1, true) == nil)
assert(lifecycle:find("RemoteEvent", 1, true) == nil)
assert(operation:find("RemoteEvent", 1, true) == nil)
assert(combat:find("OnServerEvent", 1, true) ~= nil, "reload remains the only client combat intent")
assert(combat:find("task.spawn", 1, true) == nil)
assert(lifecycle:find("RunService.Heartbeat:Connect", 1, true) ~= nil)
assert(operation:find("RunService.Heartbeat:Connect", 1, true) ~= nil)
assert(combat:find("RunService.Heartbeat:Connect", 1, true) ~= nil)
assert(mission:find("AutomaticCombatDevelopmentHarness.spawnMissionHostile", 1, true) ~= nil,
	"legacy call remains inert because the development harness is not started")
