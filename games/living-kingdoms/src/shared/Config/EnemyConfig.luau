--!strict

--[[
	Shared balance home for the production enemy runtime. This integrates the
	validated Horde Pressure v1 time-to-contact and time-to-kill tuning with the
	higher-density horde vertical-slice population and evaluation budgets. Every
	consequential value remains server-owned and configuration-driven.
]]

local EnemyContracts = require(script.Parent.Parent.Combat.EnemyContracts)
local WorldFoundationConfig = require(script.Parent.WorldFoundationConfig)

local EnemyConfig = {
	Version = "HORDE-VS-001-v3",
	Walker = table.freeze({
		ArchetypeId = EnemyContracts.EnemyArchetypeIds.ExclusionWalker,
		DisplayName = "Hollow Infected",
		-- Preserve PR #99's faster time-to-kill so larger populations remain
		-- satisfying rather than becoming damage-sponge cleanup.
		MaximumHealth = 45,
		PursuitSpeedStudsPerSecond = 13,
		RoamSpeedStudsPerSecond = 7.5,
		DetectionRadiusStuds = 110,
		PursuitDropRadiusStuds = 145,
		AttackRangeStuds = 6,
		AttackDamage = 12,
		AttackWindupSeconds = 0.6,
		AttackCooldownSeconds = 1.45,
		RoamWanderRadiusStuds = 24,
		RoamRetargetIntervalSeconds = 4,
	}),
	FairSpawn = table.freeze({
		MinimumOperativeDistanceStuds = 64,
		DeferredRetryIntervalSeconds = 0.75,
		MaximumDeferredSpawns = 64,
	}),
	Population = table.freeze({
		-- This is the explicit vertical-slice profiling budget, not a production
		-- guarantee. Merge remains blocked on solo and two-client MicroProfiler
		-- evidence at representative pressure. Raise only from measured evidence.
		MaximumConcurrentPerOperative = 24,
		AbsoluteMaximumConcurrent = 96,
	}),
	Pressure = table.freeze({
		-- Retains PR #99's contact-in-seconds principle while increasing the
		-- population fill rate enough to support actual visible hordes.
		RoamingByEscalationLevel = table.freeze({
			[0] = table.freeze({ IntervalSeconds = 9, SpawnCount = 4 }),
			[1] = table.freeze({ IntervalSeconds = 7, SpawnCount = 6 }),
			[2] = table.freeze({ IntervalSeconds = 5, SpawnCount = 8 }),
			[3] = table.freeze({ IntervalSeconds = 3.5, SpawnCount = 10 }),
		}),
		MaximumEscalationLevel = 3,
		RecoveryWindowSeconds = 6,
		RoamingSpawnMinimumDistanceStuds = 68,
		RoamingSpawnMaximumDistanceStuds = 118,
	}),
	Cleanup = table.freeze({
		CorpseCleanupSeconds = 5,
	}),
	Combat = table.freeze({
		GameplayVisibilityRadiusStuds = 60,
		EvaluationIntervalSeconds = 0.08,
		MaximumLineOfSightRaycastsPerEvaluation = 8,
	}),
	EvaluationIntervalSeconds = 0.1,
}

assert(EnemyConfig.Walker.MaximumHealth > 0, "walker health must be positive")
assert(EnemyConfig.Walker.PursuitSpeedStudsPerSecond > 0, "pursuit speed must be positive")
assert(
	EnemyConfig.Walker.RoamSpeedStudsPerSecond > 0
		and EnemyConfig.Walker.RoamSpeedStudsPerSecond <= EnemyConfig.Walker.PursuitSpeedStudsPerSecond,
	"roam speed must be positive and no faster than pursuit"
)
assert(
	EnemyConfig.Walker.DetectionRadiusStuds > EnemyConfig.Walker.AttackRangeStuds,
	"detection must reach beyond melee range"
)
assert(
	EnemyConfig.Walker.PursuitDropRadiusStuds > EnemyConfig.Walker.DetectionRadiusStuds,
	"pursuit drop hysteresis must exceed detection"
)
assert(EnemyConfig.Walker.AttackDamage > 0, "attack damage must be positive")
assert(
	EnemyConfig.Walker.AttackWindupSeconds >= EnemyConfig.EvaluationIntervalSeconds
		and EnemyConfig.Walker.AttackWindupSeconds < EnemyConfig.Walker.AttackCooldownSeconds,
	"attack windup must be visible, bounded, and shorter than the cooldown"
)
assert(EnemyConfig.Walker.AttackCooldownSeconds > 0, "attack cooldown must be positive")
assert(
	EnemyConfig.FairSpawn.MinimumOperativeDistanceStuds > EnemyConfig.Combat.GameplayVisibilityRadiusStuds,
	"fair spawns must land outside the darkness engagement radius"
)
assert(
	EnemyConfig.FairSpawn.MinimumOperativeDistanceStuds > EnemyConfig.Walker.AttackRangeStuds,
	"fair spawns must never begin inside melee range"
)
assert(EnemyConfig.FairSpawn.MaximumDeferredSpawns > 0, "the deferred spawn queue must be bounded and positive")
assert(
	EnemyConfig.Population.MaximumConcurrentPerOperative > 0
		and EnemyConfig.Population.AbsoluteMaximumConcurrent
			>= EnemyConfig.Population.MaximumConcurrentPerOperative * 4,
	"population caps must cover the four-operative squad"
)
for level = 0, EnemyConfig.Pressure.MaximumEscalationLevel do
	local cadence = EnemyConfig.Pressure.RoamingByEscalationLevel[level]
	assert(cadence ~= nil, "every escalation level requires an authored roaming cadence")
	assert(cadence.IntervalSeconds > 0 and cadence.IntervalSeconds < math.huge, "roaming interval must be bounded")
	assert(cadence.SpawnCount > 0, "roaming spawn count must be positive")
end
assert(EnemyConfig.Pressure.RecoveryWindowSeconds > 0, "recovery windows must be a bounded positive duration")
assert(
	EnemyConfig.Pressure.RoamingSpawnMinimumDistanceStuds >= EnemyConfig.FairSpawn.MinimumOperativeDistanceStuds,
	"roaming spawns must honor the fair-spawn distance"
)
assert(
	EnemyConfig.Pressure.RoamingSpawnMaximumDistanceStuds > EnemyConfig.Pressure.RoamingSpawnMinimumDistanceStuds,
	"the roaming spawn ring must have positive width"
)
assert(
	EnemyConfig.Pressure.RoamingSpawnMaximumDistanceStuds < WorldFoundationConfig.PlayableHalfExtentStuds,
	"roaming spawns must stay inside the authored world"
)
assert(EnemyConfig.Cleanup.CorpseCleanupSeconds > 0, "corpse cleanup must be a bounded positive duration")
assert(EnemyConfig.Combat.GameplayVisibilityRadiusStuds > 0, "the darkness engagement radius must be positive")
assert(
	EnemyConfig.Combat.EvaluationIntervalSeconds > 0 and EnemyConfig.Combat.EvaluationIntervalSeconds <= 1,
	"combat evaluation must stay bounded and responsive"
)
assert(
	EnemyConfig.Combat.MaximumLineOfSightRaycastsPerEvaluation > 0
		and EnemyConfig.Combat.MaximumLineOfSightRaycastsPerEvaluation <= 8,
	"the line-of-sight raycast budget must remain bounded"
)
assert(
	EnemyConfig.EvaluationIntervalSeconds > 0 and EnemyConfig.EvaluationIntervalSeconds <= 1,
	"enemy evaluation must stay bounded and responsive"
)

return table.freeze(EnemyConfig)
