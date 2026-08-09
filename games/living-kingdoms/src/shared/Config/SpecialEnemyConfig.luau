--!strict

--[[
	P9-0101 shared balance home for the Blight Spitter special enemy. Every
	consequential value is server-owned and configuration-driven, mirroring
	EnemyConfig. These are prototype authoring-intent values, not promises: the
	P12 balance pass confirms them against evidence.

	The Spitter reuses the production enemy owner for identity, fair spawning,
	health, corpse cleanup, and stand-down (P9-0102 integration). The values here
	add only the ranged Corrosive Bloom area-denial ability and the authored
	rarity that keeps it a special rather than a crowd.
]]

local EnemyConfig = require(script.Parent.EnemyConfig)
local SpecialEnemyContracts = require(script.Parent.Parent.Combat.SpecialEnemyContracts)

local SpecialEnemyConfig = {
	Version = "P9-0101-v1",
	BlightSpitter = table.freeze({
		ArchetypeId = SpecialEnemyContracts.SpecialEnemyArchetypeIds.BlightSpitter,
		DisplayName = "Blight Spitter",
		-- Tougher than a walker (45) so it reads as a priority target worth
		-- interrupting, but not a damage sponge.
		MaximumHealth = 120,
		-- Ranged and deliberate: slower than a walker's 13-stud pursuit because it
		-- keeps its distance and lobs rather than closing to melee.
		PursuitSpeedStudsPerSecond = 9,
		RoamSpeedStudsPerSecond = 6,
		DetectionRadiusStuds = 110,
		-- The densest cluster must be within this range for the Spitter to begin a
		-- bloom; beyond it, the Spitter approaches. Must sit inside detection and
		-- outside the fair-spawn floor so an approaching Spitter can act.
		BloomEngagementRangeStuds = 72,
	}),
	Bloom = table.freeze({
		-- The whole counterplay budget: spread out, step off, or kill the Spitter
		-- before the landing position commits.
		ChargeWindupSeconds = 1.4,
		ImpactRadiusStuds = 16,
		ImpactDamage = 14,
		-- An operative counts toward a cluster (and is a candidate landing anchor)
		-- when this many studs from another; kept equal to the impact radius so the
		-- densest-cluster anchor reflects exactly who the bloom would catch.
		ClusterRadiusStuds = 16,
		-- Keeps the Spitter a pressure source, not a stunlock.
		CooldownSeconds = 6,
		-- The short-lived pool that actually denies the held ground and forces the
		-- reposition. Ticks ride the existing enemy evaluation pass; the runtime
		-- bounds the number of concurrent pools.
		Lingering = table.freeze({
			LifetimeSeconds = 3,
			TickDamage = 5,
			TickIntervalSeconds = 1,
		}),
		MaximumActiveZones = 4,
	}),
	Spawn = table.freeze({
		-- Authored rarity, not a random crowd. The runtime introduces the Spitter
		-- once escalation reaches the booster hold and holds a low concurrent count.
		IntroductionEscalationLevel = 1,
		MaximumConcurrent = 2,
	}),
}

local spitter = SpecialEnemyConfig.BlightSpitter
local bloom = SpecialEnemyConfig.Bloom
local lingering = bloom.Lingering
local spawn = SpecialEnemyConfig.Spawn

assert(spitter.MaximumHealth > 0, "spitter health must be positive")
assert(spitter.PursuitSpeedStudsPerSecond > 0, "spitter pursuit speed must be positive")
assert(
	spitter.RoamSpeedStudsPerSecond > 0 and spitter.RoamSpeedStudsPerSecond <= spitter.PursuitSpeedStudsPerSecond,
	"spitter roam speed must be positive and no faster than pursuit"
)
assert(
	spitter.BloomEngagementRangeStuds > 0 and spitter.BloomEngagementRangeStuds <= spitter.DetectionRadiusStuds,
	"the bloom engagement range must be positive and within detection"
)
assert(
	spitter.BloomEngagementRangeStuds > EnemyConfig.FairSpawn.MinimumOperativeDistanceStuds,
	"an approaching Spitter must be able to reach bloom range after a fair spawn"
)
assert(bloom.ImpactRadiusStuds > 0, "the bloom impact radius must be positive")
assert(bloom.ImpactDamage > 0, "the bloom impact damage must be positive")
assert(
	bloom.ClusterRadiusStuds > 0 and bloom.ClusterRadiusStuds <= bloom.ImpactRadiusStuds,
	"the cluster radius must be positive and no larger than the impact radius"
)
assert(
	bloom.ChargeWindupSeconds >= EnemyConfig.EvaluationIntervalSeconds,
	"the bloom windup must be visible on the enemy evaluation pass"
)
assert(bloom.CooldownSeconds > 0, "the bloom cooldown must be positive")
assert(bloom.ChargeWindupSeconds < bloom.CooldownSeconds, "the bloom windup must be shorter than its cooldown")
assert(lingering.LifetimeSeconds > 0, "the lingering pool lifetime must be positive")
assert(lingering.TickDamage > 0, "the lingering tick damage must be positive")
assert(
	lingering.TickIntervalSeconds > 0 and lingering.TickIntervalSeconds <= lingering.LifetimeSeconds,
	"the lingering tick interval must be positive and no longer than the pool lifetime"
)
assert(
	lingering.TickIntervalSeconds >= EnemyConfig.EvaluationIntervalSeconds,
	"lingering ticks must be observable on the enemy evaluation pass"
)
assert(bloom.MaximumActiveZones > 0, "the active-zone pool must be bounded and positive")
assert(
	spawn.IntroductionEscalationLevel >= 0
		and spawn.IntroductionEscalationLevel <= EnemyConfig.Pressure.MaximumEscalationLevel,
	"the introduction escalation level must be a valid authored level"
)
assert(spawn.MaximumConcurrent > 0, "the concurrent Spitter count must be positive")
assert(
	spawn.MaximumConcurrent <= EnemyConfig.Population.MaximumConcurrentPerOperative,
	"concurrent Spitters must stay within the existing population budget"
)

return table.freeze(SpecialEnemyConfig)
