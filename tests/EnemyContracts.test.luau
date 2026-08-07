--!strict

-- Horde vertical-slice enemy vocabulary and configuration invariants: stable
-- IDs, bounded balance values, fair-spawn distances, representative population
-- budgets, roaming cadence coverage, and frozen shared tables.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "horde enemy contracts fixture assertion failed", 2)
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
local configLoader = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau"), {
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
})
local config = configLoader()

-- Stable vocabulary: renames break saved IDs and cross-system contracts.
assert(contracts.EnemyArchetypeIds.ExclusionWalker == "enemy.exclusion_walker")
assert(
	contracts.EnemyArchetypeIds.BlightSpitter == "enemy.blight_spitter",
	"the special-enemy archetype joins the registry"
)
assert(contracts.EnemyArchetypeIds.Progenitor == "boss.progenitor", "the boss archetype joins the registry")
assert(contracts.EnemyBehaviorStateIds.Roaming == "Roaming")
assert(contracts.EnemyBehaviorStateIds.Pursuing == "Pursuing")
assert(contracts.EnemyBehaviorStateIds.Attacking == "Attacking")
assert(contracts.EnemyBehaviorStateIds.StandDown == "StandDown")
assert(contracts.EnemyBehaviorStateIds.Dead == "Dead")
assert(contracts.EnemySpawnSourceIds.AuthoredWave == "AuthoredWave")
assert(contracts.EnemySpawnSourceIds.RoamingPressure == "RoamingPressure")
for _, reason in
	{ "InvalidDefinition", "DuplicateEntityId", "PopulationCapReached", "OutsidePlayableExtent", "TooCloseToOperative" }
do
	assert(contracts.EnemySpawnRejectionReasonIds[reason] == reason, "missing spawn rejection: " .. reason)
end
for _, reason in { "InvalidFacts", "InvalidTimestamp" } do
	assert(contracts.EnemyBehaviorRejectionReasonIds[reason] == reason, "missing behavior rejection: " .. reason)
end
assert(table.isfrozen(contracts), "contracts must be frozen")
assert(table.isfrozen(contracts.EnemyBehaviorStateIds), "state IDs must be frozen")

-- Configuration invariants beyond the module's own asserts.
assert(config.Walker.ArchetypeId == contracts.EnemyArchetypeIds.ExclusionWalker)
assert(table.isfrozen(config) and table.isfrozen(config.Walker), "config must be frozen")
assert(config.Walker.MaximumHealth > 0 and config.Walker.MaximumHealth < math.huge)
assert(config.Walker.AttackDamage < 100, "one walker swing must never down a full-health operative outright")
assert(
	config.Walker.DetectionRadiusStuds
		< config.FairSpawn.MinimumOperativeDistanceStuds + config.Pressure.RoamingSpawnMaximumDistanceStuds,
	"detection must stay in the same order of magnitude as the spawn ring"
)
assert(
	config.FairSpawn.MinimumOperativeDistanceStuds > config.Combat.GameplayVisibilityRadiusStuds,
	"fair spawns must land outside the darkness engagement radius"
)
assert(config.Combat.GameplayVisibilityRadiusStuds < 80, "darkness, not weapon range, must bound engagement")
assert(
	config.Population.AbsoluteMaximumConcurrent >= config.Population.MaximumConcurrentPerOperative * 4,
	"the absolute cap must cover a four-operative squad"
)

-- Representative vertical-slice population budget: 1/2/4 operatives.
local function capFor(operativeCount: number): number
	return math.min(
		config.Population.AbsoluteMaximumConcurrent,
		config.Population.MaximumConcurrentPerOperative * math.max(1, operativeCount)
	)
end
assert(capFor(1) == 10 and capFor(2) == 20 and capFor(4) == 40, "representative 1/2/4 predator caps changed")

-- Roaming cadence covers every escalation level, tightens monotonically, and
-- remains bounded by the authored ten-enemy burst maximum.
local previousInterval = math.huge
for level = 0, config.Pressure.MaximumEscalationLevel do
	local cadence = config.Pressure.RoamingByEscalationLevel[level]
	assert(cadence ~= nil, "missing roaming cadence for level " .. level)
	assert(cadence.IntervalSeconds <= previousInterval, "escalation must not relax roaming pressure")
	assert(cadence.SpawnCount >= 1 and cadence.SpawnCount <= 10, "roaming bursts must remain bounded")
	previousInterval = cadence.IntervalSeconds
end
assert(
	config.Pressure.RecoveryWindowSeconds < config.Pressure.RoamingByEscalationLevel[0].IntervalSeconds,
	"recovery windows must stay shorter than the calmest roaming interval"
)

-- The spawn ring stays inside the authored world from any standing position.
assert(config.Pressure.RoamingSpawnMaximumDistanceStuds < worldConfig.PlayableHalfExtentStuds)

print("EnemyContracts: horde vocabulary, balance invariants, population caps, and cadence coverage passed")
