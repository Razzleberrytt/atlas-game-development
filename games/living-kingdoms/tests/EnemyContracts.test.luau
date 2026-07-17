--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0104 enemy contract fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadSimple("games/living-kingdoms/src/shared/Enemy/EnemyContracts.luau", "EnemyContracts")
local config = loadSimple("games/living-kingdoms/src/shared/Config/EnemyConfig.luau", "EnemyConfig")
local world = loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

assert(contracts.ArchetypeIds.Shambler == "Shambler")
for _, stateId in { "Spawning", "Active", "Dead", "Removed" } do
	assert(contracts.LifecycleStateIds[stateId] == stateId, "missing lifecycle state " .. stateId)
end
for _, stateId in { "Idle", "Pursuing", "Attacking" } do
	assert(contracts.ActivityStateIds[stateId] == stateId, "missing activity state " .. stateId)
end
for _, reasonId in {
	"ServiceStopped",
	"InvalidDefinition",
	"DuplicateEntityId",
	"CapacityExceeded",
	"OutsidePlayableBounds",
	"TooCloseToLivingOperative",
	"VisibleToLivingOperative",
	"BlockedSpawnVolume",
	"CreationFailed",
} do
	assert(contracts.SpawnRejectionReasonIds[reasonId] == reasonId, "missing spawn rejection " .. reasonId)
end

assert(contracts.isLegalLifecycleTransition("Spawning", "Active"))
assert(contracts.isLegalLifecycleTransition("Spawning", "Removed"))
assert(contracts.isLegalLifecycleTransition("Active", "Dead"))
assert(contracts.isLegalLifecycleTransition("Dead", "Removed"))
assert(not contracts.isLegalLifecycleTransition("Active", "Removed"))
assert(not contracts.isLegalLifecycleTransition("Dead", "Active"))
assert(not contracts.isLegalLifecycleTransition("Removed", "Active"))

local definition = {
	entityId = "enemy.fixture.1",
	archetypeId = "Shambler",
	position = { x = 1, y = 2, z = 3 },
	facingDirection = { x = 0, y = 0, z = -1 },
	correlationId = "wave.fixture.1",
}
assert(contracts.validateSpawnDefinition(definition))
assert(not contracts.validateSpawnDefinition(nil))
assert(not contracts.validateSpawnDefinition({}))
assert(not contracts.validateSpawnDefinition({
	entityId = definition.entityId,
	archetypeId = "Boss",
	position = definition.position,
	correlationId = definition.correlationId,
}))
assert(not contracts.validateSpawnDefinition({
	entityId = definition.entityId,
	archetypeId = definition.archetypeId,
	position = { x = math.huge, y = 0, z = 0 },
	correlationId = definition.correlationId,
}))

local activeSnapshot = {
	entityId = definition.entityId,
	archetypeId = "Shambler",
	lifecycleStateId = "Active",
	activityStateId = "Pursuing",
	health = 80,
	selectedOperativeEntityId = "operative.fixture.1",
	spawnServerTimestamp = 10,
	lastAttackServerTimestamp = nil,
	cleanupDeadlineServerTimestamp = nil,
	revision = 2,
}
assert(contracts.validateSnapshot(activeSnapshot))
local deadSnapshot = table.clone(activeSnapshot)
deadSnapshot.lifecycleStateId = "Dead"
deadSnapshot.activityStateId = nil
deadSnapshot.health = 0
deadSnapshot.selectedOperativeEntityId = nil
deadSnapshot.cleanupDeadlineServerTimestamp = 20
assert(contracts.validateSnapshot(deadSnapshot))
local invalidInactiveActivity = table.clone(deadSnapshot)
invalidInactiveActivity.activityStateId = "Idle"
assert(not contracts.validateSnapshot(invalidInactiveActivity))
local invalidActiveActivity = table.clone(activeSnapshot)
invalidActiveActivity.activityStateId = nil
assert(not contracts.validateSnapshot(invalidActiveActivity))

assert(config.ArchetypeId == contracts.ArchetypeIds.Shambler)
assert(config.PlayableHalfExtentStuds == world.PlayableHalfExtentStuds)
assert(config.MaximumHealth == 100)
assert(config.TargetLossRadiusStuds >= config.AcquisitionRadiusStuds)
assert(config.MinimumFairSpawnDistanceStuds > config.AttackRangeStuds)
assert(config.MaximumActiveEnemies == 24)
assert(config.SimulationIntervalSeconds >= 0.1)
assert(table.isfrozen(contracts))
assert(table.isfrozen(config))

print("EnemyContracts fixture passed")
