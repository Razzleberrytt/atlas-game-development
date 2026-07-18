--!strict

--[[
	P5-0104 shared balance home for the production enemy runtime. Prototype
	values, not a balance promise. Every consequential enemy number lives here
	rather than inside runtime logic; the server remains the only authority
	over facts derived from these values.
]]

local EnemyContracts = require(script.Parent.Parent.Combat.EnemyContracts)
local WorldFoundationConfig = require(script.Parent.WorldFoundationConfig)

local EnemyConfig = {
	Version = "P5-0104-v3-horde-pressure",
	Walker = table.freeze({
		ArchetypeId = EnemyContracts.EnemyArchetypeIds.ExclusionWalker,
		DisplayName = "Exclusion Walker",
		-- Faster time-to-kill keeps a larger enemy population satisfying rather
		-- than turning every contact into a slow damage-sponge cleanup exercise.
		MaximumHealth = 45,
		PursuitSpeedStudsPerSecond = 13,
		RoamSpeedStudsPerSecond = 7.5,
		-- The pressure ring now lands inside detection range, so fair off-screen
		-- spawns become active threats instead of wandering harmlessly nearby.
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
		-- Larger than the darkness engagement radius so spawns never pop into
		-- an operative's validated sight or melee reach.
		MinimumOperativeDistanceStuds = 64,
		DeferredRetryIntervalSeconds = 2,
		MaximumDeferredSpawns = 16,
	}),
	Population = table.freeze({
		-- Keep the already validated population budget. This pass raises pressure
		-- by filling it quickly and consistently rather than increasing the worst-
		-- case server load before representative Studio profiling.
		MaximumConcurrentPerOperative = 6,
		AbsoluteMaximumConcurrent = 24,
	}),
	Pressure = table.freeze({
		-- Horde Pressure v1: contact begins in seconds, not minutes. Escalation
		-- tightens cadence and raises the final burst while every proposal still
		-- passes the existing population cap and fair-spawn validation.
		RoamingByEscalationLevel = table.freeze({
			[0] = table.freeze({ IntervalSeconds = 12, SpawnCount = 2 }),
			[1] = table.freeze({ IntervalSeconds = 10, SpawnCount = 2 }),
			[2] = table.freeze({ IntervalSeconds = 8, SpawnCount = 2 }),
			[3] = table.freeze({ IntervalSeconds = 6, SpawnCount = 3 }),
		}),
		MaximumEscalationLevel = 3,
		-- Preserve readable breathers without draining the world of urgency.
		RecoveryWindowSeconds = 8,
		RoamingSpawnMinimumDistanceStuds = 68,
		RoamingSpawnMaximumDistanceStuds = 96,
	}),
	Cleanup = table.freeze({
		CorpseCleanupSeconds = 8,
	}),
	Combat = table.freeze({
		-- Darkness-bounded gameplay visibility for automatic targeting. This
		-- prototype provider marks a hostile visible only inside this
		-- horizontal radius; it is deliberately shorter than the 80-stud
		-- firearm range so darkness, not range, is the engagement limit.
		GameplayVisibilityRadiusStuds = 60,
		EvaluationIntervalSeconds = 0.1,
		-- Bounded per-operative line-of-sight budget for one evaluation pass.
		MaximumLineOfSightRaycastsPerEvaluation = 3,
	}),
	EvaluationIntervalSeconds = 0.2,
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
	"the line-of-sight raycast budget must be small and positive"
)
assert(
	EnemyConfig.EvaluationIntervalSeconds > 0 and EnemyConfig.EvaluationIntervalSeconds <= 1,
	"enemy evaluation must stay bounded and responsive"
)

return table.freeze(EnemyConfig)
