--!strict

-- P5-0104 pure enemy decisions: fair-spawn ordering and boundaries, detection,
-- pursuit hysteresis, tie-breaks, attack range/cooldown legality, inert states,
-- determinism, and input immutability.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P5-0104 enemy behavior fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local worldConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

local CONTRACTS_TOKEN = {}
local WORLD_TOKEN = {}
local CONFIG_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
	debugName = "EnemyConfig",
	environment = {
		script = {
			Parent = {
				WorldFoundationConfig = WORLD_TOKEN,
				Parent = { Combat = { EnemyContracts = CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			if token == WORLD_TOKEN then
				return worldConfig
			end
			error("unexpected EnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local replicatedStorage = {
	Shared = {
		Combat = { EnemyContracts = CONTRACTS_TOKEN },
		Config = { EnemyConfig = CONFIG_TOKEN },
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EnemyBehaviorResolver.luau"), {
	debugName = "EnemyBehaviorResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			if token == CONFIG_TOKEN then
				return config
			end
			error("unexpected resolver dependency")
		end,
	},
	injectGlobals = true,
})()

local minimumSpawn = config.FairSpawn.MinimumOperativeDistanceStuds
local halfExtent = worldConfig.PlayableHalfExtentStuds

local function spawnRequest(overrides: { [string]: any }?)
	local request = {
		entityId = "enemy.test.alpha",
		archetypeId = "enemy.exclusion_walker",
		spawnSourceId = "AuthoredWave",
		displayName = "Test Walker",
		position = { x = 0, y = 3, z = 0 },
	}
	for key, value in overrides or {} do
		request[key] = value
	end
	return request
end

local function spawnFacts(overrides: { [string]: any }?)
	local facts = {
		existingEnemyEntityIds = {},
		activeEnemyCount = 0,
		populationCap = 24,
		playableHalfExtentStuds = halfExtent,
		alivePositions = {},
	}
	for key, value in overrides or {} do
		facts[key] = value
	end
	return facts
end

-- Fair-spawn validation shape failures.
assert(resolver.resolveSpawn(nil :: any, spawnFacts()).rejectionReasonId == "InvalidDefinition")
assert(resolver.resolveSpawn(spawnRequest({ entityId = "" }), spawnFacts()).rejectionReasonId == "InvalidDefinition")
assert(
	resolver.resolveSpawn(spawnRequest({ archetypeId = "enemy.unknown" }), spawnFacts()).rejectionReasonId
		== "InvalidDefinition"
)
assert(
	resolver.resolveSpawn(spawnRequest({ spawnSourceId = "ClientRequest" }), spawnFacts()).rejectionReasonId
		== "InvalidDefinition"
)
assert(resolver.resolveSpawn(spawnRequest({ displayName = "" }), spawnFacts()).rejectionReasonId == "InvalidDefinition")
assert(
	resolver.resolveSpawn(spawnRequest({ position = { x = 0 / 0, y = 0, z = 0 } }), spawnFacts()).rejectionReasonId
		== "InvalidDefinition"
)
assert(resolver.resolveSpawn(spawnRequest(), nil :: any).rejectionReasonId == "InvalidDefinition")

-- Legal spawn with no operatives nearby.
local legal = resolver.resolveSpawn(spawnRequest(), spawnFacts())
assert(legal.isLegal and legal.rejectionReasonId == nil)

-- Stable first-failure order: duplicate precedes cap, cap precedes extent,
-- extent precedes fairness.
assert(resolver.resolveSpawn(
	spawnRequest(),
	spawnFacts({
		existingEnemyEntityIds = { ["enemy.test.alpha"] = true },
		activeEnemyCount = 24,
		alivePositions = { { x = 0, y = 0, z = 0 } },
	})
).rejectionReasonId == "DuplicateEntityId")
assert(
	resolver.resolveSpawn(
		spawnRequest({ position = { x = halfExtent + 1, y = 3, z = 0 } }),
		spawnFacts({ activeEnemyCount = 24, alivePositions = { { x = halfExtent + 1, y = 0, z = 0 } } })
	).rejectionReasonId == "PopulationCapReached"
)
assert(
	resolver.resolveSpawn(
		spawnRequest({ position = { x = halfExtent + 1, y = 3, z = 0 } }),
		spawnFacts({ alivePositions = { { x = halfExtent + 1, y = 0, z = 0 } } })
	).rejectionReasonId == "OutsidePlayableExtent"
)

-- Extent boundary is inclusive.
assert(
	resolver.resolveSpawn(spawnRequest({ position = { x = halfExtent, y = 3, z = -halfExtent } }), spawnFacts()).isLegal
)

-- Fairness distance is horizontal and inclusive at exactly the minimum.
assert(
	resolver.resolveSpawn(spawnRequest(), spawnFacts({ alivePositions = { { x = minimumSpawn, y = 500, z = 0 } } })).isLegal,
	"exactly the fair-spawn distance must be legal regardless of elevation"
)
assert(
	resolver.resolveSpawn(
		spawnRequest(),
		spawnFacts({ alivePositions = { { x = minimumSpawn - 0.01, y = 0, z = 0 } } })
	).rejectionReasonId == "TooCloseToOperative"
)
assert(
	resolver.resolveSpawn(
		spawnRequest(),
		spawnFacts({ alivePositions = { { x = minimumSpawn + 40, y = 0, z = 0 }, { x = 0, y = 0, z = 10 } } })
	).rejectionReasonId == "TooCloseToOperative",
	"every alive operative constrains fairness"
)

-- Behavior facts validation.
local walker = config.Walker
local function enemyFacts(overrides: { [string]: any }?)
	local facts = {
		entityId = "enemy.test.alpha",
		behaviorStateId = "Roaming",
		position = { x = 0, y = 3, z = 0 },
		targetOperativeEntityId = nil,
		lastAttackServerTimestamp = nil,
		attackWindupTargetOperativeEntityId = nil,
		attackWindupStartedServerTimestamp = nil,
	}
	for key, value in overrides or {} do
		facts[key] = value
	end
	return facts
end
local function operative(id: string, x: number, z: number, isAlive: boolean?)
	return {
		operativeEntityId = id,
		isAlive = isAlive ~= false,
		position = { x = x, y = 0, z = z },
	}
end

assert(resolver.resolveBehavior(nil :: any, {}, 10).rejectionReasonId == "InvalidFacts")
assert(
	resolver.resolveBehavior(enemyFacts({ behaviorStateId = "Sprinting" }), {}, 10).rejectionReasonId == "InvalidFacts"
)
local badTime = resolver.resolveBehavior(enemyFacts({ behaviorStateId = "Pursuing" }), {}, 0 / 0)
assert(badTime.rejectionReasonId == "InvalidTimestamp" and badTime.behaviorStateIdAfter == "Pursuing")
assert(resolver.resolveBehavior(enemyFacts(), {}, -1).rejectionReasonId == "InvalidTimestamp")

-- Inert states.
local dead = resolver.resolveBehavior(enemyFacts({ behaviorStateId = "Dead" }), { operative("operative:a", 1, 0) }, 10)
assert(dead.behaviorStateIdAfter == "Dead" and not dead.shouldAttack and dead.targetOperativeEntityId == nil)
local stood =
	resolver.resolveBehavior(enemyFacts({ behaviorStateId = "StandDown" }), { operative("operative:a", 1, 0) }, 10)
assert(stood.behaviorStateIdAfter == "StandDown" and not stood.shouldAttack)

-- No operative in detection: roam.
local roaming =
	resolver.resolveBehavior(enemyFacts(), { operative("operative:a", walker.DetectionRadiusStuds + 1, 0) }, 10)
assert(roaming.behaviorStateIdAfter == "Roaming" and roaming.targetOperativeEntityId == nil)

-- Dead operatives are never targets.
assert(
	resolver.resolveBehavior(enemyFacts(), { operative("operative:a", 20, 0, false) }, 10).behaviorStateIdAfter
		== "Roaming"
)

-- Detection selects the nearest; exact ties break to the lexically smallest ID.
local pursuit = resolver.resolveBehavior(
	enemyFacts(),
	{ operative("operative:far", 40, 0), operative("operative:near", 20, 0) },
	10
)
assert(pursuit.behaviorStateIdAfter == "Pursuing" and pursuit.targetOperativeEntityId == "operative:near")
local tie = resolver.resolveBehavior(
	enemyFacts(),
	{ operative("operative:bravo", 30, 0), operative("operative:alpha", 0, 30) },
	10
)
assert(tie.targetOperativeEntityId == "operative:alpha", "exact distance ties must break deterministically")

-- Detection boundary is inclusive; elevation is ignored.
assert(
	resolver.resolveBehavior(enemyFacts(), { operative("operative:a", walker.DetectionRadiusStuds, 0) }, 10).behaviorStateIdAfter
		== "Pursuing"
)

-- Pursuit hysteresis: a current target beyond detection but inside the drop
-- radius is retained, even when a new closer operative exists outside detection.
local retained = resolver.resolveBehavior(
	enemyFacts({ behaviorStateId = "Pursuing", targetOperativeEntityId = "operative:chased" }),
	{ operative("operative:chased", walker.PursuitDropRadiusStuds, 0) },
	10
)
assert(retained.behaviorStateIdAfter == "Pursuing" and retained.targetOperativeEntityId == "operative:chased")
local dropped = resolver.resolveBehavior(
	enemyFacts({ behaviorStateId = "Pursuing", targetOperativeEntityId = "operative:chased" }),
	{ operative("operative:chased", walker.PursuitDropRadiusStuds + 0.01, 0) },
	10
)
assert(dropped.behaviorStateIdAfter == "Roaming" and dropped.targetOperativeEntityId == nil)
-- The retained victim keeps the enemy committed even when someone else is
-- closer: threat facts must reflect actual intent, not proximity.
local committed = resolver.resolveBehavior(
	enemyFacts({ behaviorStateId = "Pursuing", targetOperativeEntityId = "operative:chased" }),
	{ operative("operative:chased", 50, 0), operative("operative:closer", 20, 0) },
	10
)
assert(committed.targetOperativeEntityId == "operative:chased")

-- Attack range is inclusive, but damage begins with a real server-owned windup.
local beginWindup = resolver.resolveBehavior(enemyFacts(), { operative("operative:a", walker.AttackRangeStuds, 0) }, 10)
assert(beginWindup.behaviorStateIdAfter == "WindingUp")
assert(beginWindup.attackWindupActionId == "Begin" and not beginWindup.shouldAttack and beginWindup.attack == nil)

local windingFacts = enemyFacts({
	behaviorStateId = "WindingUp",
	targetOperativeEntityId = "operative:a",
	attackWindupTargetOperativeEntityId = "operative:a",
	attackWindupStartedServerTimestamp = 10,
})
local continuing =
	resolver.resolveBehavior(windingFacts, { operative("operative:a", 2, 0) }, 10 + walker.AttackWindupSeconds - 0.01)
assert(continuing.behaviorStateIdAfter == "WindingUp" and continuing.attackWindupActionId == "Continue")
assert(not continuing.shouldAttack and continuing.attack == nil)
local commit =
	resolver.resolveBehavior(windingFacts, { operative("operative:a", 2, 0) }, 10 + walker.AttackWindupSeconds)
assert(commit.behaviorStateIdAfter == "WindingUp" and commit.attackWindupActionId == "Commit" and commit.shouldAttack)
local attack = commit.attack
assert(attack ~= nil)
assert(attack.damageEventId == "enemyattack:enemy.test.alpha:operative:a:10")
assert(attack.sourceEntityId == "enemy.test.alpha" and attack.targetEntityId == "operative:a")
assert(attack.damageAmount == walker.AttackDamage and attack.serverTimestamp == 10 + walker.AttackWindupSeconds)

local canceled =
	resolver.resolveBehavior(windingFacts, { operative("operative:a", walker.AttackRangeStuds + 0.01, 0) }, 10.2)
assert(canceled.behaviorStateIdAfter == "Pursuing" and canceled.attackWindupActionId == "Cancel")
assert(not canceled.shouldAttack and canceled.attack == nil)

-- Partial or fabricated windup facts are invalid.
assert(
	resolver.resolveBehavior(enemyFacts({ behaviorStateId = "WindingUp" }), { operative("operative:a", 2, 0) }, 10).rejectionReasonId
		== "InvalidFacts"
)
assert(
	resolver.resolveBehavior(
		enemyFacts({ attackWindupTargetOperativeEntityId = "operative:a" }),
		{ operative("operative:a", 2, 0) },
		10
	).rejectionReasonId == "InvalidFacts"
)

-- Cooldown gate: just before is blocked; exactly at the deadline starts the next windup.
local blocked = resolver.resolveBehavior(
	enemyFacts({ lastAttackServerTimestamp = 10 }),
	{ operative("operative:a", 2, 0) },
	10 + walker.AttackCooldownSeconds - 0.01
)
assert(blocked.behaviorStateIdAfter == "Attacking" and blocked.attackWindupActionId == "None")
assert(not blocked.shouldAttack and blocked.attack == nil)
local secondWindup = resolver.resolveBehavior(
	enemyFacts({ lastAttackServerTimestamp = 10 }),
	{ operative("operative:a", 2, 0) },
	10 + walker.AttackCooldownSeconds
)
assert(secondWindup.behaviorStateIdAfter == "WindingUp" and secondWindup.attackWindupActionId == "Begin")

-- Just outside melee range pursues instead of attacking.
assert(
	resolver.resolveBehavior(enemyFacts(), { operative("operative:a", walker.AttackRangeStuds + 0.01, 0) }, 10).behaviorStateIdAfter
		== "Pursuing"
)

-- Determinism and immutability: identical inputs give identical decisions and
-- inputs are never mutated.
local frozenEnemy = table.freeze(enemyFacts({ position = table.freeze({ x = 0, y = 3, z = 0 }) }))
local frozenOperatives = table.freeze({
	table.freeze(operative("operative:a", 4, 0)),
})
local first = resolver.resolveBehavior(frozenEnemy, frozenOperatives, 25)
local second = resolver.resolveBehavior(frozenEnemy, frozenOperatives, 25)
assert(first.shouldAttack == second.shouldAttack and not first.shouldAttack)
assert(first.behaviorStateIdAfter == second.behaviorStateIdAfter and first.behaviorStateIdAfter == "WindingUp")
assert(first.attackWindupActionId == second.attackWindupActionId and first.attackWindupActionId == "Begin")
assert(first.attack == nil and second.attack == nil)
local frozenRequest = table.freeze(spawnRequest({ position = table.freeze({ x = 0, y = 3, z = 0 }) }))
local frozenFacts = table.freeze(spawnFacts({
	existingEnemyEntityIds = table.freeze({}),
	alivePositions = table.freeze({ table.freeze({ x = 200, y = 0, z = 0 }) }),
}))
assert(resolver.resolveSpawn(frozenRequest, frozenFacts).isLegal)

print("EnemyBehaviorResolver: P5-0104 fair spawns, detection, hysteresis, attacks, cooldowns, and determinism passed")
