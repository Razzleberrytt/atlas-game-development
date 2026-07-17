--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0104 enemy domain fixture assertion failed", 2)
	end
end

local function loadDomain()
	local source = fs.readFile("games/living-kingdoms/src/server/Domain/EnemyDomain.luau")
	local dependencyPattern = 'local ReplicatedStorage = game:GetService%("ReplicatedStorage"%)\n\nlocal EnemyContracts = require%(ReplicatedStorage.Shared.Enemy.EnemyContracts%)\nlocal EnemyConfig = require%(ReplicatedStorage.Shared.Config.EnemyConfig%)'
	local dependencyStub = [[local EnemyContracts = {
	SpawnRejectionReasonIds = {
		ServiceStopped = "ServiceStopped",
		InvalidDefinition = "InvalidDefinition",
		DuplicateEntityId = "DuplicateEntityId",
		CapacityExceeded = "CapacityExceeded",
		OutsidePlayableBounds = "OutsidePlayableBounds",
		TooCloseToLivingOperative = "TooCloseToLivingOperative",
		VisibleToLivingOperative = "VisibleToLivingOperative",
		BlockedSpawnVolume = "BlockedSpawnVolume",
		CreationFailed = "CreationFailed",
	},
	DamageRejectionReasonIds = {
		InvalidRequest = "InvalidRequest",
		InvalidLifecycleState = "InvalidLifecycleState",
		StaleRevision = "StaleRevision",
		DuplicateCorrelation = "DuplicateCorrelation",
	},
	LifecycleStateIds = {
		Active = "Active",
		Dead = "Dead",
	},
}
local EnemyConfig = {
	MaximumActiveEnemies = 24,
	MinimumFairSpawnDistanceStuds = 55,
	AcquisitionRadiusStuds = 150,
	TargetLossRadiusStuds = 190,
	AttackRangeStuds = 4.5,
	AttackCadenceSeconds = 1.35,
}]]
	local rewritten, replacementCount = source:gsub(dependencyPattern, dependencyStub)
	assert(replacementCount == 1, "enemy domain dependency boundary changed")
	return luau.load(rewritten, {
		debugName = "EnemyDomain",
		injectGlobals = true,
	})()
end

local domain = loadDomain()

local validSpawnFacts = {
	serviceRunning = true,
	definitionValid = true,
	duplicateEntityId = false,
	activeEnemyCount = 0,
	insidePlayableBounds = true,
	minimumLivingOperativeDistance = 80,
	visibleToLivingOperative = false,
	spawnVolumeBlocked = false,
	creationSucceeded = true,
}

local function expectSpawnRejection(overrides: { [string]: any }, expectedReason: string)
	local facts = table.clone(validSpawnFacts)
	for key, value in overrides do
		facts[key] = value
	end
	local accepted, reason = domain.validateSpawnFacts(facts)
	assert(not accepted, "spawn unexpectedly accepted")
	assert(reason == expectedReason, string.format("expected %s, received %s", expectedReason, tostring(reason)))
end

local accepted, reason = domain.validateSpawnFacts(validSpawnFacts)
assert(accepted and reason == nil, "valid spawn facts must be accepted")
expectSpawnRejection({ serviceRunning = false, definitionValid = false }, "ServiceStopped")
expectSpawnRejection({ definitionValid = false, duplicateEntityId = true }, "InvalidDefinition")
expectSpawnRejection({ duplicateEntityId = true, activeEnemyCount = 24 }, "DuplicateEntityId")
expectSpawnRejection({ activeEnemyCount = 24, insidePlayableBounds = false }, "CapacityExceeded")
expectSpawnRejection({ insidePlayableBounds = false, minimumLivingOperativeDistance = 0 }, "OutsidePlayableBounds")
expectSpawnRejection({ minimumLivingOperativeDistance = 54, visibleToLivingOperative = true }, "TooCloseToLivingOperative")
expectSpawnRejection({ visibleToLivingOperative = true, spawnVolumeBlocked = true }, "VisibleToLivingOperative")
expectSpawnRejection({ spawnVolumeBlocked = true, creationSucceeded = false }, "BlockedSpawnVolume")
expectSpawnRejection({ creationSucceeded = false }, "CreationFailed")

