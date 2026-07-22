--!strict

-- P9-0101 pure Blight Spitter decisions: fact/timestamp validation, charge-fact
-- consistency, densest-cluster targeting and tie-breaks, engagement/cooldown
-- gating, the charge lifecycle (Begin/Continue/Commit), the commit burst against
-- operatives in the impact radius, the lingering-pool tick, inert states,
-- determinism, and input immutability.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P9-0101 special-enemy behavior fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local enemyContracts = loadSimple("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau", "EnemyContracts")
local worldConfig =
	loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

local ENEMY_CONTRACTS_TOKEN = {}
local specialContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/SpecialEnemyContracts.luau"), {
	debugName = "SpecialEnemyContracts",
	environment = {
		script = { Parent = { EnemyContracts = ENEMY_CONTRACTS_TOKEN } },
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			end
			error("unexpected SpecialEnemyContracts dependency")
		end,
	},
	injectGlobals = true,
})()

local WORLD_TOKEN = {}
local ENEMY_CONTRACTS_CONFIG_TOKEN = {}
local enemyConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
	debugName = "EnemyConfig",
	environment = {
		script = {
			Parent = {
				WorldFoundationConfig = WORLD_TOKEN,
				Parent = { Combat = { EnemyContracts = ENEMY_CONTRACTS_CONFIG_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_CONFIG_TOKEN then
				return enemyContracts
			end
			if token == WORLD_TOKEN then
				return worldConfig
			end
			error("unexpected EnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local ENEMY_CONFIG_TOKEN = {}
local SPECIAL_CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/SpecialEnemyConfig.luau"), {
	debugName = "SpecialEnemyConfig",
	environment = {
		script = {
			Parent = {
				EnemyConfig = ENEMY_CONFIG_TOKEN,
				Parent = { Combat = { SpecialEnemyContracts = SPECIAL_CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			end
			if token == SPECIAL_CONTRACTS_TOKEN then
				return specialContracts
			end
			error("unexpected SpecialEnemyConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Combat = { SpecialEnemyContracts = CONTRACTS_TOKEN },
		Config = { SpecialEnemyConfig = CONFIG_TOKEN },
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/SpecialEnemyBehaviorResolver.luau"), {
	debugName = "SpecialEnemyBehaviorResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return specialContracts
			end
			if token == CONFIG_TOKEN then
				return config
			end
			error("unexpected resolver dependency")
		end,
	},
	injectGlobals = true,
})()

local spitter = config.BlightSpitter
local bloom = config.Bloom
local lingering = bloom.Lingering

local function enemyFacts(overrides: { [string]: any }?)
	local facts = {
		entityId = "enemy.spitter.alpha",
		behaviorStateId = "Roaming",
		position = { x = 0, y = 3, z = 0 },
		anchorOperativeEntityId = nil,
		lastBloomCommitServerTimestamp = nil,
		bloomChargeTargetPosition = nil,
		bloomChargeStartedServerTimestamp = nil,
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

local function impactByTarget(impacts: { any })
	local byTarget = {}
	for _, impact in impacts do
		byTarget[impact.targetEntityId] = impact
	end
	return byTarget
end

-- Fact and timestamp validation.
assert(resolver.resolveBehavior(nil :: any, {}, 10).rejectionReasonId == "InvalidFacts")
assert(resolver.resolveBehavior(enemyFacts({ entityId = "" }), {}, 10).rejectionReasonId == "InvalidFacts")
assert(
	resolver.resolveBehavior(enemyFacts({ behaviorStateId = "Lunging" }), {}, 10).rejectionReasonId == "InvalidFacts"
)
assert(
	resolver.resolveBehavior(enemyFacts({ position = { x = 0 / 0, y = 0, z = 0 } }), {}, 10).rejectionReasonId
		== "InvalidFacts"
)
assert(
	resolver.resolveBehavior(enemyFacts({ anchorOperativeEntityId = "" }), {}, 10).rejectionReasonId == "InvalidFacts"
)
local badTime = resolver.resolveBehavior(enemyFacts({ behaviorStateId = "Approaching" }), {}, 0 / 0)
assert(badTime.rejectionReasonId == "InvalidTimestamp" and badTime.behaviorStateIdAfter == "Approaching")
assert(resolver.resolveBehavior(enemyFacts(), {}, -1).rejectionReasonId == "InvalidTimestamp")

-- A commit timestamp cannot be in the future.
assert(
	resolver.resolveBehavior(enemyFacts({ lastBloomCommitServerTimestamp = 100 }), {}, 10).rejectionReasonId
		== "InvalidFacts"
)

-- Charge-fact consistency: partial or state-mismatched charge facts fail closed.
assert(
	resolver.resolveBehavior(enemyFacts({ behaviorStateId = "Charging" }), {}, 10).rejectionReasonId == "InvalidFacts",
	"Charging without charge facts is invalid"
)
assert(
	resolver.resolveBehavior(enemyFacts({ bloomChargeTargetPosition = { x = 0, y = 0, z = 0 } }), {}, 10).rejectionReasonId
		== "InvalidFacts",
	"a charge target without a start time is invalid"
)
assert(resolver.resolveBehavior(
	enemyFacts({
		behaviorStateId = "Charging",
		bloomChargeTargetPosition = { x = 0, y = 0, z = 0 },
		bloomChargeStartedServerTimestamp = 20,
	}),
	{},
	10
).rejectionReasonId == "InvalidFacts", "a charge that started in the future is invalid")
assert(resolver.resolveBehavior(
	enemyFacts({
		bloomChargeTargetPosition = { x = 0, y = 0, z = 0 },
		bloomChargeStartedServerTimestamp = 5,
	}),
	{},
	10
).rejectionReasonId == "InvalidFacts", "charge facts without the Charging state are invalid")

-- Inert states: dead and stood-down Spitters take no action and never commit.
-- Killing a Spitter mid-charge is the interrupt — the director marks it Dead and
-- clears the charge facts, so the pending bloom simply never commits. (Dead or
-- stood-down facts must not carry a live charge; that inconsistency fails closed
-- above, so the inert branches only ever see cleared charge facts.)
local dead = resolver.resolveBehavior(enemyFacts({ behaviorStateId = "Dead" }), { operative("op:a", 10, 0) }, 10)
assert(dead.behaviorStateIdAfter == "Dead" and not dead.shouldCommitBloom and dead.bloomActionId == "None")
assert(#dead.bloomImpacts == 0 and dead.anchorOperativeEntityId == nil)
local stood = resolver.resolveBehavior(enemyFacts({ behaviorStateId = "StandDown" }), { operative("op:a", 10, 0) }, 10)
assert(stood.behaviorStateIdAfter == "StandDown" and not stood.shouldCommitBloom and #stood.bloomImpacts == 0)
-- Dead/stood-down facts that still carry a live charge are rejected, not committed.
assert(resolver.resolveBehavior(
	enemyFacts({
		behaviorStateId = "Dead",
		bloomChargeTargetPosition = { x = 10, y = 0, z = 0 },
		bloomChargeStartedServerTimestamp = 5,
	}),
	{ operative("op:a", 10, 0) },
	6
).rejectionReasonId == "InvalidFacts")

-- No operative in detection: roam.
local roaming = resolver.resolveBehavior(enemyFacts(), { operative("op:a", spitter.DetectionRadiusStuds + 1, 0) }, 10)
assert(roaming.behaviorStateIdAfter == "Roaming" and roaming.anchorOperativeEntityId == nil)

-- Dead operatives never anchor a bloom.
assert(
	resolver.resolveBehavior(enemyFacts(), { operative("op:a", 30, 0, false) }, 10).behaviorStateIdAfter == "Roaming"
)

-- Detected but beyond bloom range: approach, do not charge.
local approaching =
	resolver.resolveBehavior(enemyFacts(), { operative("op:a", spitter.BloomEngagementRangeStuds + 5, 0) }, 10)
assert(approaching.behaviorStateIdAfter == "Approaching" and approaching.anchorOperativeEntityId == "op:a")
assert(approaching.bloomActionId == "None" and not approaching.shouldCommitBloom)

-- In bloom range with the ability ready: begin a charge locked on the anchor.
local begin = resolver.resolveBehavior(enemyFacts(), { operative("op:a", 40, 0) }, 10)
assert(begin.behaviorStateIdAfter == "Charging" and begin.bloomActionId == "Begin")
assert(begin.anchorOperativeEntityId == "op:a" and not begin.shouldCommitBloom)
assert(begin.bloomTargetPosition ~= nil and begin.bloomTargetPosition.x == 40 and begin.bloomTargetPosition.z == 0)

-- The densest cluster anchors the bloom even when a lone operative is closer.
local dense = resolver.resolveBehavior(enemyFacts(), {
	operative("op:z", 0, 20),
	operative("op:a", 40, 0),
	operative("op:b", 45, 0),
	operative("op:c", 50, 0),
}, 10)
assert(
	dense.behaviorStateIdAfter == "Charging" and dense.anchorOperativeEntityId == "op:a",
	"the densest cluster anchors"
)
assert(dense.bloomTargetPosition.x == 40)

-- Equal-density clusters tie-break to the lexically smallest operative ID.
local tie = resolver.resolveBehavior(enemyFacts(), {
	operative("op:m", 40, 0),
	operative("op:n", 45, 0),
	operative("op:a", -40, 0),
	operative("op:b", -45, 0),
}, 10)
assert(tie.anchorOperativeEntityId == "op:a", "equal-density ties must break deterministically")

-- Cooldown gate: in range but reloading holds; exactly at the deadline re-arms.
local reloading = resolver.resolveBehavior(
	enemyFacts({ behaviorStateId = "Recovering", lastBloomCommitServerTimestamp = 10 }),
	{ operative("op:a", 40, 0) },
	10 + bloom.CooldownSeconds - 0.01
)
assert(reloading.behaviorStateIdAfter == "Recovering" and reloading.bloomActionId == "None")
local rearmed = resolver.resolveBehavior(
	enemyFacts({ behaviorStateId = "Recovering", lastBloomCommitServerTimestamp = 10 }),
	{ operative("op:a", 40, 0) },
	10 + bloom.CooldownSeconds
)
assert(rearmed.behaviorStateIdAfter == "Charging" and rearmed.bloomActionId == "Begin")

-- Charge lifecycle: continue before the windup elapses, commit at the deadline.
local charging = enemyFacts({
	behaviorStateId = "Charging",
	anchorOperativeEntityId = "op:a",
	bloomChargeTargetPosition = { x = 0, y = 0, z = 0 },
	bloomChargeStartedServerTimestamp = 10,
})
local continuing =
	resolver.resolveBehavior(charging, { operative("op:a", 2, 0) }, 10 + bloom.ChargeWindupSeconds - 0.01)
assert(continuing.behaviorStateIdAfter == "Charging" and continuing.bloomActionId == "Continue")
assert(not continuing.shouldCommitBloom and #continuing.bloomImpacts == 0)

local commit = resolver.resolveBehavior(charging, {
	operative("op:hit_a", 10, 0),
	operative("op:hit_b", 0, 15),
	operative("op:miss", bloom.ImpactRadiusStuds + 4, 0),
	operative("op:dead", 5, 0, false),
}, 10 + bloom.ChargeWindupSeconds)
assert(commit.behaviorStateIdAfter == "Recovering" and commit.bloomActionId == "Commit" and commit.shouldCommitBloom)
assert(#commit.bloomImpacts == 2, "only Alive operatives inside the radius are hit")
local hits = impactByTarget(commit.bloomImpacts)
assert(hits["op:hit_a"] ~= nil and hits["op:hit_b"] ~= nil and hits["op:miss"] == nil and hits["op:dead"] == nil)
assert(hits["op:hit_a"].damageAmount == bloom.ImpactDamage)
assert(hits["op:hit_a"].sourceEntityId == "enemy.spitter.alpha" and hits["op:hit_a"].targetEntityId == "op:hit_a")
assert(hits["op:hit_a"].damageEventId == "spitterbloom:enemy.spitter.alpha:op:hit_a:10")
assert(hits["op:hit_a"].serverTimestamp == 10 + bloom.ChargeWindupSeconds)

-- The commit emits the lingering-pool descriptor for the runtime to own.
local zone = commit.lingeringZone
assert(zone ~= nil, "a commit must emit a lingering zone")
assert(zone.zoneId == "spitterzone:enemy.spitter.alpha:10")
assert(zone.sourceEntityId == "enemy.spitter.alpha")
assert(zone.centerPosition.x == 0 and zone.centerPosition.z == 0)
assert(zone.radiusStuds == bloom.ImpactRadiusStuds and zone.tickDamage == lingering.TickDamage)
assert(zone.tickIntervalSeconds == lingering.TickIntervalSeconds and zone.lifetimeSeconds == lingering.LifetimeSeconds)
assert(zone.committedServerTimestamp == 10 + bloom.ChargeWindupSeconds and zone.lastTickServerTimestamp == nil)

-- A charge lands on empty ground when the squad escaped: committed, zero impacts.
local emptyCommit = resolver.resolveBehavior(charging, {}, 10 + bloom.ChargeWindupSeconds)
assert(emptyCommit.bloomActionId == "Commit" and #emptyCommit.bloomImpacts == 0 and emptyCommit.lingeringZone ~= nil)

-- Lingering pool ticks: not-due, due, and expired.
local function zoneFacts(overrides: { [string]: any }?)
	local z = {
		zoneId = "spitterzone:enemy.spitter.alpha:100",
		sourceEntityId = "enemy.spitter.alpha",
		centerPosition = { x = 0, y = 0, z = 0 },
		radiusStuds = bloom.ImpactRadiusStuds,
		tickDamage = lingering.TickDamage,
		tickIntervalSeconds = lingering.TickIntervalSeconds,
		lifetimeSeconds = lingering.LifetimeSeconds,
		committedServerTimestamp = 100,
		lastTickServerTimestamp = nil,
	}
	for key, value in overrides or {} do
		z[key] = value
	end
	return z
end

local notDue = resolver.resolveLingeringDamage(zoneFacts(), { operative("op:a", 1, 0) }, 100)
assert(notDue.isActive and not notDue.ticked and #notDue.impacts == 0)

local due = resolver.resolveLingeringDamage(zoneFacts(), {
	operative("op:in", 2, 0),
	operative("op:out", bloom.ImpactRadiusStuds + 3, 0),
	operative("op:dead", 1, 0, false),
}, 100 + lingering.TickIntervalSeconds)
assert(due.isActive and due.ticked and #due.impacts == 1)
assert(due.tickServerTimestamp == 100 + lingering.TickIntervalSeconds)
local tickHits = impactByTarget(due.impacts)
assert(tickHits["op:in"] ~= nil and tickHits["op:out"] == nil and tickHits["op:dead"] == nil)
assert(tickHits["op:in"].damageAmount == lingering.TickDamage)
assert(
	tickHits["op:in"].damageEventId
		== "spitterlinger:enemy.spitter.alpha:op:in:" .. tostring(100 + lingering.TickIntervalSeconds)
)

-- A second tick is not due until another interval passes from the last tick.
local afterFirstTick = resolver.resolveLingeringDamage(
	zoneFacts({ lastTickServerTimestamp = 101 }),
	{ operative("op:a", 1, 0) },
	101 + lingering.TickIntervalSeconds - 0.01
)
assert(afterFirstTick.isActive and not afterFirstTick.ticked)

local expired =
	resolver.resolveLingeringDamage(zoneFacts(), { operative("op:a", 1, 0) }, 100 + lingering.LifetimeSeconds)
assert(not expired.isActive and not expired.ticked and #expired.impacts == 0)

-- Lingering validation: malformed zone, stale timestamp, impossible tick history.
assert(resolver.resolveLingeringDamage(zoneFacts({ radiusStuds = 0 }), {}, 100).rejectionReasonId == "InvalidFacts")
assert(resolver.resolveLingeringDamage(zoneFacts(), {}, 99).rejectionReasonId == "InvalidTimestamp")
assert(
	resolver.resolveLingeringDamage(zoneFacts({ lastTickServerTimestamp = 99 }), {}, 101).rejectionReasonId
		== "InvalidFacts"
)

-- Determinism and immutability: identical frozen inputs give identical decisions.
local frozenEnemy = table.freeze(enemyFacts({ position = table.freeze({ x = 0, y = 3, z = 0 }) }))
local frozenOperatives = table.freeze({ table.freeze(operative("op:a", 40, 0)) })
local first = resolver.resolveBehavior(frozenEnemy, frozenOperatives, 25)
local second = resolver.resolveBehavior(frozenEnemy, frozenOperatives, 25)
assert(first.behaviorStateIdAfter == second.behaviorStateIdAfter and first.behaviorStateIdAfter == "Charging")
assert(first.bloomActionId == second.bloomActionId and first.bloomActionId == "Begin")
assert(first.anchorOperativeEntityId == "op:a" and second.anchorOperativeEntityId == "op:a")

print(
	"SpecialEnemyBehaviorResolver: P9-0101 targeting, charge lifecycle, commit burst, lingering ticks, and determinism passed"
)
