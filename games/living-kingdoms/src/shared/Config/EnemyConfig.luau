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
	Version = "P5-0104-v2",
	Walker = table.freeze({
		ArchetypeId = EnemyContracts.EnemyArchetypeIds.ExclusionWalker,
		DisplayName = "Exclusion Walker",
		MaximumHealth = 60,
		PursuitSpeedStudsPerSecond = 11,
		RoamSpeedStudsPerSecond = 6,
		DetectionRadiusStuds = 70,
		PursuitDropRadiusStuds = 95,
		AttackRangeStuds = 6,
		AttackDamage = 12,
		AttackWindupSeconds = 0.6,
		AttackCooldownSeconds = 1.6,
		RoamWanderRadiusStuds = 24,
		RoamRetargetIntervalSeconds = 6,
	}),
	FairSpawn = table.freeze({
		-- Larger than the darkness engagement radius so spawns never pop into
		-- an operative's validated sight or melee reach.
		MinimumOperativeDistanceStuds = 64,
		DeferredRetryIntervalSeconds = 2,
		MaximumDeferredSpawns = 16,
	}),
	Population = table.freeze({
		MaximumConcurrentPerOperative = 6,
		AbsoluteMaximumConcurrent = 24,
	}),
	Pressure = table.freeze({
		-- Roaming cadence per mission escalation level. Level 0 is the light
		-- infiltration baseline; authored waves raise the level monotonically.
		RoamingByEscalationLevel = table.freeze({
			[0] = table.freeze({ IntervalSeconds = 60, SpawnCount = 1 }),
			[1] = table.freeze({ IntervalSeconds = 45, SpawnCount = 1 }),
			[2] = table.freeze({ IntervalSeconds = 35, SpawnCount = 2 }),
			[3] = table.freeze({ IntervalSeconds = 25, SpawnCount = 2 }),
		}),
		MaximumEscalationLevel = 3,
		-- Short recovery window after each authored wave: roaming pressure
		-- pauses so squads get a readable breather between spikes.
		RecoveryWindowSeconds = 20,
		RoamingSpawnMinimumDistanceStuds = 70,
		RoamingSpawnMaximumDistanceStuds = 120,
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