local enemyPosition = { x = 0, y = 0, z = 0 }
local candidates = {
	{ entityId = "operative.b", position = { x = 10, y = 0, z = 0 }, lifeStateId = "Alive" },
	{ entityId = "operative.a", position = { x = -10, y = 0, z = 0 }, lifeStateId = "Alive" },
	{ entityId = "operative.dead", position = { x = 1, y = 0, z = 0 }, lifeStateId = "Dead" },
}
assert(domain.selectTarget(enemyPosition, nil, candidates) == "operative.a", "equal-distance ties must use entity ID")
assert(domain.selectTarget(enemyPosition, "operative.b", candidates) == "operative.b", "legal current target must be retained")
candidates[1].position.x = 191
assert(domain.selectTarget(enemyPosition, "operative.b", candidates) == "operative.a", "target beyond loss radius must be replaced")
candidates[2].position.x = 151
assert(domain.selectTarget(enemyPosition, nil, candidates) == nil, "targets beyond acquisition radius must be rejected")

local initialDamageState = {
	lifecycleStateId = "Active",
	health = 100,
	revision = 7,
	processedCorrelations = {},
}
local didCommit, rejection, damaged = domain.applyAuthorizedDamage(initialDamageState, "shot.1", 35, 7)
assert(didCommit and rejection == nil, "authorized damage must commit")
assert(damaged.health == 65 and damaged.revision == 8, "damage must subtract and advance revision")
assert(damaged.processedCorrelations["shot.1"] == true, "accepted correlation must be recorded")
assert(initialDamageState.health == 100 and initialDamageState.revision == 7, "input state must remain immutable")
assert(initialDamageState.processedCorrelations["shot.1"] == nil, "input correlation table must remain immutable")

local duplicateCommit, duplicateReason = domain.applyAuthorizedDamage(damaged, "shot.1", 35, 8)
assert(not duplicateCommit and duplicateReason == "DuplicateCorrelation", "duplicate shots must fail closed")
local staleCommit, staleReason = domain.applyAuthorizedDamage(damaged, "shot.2", 35, 7)
assert(not staleCommit and staleReason == "StaleRevision", "stale revisions must reject")
local invalidCommit, invalidReason = domain.applyAuthorizedDamage(damaged, "shot.2", 0 / 0, 8)
assert(not invalidCommit and invalidReason == "InvalidRequest", "NaN damage must reject")

local exactCommit, exactReason, exactDeath = domain.applyAuthorizedDamage(damaged, "shot.2", 65, 8)
assert(exactCommit and exactReason == nil, "exact-zero damage must commit")
assert(exactDeath.health == 0 and exactDeath.lifecycleStateId == "Dead", "exact-zero damage must kill")
local overkillCommit, overkillReason, overkillDeath = domain.applyAuthorizedDamage(damaged, "shot.3", 500, 8)
assert(overkillCommit and overkillReason == nil, "overkill damage must commit")
assert(overkillDeath.health == 0 and overkillDeath.lifecycleStateId == "Dead", "overkill must clamp to zero")
local deadCommit, deadReason = domain.applyAuthorizedDamage(exactDeath, "shot.4", 1, 9)
assert(not deadCommit and deadReason == "InvalidLifecycleState", "dead enemies must reject further damage")

assert(domain.isAttackReady(enemyPosition, { x = 4.5, y = 0, z = 0 }, nil, 10, false))
assert(not domain.isAttackReady(enemyPosition, { x = 4.6, y = 0, z = 0 }, nil, 10, false))
assert(not domain.isAttackReady(enemyPosition, { x = 4, y = 0, z = 0 }, nil, 10, true))
assert(not domain.isAttackReady(enemyPosition, { x = 4, y = 0, z = 0 }, 9, 10, false))
assert(domain.isAttackReady(enemyPosition, { x = 4, y = 0, z = 0 }, 9, 10.35, false))

print("EnemyDomain fixture passed")
