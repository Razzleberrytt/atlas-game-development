--!strict

-- P9-0103 pure boss phase decisions: fact/timestamp validation, slam-fact
-- consistency, monotonic health-driven phase transitions, post-Slam vulnerability
-- windows, the Slam lifecycle and commit AoE, the one-shot Brood summon, the
-- shroud / Collapse-darkness visibility overrides, defeat, and determinism.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P9-0103 boss phase fixture assertion failed", 2)
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
local bossContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/BossContracts.luau"), {
	debugName = "BossContracts",
	environment = {
		script = { Parent = { EnemyContracts = ENEMY_CONTRACTS_TOKEN } },
		require = function(token: unknown)
			assert(token == ENEMY_CONTRACTS_TOKEN, "unexpected BossContracts dependency")
			return enemyContracts
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
local BOSS_CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/BossConfig.luau"), {
	debugName = "BossConfig",
	environment = {
		script = {
			Parent = {
				EnemyConfig = ENEMY_CONFIG_TOKEN,
				Parent = { Combat = { BossContracts = BOSS_CONTRACTS_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONFIG_TOKEN then
				return enemyConfig
			end
			if token == BOSS_CONTRACTS_TOKEN then
				return bossContracts
			end
			error("unexpected BossConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Combat = { BossContracts = CONTRACTS_TOKEN },
		Config = { BossConfig = CONFIG_TOKEN },
	},
}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/BossPhaseResolver.luau"), {
	debugName = "BossPhaseResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return bossContracts
			end
			if token == CONFIG_TOKEN then
				return config
			end
			error("unexpected resolver dependency")
		end,
	},
	injectGlobals = true,
})()

local progenitor = config.Progenitor
local carapace = config.Phases.Carapace

local function bossFacts(overrides: { [string]: any }?)
	local facts = {
		entityId = "boss.progenitor.test",
		phaseId = "Carapace",
		position = { x = 0, y = 5, z = 0 },
		currentHealth = progenitor.MaximumHealth,
		maximumHealth = progenitor.MaximumHealth,
		lastSlamCommitServerTimestamp = nil,
		slamWindupStartedServerTimestamp = nil,
		slamTargetPosition = nil,
		broodSummonedForPhase = false,
		floodlightsRestored = false,
	}
	for key, value in overrides or {} do
		facts[key] = value
	end
	return facts
end

local function operative(id: string, x: number, z: number, lifeStateId: string?)
	return {
		operativeEntityId = id,
		isAlive = (lifeStateId or "Alive") == "Alive",
		position = { x = x, y = 0, z = z },
	}
end

local broodHealth = progenitor.MaximumHealth * 0.5 -- between collapse and brood fractions
local collapseHealth = progenitor.MaximumHealth * 0.2 -- at/under the collapse fraction

-- Fact and timestamp validation.
assert(resolver.resolveBossPhase(nil :: any, {}, 10).rejectionReasonId == "InvalidFacts")
assert(resolver.resolveBossPhase(bossFacts({ phaseId = "Rampage" }), {}, 10).rejectionReasonId == "InvalidFacts")
assert(
	resolver.resolveBossPhase(bossFacts({ position = { x = 0 / 0, y = 0, z = 0 } }), {}, 10).rejectionReasonId
		== "InvalidFacts"
)
assert(resolver.resolveBossPhase(bossFacts({ maximumHealth = 0 }), {}, 10).rejectionReasonId == "InvalidFacts")
assert(
	resolver.resolveBossPhase(bossFacts({ broodSummonedForPhase = "yes" }), {}, 10).rejectionReasonId == "InvalidFacts"
)
local badTime = resolver.resolveBossPhase(bossFacts({ phaseId = "Brood" }), {}, 0 / 0)
assert(badTime.rejectionReasonId == "InvalidTimestamp" and badTime.phaseIdAfter == "Brood")
assert(resolver.resolveBossPhase(bossFacts(), {}, -1).rejectionReasonId == "InvalidTimestamp")

-- A commit timestamp cannot be in the future.
assert(
	resolver.resolveBossPhase(bossFacts({ lastSlamCommitServerTimestamp = 100 }), {}, 10).rejectionReasonId
		== "InvalidFacts"
)

-- Slam-fact consistency: partial or future windup facts fail closed.
assert(
	resolver.resolveBossPhase(bossFacts({ slamTargetPosition = { x = 0, y = 0, z = 0 } }), {}, 10).rejectionReasonId
		== "InvalidFacts"
)
assert(
	resolver.resolveBossPhase(
		bossFacts({ slamTargetPosition = { x = 0, y = 0, z = 0 }, slamWindupStartedServerTimestamp = 20 }),
		{},
		10
	).rejectionReasonId == "InvalidFacts"
)

-- Monotonic phase transitions from health thresholds.
assert(resolver.resolveBossPhase(bossFacts(), {}, 10).phaseIdAfter == "Carapace", "full health is Carapace")
assert(resolver.resolveBossPhase(bossFacts({ currentHealth = broodHealth }), {}, 10).phaseIdAfter == "Brood")
assert(resolver.resolveBossPhase(bossFacts({ currentHealth = collapseHealth }), {}, 10).phaseIdAfter == "Collapse")
assert(resolver.resolveBossPhase(bossFacts({ currentHealth = 0 }), {}, 10).phaseIdAfter == "Defeated")
-- Never regress: a Collapse boss whose health somehow reads high stays Collapse.
assert(
	resolver.resolveBossPhase(bossFacts({ phaseId = "Collapse", currentHealth = progenitor.MaximumHealth }), {}, 10).phaseIdAfter
		== "Collapse",
	"phases are monotonic and never regress"
)

-- Defeat is inert and terminal, and cancels any pending Slam.
local defeated = resolver.resolveBossPhase(
	bossFacts({
		phaseId = "Collapse",
		currentHealth = 0,
		slamTargetPosition = { x = 0, y = 5, z = 0 },
		slamWindupStartedServerTimestamp = 5,
	}),
	{ operative("op:a", 1, 0) },
	6
)
assert(defeated.phaseIdAfter == "Defeated" and defeated.outcomeId == "Defeated")
assert(defeated.slamActionId == "Cancel" and not defeated.isVulnerable and #defeated.slamImpacts == 0)
assert(not defeated.shroudActive and defeated.visibilityOverrideRadiusStuds == nil)

-- Vulnerability: armored until a Slam commits, then open for the exposure window.
assert(not resolver.resolveBossPhase(bossFacts(), {}, 10).isVulnerable, "the boss is armored before any Slam")
assert(
	resolver.resolveBossPhase(
		bossFacts({ lastSlamCommitServerTimestamp = 10 }),
		{},
		10 + carapace.ExposureWindowSeconds - 0.01
	).isVulnerable,
	"the exposure window opens after a Slam"
)
assert(
	not resolver.resolveBossPhase(
		bossFacts({ lastSlamCommitServerTimestamp = 10 }),
		{},
		10 + carapace.ExposureWindowSeconds
	).isVulnerable,
	"the exposure window closes on its deadline"
)

-- Slam lifecycle: Begin locks the boss centre, Continue holds, Commit hits the AoE.
local begin = resolver.resolveBossPhase(bossFacts(), { operative("op:a", 5, 0) }, 10)
assert(begin.slamActionId == "Begin" and begin.slamTargetPosition ~= nil)
assert(begin.slamTargetPosition.x == 0 and begin.slamTargetPosition.z == 0, "the Slam is centred on the boss")

local windingFacts = bossFacts({
	slamTargetPosition = { x = 0, y = 5, z = 0 },
	slamWindupStartedServerTimestamp = 10,
})
assert(resolver.resolveBossPhase(windingFacts, {}, 10 + carapace.SlamWindupSeconds - 0.01).slamActionId == "Continue")
local slam = resolver.resolveBossPhase(windingFacts, {
	operative("op:in", config.Slam.RadiusStuds - 2, 0),
	operative("op:out", config.Slam.RadiusStuds + 4, 0),
	operative("op:down", 3, 0, "Incapacitated"),
}, 10 + carapace.SlamWindupSeconds)
assert(slam.slamActionId == "Commit" and #slam.slamImpacts == 1, "only Alive operatives inside the radius are hit")
assert(slam.slamImpacts[1].targetEntityId == "op:in" and slam.slamImpacts[1].damageAmount == config.Slam.Damage)
assert(slam.slamImpacts[1].damageEventId == "bossslam:boss.progenitor.test:op:in:10")
assert(slam.slamImpacts[1].serverTimestamp == 10 + carapace.SlamWindupSeconds)

-- Slam cooldown gate: no new Slam until the cadence elapses.
assert(
	resolver.resolveBossPhase(
		bossFacts({ lastSlamCommitServerTimestamp = 10 }),
		{},
		10 + carapace.SlamCooldownSeconds - 0.01
	).slamActionId == "None"
)
assert(
	resolver.resolveBossPhase(bossFacts({ lastSlamCommitServerTimestamp = 10 }), {}, 10 + carapace.SlamCooldownSeconds).slamActionId
		== "Begin"
)

-- The Brood surge fires exactly once on entering Brood.
local broodEntry = resolver.resolveBossPhase(bossFacts({ currentHealth = broodHealth }), {}, 10)
assert(broodEntry.shouldSummonBrood and broodEntry.broodSurgeCount == config.Brood.SurgeCount)
assert(broodEntry.shroudActive and broodEntry.visibilityOverrideRadiusStuds == config.Visibility.ShroudRadiusStuds)
local broodAgain =
	resolver.resolveBossPhase(bossFacts({ currentHealth = broodHealth, broodSummonedForPhase = true }), {}, 10)
assert(not broodAgain.shouldSummonBrood and broodAgain.broodSurgeCount == 0, "the surge never repeats within a phase")
assert(not resolver.resolveBossPhase(bossFacts(), {}, 10).shouldSummonBrood, "Carapace never summons")

-- Collapse readability depends on the P8 floodlight repair.
local darkCollapse =
	resolver.resolveBossPhase(bossFacts({ currentHealth = collapseHealth, floodlightsRestored = false }), {}, 10)
assert(
	not darkCollapse.shroudActive
		and darkCollapse.visibilityOverrideRadiusStuds == config.Visibility.CollapseDarkRadiusStuds,
	"un-repaired floodlights leave Collapse dark"
)
local litCollapse =
	resolver.resolveBossPhase(bossFacts({ currentHealth = collapseHealth, floodlightsRestored = true }), {}, 10)
assert(litCollapse.visibilityOverrideRadiusStuds == nil, "repaired floodlights light the Collapse arena")
assert(resolver.resolveBossPhase(bossFacts(), {}, 10).visibilityOverrideRadiusStuds == nil, "Carapace has no override")

-- Determinism and immutability.
local frozenBoss = table.freeze(bossFacts({ position = table.freeze({ x = 0, y = 5, z = 0 }) }))
local frozenOperatives = table.freeze({ table.freeze(operative("op:a", 5, 0)) })
local first = resolver.resolveBossPhase(frozenBoss, frozenOperatives, 25)
local second = resolver.resolveBossPhase(frozenBoss, frozenOperatives, 25)
assert(first.phaseIdAfter == second.phaseIdAfter and first.slamActionId == second.slamActionId)
assert(first.slamActionId == "Begin")

print("BossPhaseResolver: P9-0103 phase transitions, vulnerability windows, Slam AoE, Brood summon, and shroud passed")
