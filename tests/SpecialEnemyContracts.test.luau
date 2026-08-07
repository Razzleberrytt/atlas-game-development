--!strict

-- P9-0101 special-enemy vocabulary and configuration invariants: stable IDs,
-- bounded Blight Spitter balance values, the Corrosive Bloom ability bounds,
-- authored rarity within the existing population budget, and frozen tables.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P9-0101 special-enemy contracts fixture assertion failed", 2)
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

-- Stable vocabulary: renames break saved IDs and cross-system contracts.
assert(specialContracts.SpecialEnemyArchetypeIds.BlightSpitter == "enemy.blight_spitter")
for _, state in { "Roaming", "Approaching", "Charging", "Recovering", "StandDown", "Dead" } do
	assert(specialContracts.SpecialEnemyBehaviorStateIds[state] == state, "missing behavior state: " .. state)
end
for _, action in { "None", "Begin", "Continue", "Cancel", "Commit" } do
	assert(specialContracts.SpecialAbilityActionIds[action] == action, "missing ability action: " .. action)
end
for _, reason in { "InvalidFacts", "InvalidTimestamp" } do
	assert(specialContracts.SpecialEnemyBehaviorRejectionReasonIds[reason] == reason, "missing rejection: " .. reason)
end
assert(table.isfrozen(specialContracts), "contracts must be frozen")
assert(table.isfrozen(specialContracts.SpecialEnemyBehaviorStateIds), "state IDs must be frozen")
assert(table.isfrozen(specialContracts.SpecialAbilityActionIds), "ability action IDs must be frozen")

-- Configuration invariants beyond the module's own asserts.
local spitter = config.BlightSpitter
local bloom = config.Bloom
local lingering = bloom.Lingering
local spawn = config.Spawn
assert(spitter.ArchetypeId == specialContracts.SpecialEnemyArchetypeIds.BlightSpitter)
assert(table.isfrozen(config) and table.isfrozen(spitter) and table.isfrozen(bloom), "config must be frozen")
assert(table.isfrozen(lingering) and table.isfrozen(spawn), "config subtables must be frozen")

-- The Spitter is a distinct, tougher, slower ranged threat than the walker.
assert(spitter.MaximumHealth > enemyConfig.Walker.MaximumHealth, "the Spitter must read as a priority target")
assert(spitter.PursuitSpeedStudsPerSecond < enemyConfig.Walker.PursuitSpeedStudsPerSecond, "the Spitter keeps distance")

-- The bloom must be survivable and interruptible, never an instant down.
assert(bloom.ImpactDamage < 100, "one bloom must never down a full-health operative outright")
assert(bloom.ChargeWindupSeconds > 0 and bloom.ChargeWindupSeconds < bloom.CooldownSeconds)
assert(
	bloom.ChargeWindupSeconds >= enemyConfig.EvaluationIntervalSeconds,
	"the windup must be visible on the eval pass"
)
assert(bloom.ClusterRadiusStuds <= bloom.ImpactRadiusStuds, "cluster anchors must reflect who the bloom catches")

-- Lingering denial is short and bounded, not a permanent kill zone.
assert(lingering.LifetimeSeconds <= bloom.CooldownSeconds, "a pool must fade before the next bloom lands")
assert(lingering.TickDamage < bloom.ImpactDamage, "each tick is chip pressure, not the burst")
assert(lingering.TickIntervalSeconds <= lingering.LifetimeSeconds)
local maxTicks = math.floor(lingering.LifetimeSeconds / lingering.TickIntervalSeconds)
assert(
	bloom.ImpactDamage + maxTicks * lingering.TickDamage < 100,
	"standing in a full bloom plus its pool must not guarantee an instant down"
)

-- Authored rarity: the Spitter can act after a fair spawn and stays a special.
assert(
	spitter.BloomEngagementRangeStuds > enemyConfig.FairSpawn.MinimumOperativeDistanceStuds,
	"an approaching Spitter must reach bloom range after a fair spawn"
)
assert(spitter.BloomEngagementRangeStuds <= spitter.DetectionRadiusStuds)
assert(spawn.MaximumConcurrent >= 1 and spawn.MaximumConcurrent <= enemyConfig.Population.MaximumConcurrentPerOperative)
assert(
	spawn.IntroductionEscalationLevel >= 0
		and spawn.IntroductionEscalationLevel <= enemyConfig.Pressure.MaximumEscalationLevel
)
assert(bloom.MaximumActiveZones > 0 and bloom.MaximumActiveZones < math.huge)

print("SpecialEnemyContracts: P9-0101 Blight Spitter vocabulary, bloom bounds, and rarity invariants passed")
