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
	Version = "MVP-0.1-v8-fair-stuck-recovery",
	Walker = table.freeze({
		ArchetypeId = EnemyContracts.EnemyArchetypeIds.ExclusionWalker,
		DisplayName = "Exclusion Stalker",
		MaximumHealth = 68,
		PursuitSpeedStudsPerSecond = 16.5,
		RoamSpeedStudsPerSecond = 5.5,
		DetectionRadiusStuds = 135,
		PursuitDropRadiusStuds = 170,
		AttackRangeStuds = 7,
		AttackDamage = 20,
		AttackWindupSeconds = 0.7,
		AttackCooldownSeconds = 2.1,
		RoamWanderRadiusStuds = 12,
		RoamRetargetIntervalSeconds = 6,
	}),
	Navigation = table.freeze({
		PursuitRepathIntervalSeconds = 0.45,
		MaximumPathComputationsPerEvaluation = 4,
		AgentRadiusStuds = 2.5,
		AgentHeightStuds = 4,
		AgentCanJump = false,
		WaypointSpacingStuds = 5,
		PackFlankOffsetStuds = 4.5,
		FlankActivationDistanceStuds = 38,
		StuckMinimumProgressStuds = 1.5,
		StuckProgressWindowSeconds = 1.25,
		StuckRecoveryCooldownSeconds = 1.5,
	}),
	FairSpawn = table.freeze({
		MinimumOperativeDistanceStuds = 64,
		DeferredRetryIntervalSeconds = 0.75,
		MaximumDeferredSpawns = 20,
	}),
	Population = table.freeze({
		MaximumConcurrentPerOperative = 6,
		AbsoluteMaximumConcurrent = 24,
	}),
	Pressure = table.freeze({
		RoamingByEscalationLevel = table.freeze({
			[0] = table.freeze({ IntervalSeconds = 24, SpawnCount = 1 }),
			[1] = table.freeze({ IntervalSeconds = 15, SpawnCount = 2 }),
			[2] = table.freeze({ IntervalSeconds = 12, SpawnCount = 2 }),
			[3] = table.freeze({ IntervalSeconds = 10, SpawnCount = 3 }),
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
	EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation > 0
		and EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation % 1 == 0
		and EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation <= 8,
	"pathfinding work per enemy evaluation must remain a small positive integer budget"
)
assert(type(EnemyConfig.Navigation.AgentCanJump) == "boolean", "pathfinding jump capability must be explicit")
assert(
	not EnemyConfig.Navigation.AgentCanJump,
	"walker Humanoids currently have zero JumpPower, so navigation must not request jump waypoints"
)
assert(
	EnemyConfig.Navigation.StuckMinimumProgressStuds > 0
		and EnemyConfig.Navigation.StuckMinimumProgressStuds < EnemyConfig.Walker.AttackRangeStuds,
	"stuck progress threshold must be positive and smaller than melee range"
)
assert(
	EnemyConfig.Navigation.StuckProgressWindowSeconds > EnemyConfig.Navigation.PursuitRepathIntervalSeconds,
	"stuck detection must observe multiple ordinary repath intervals"
)
assert(
	EnemyConfig.Navigation.StuckRecoveryCooldownSeconds >= EnemyConfig.Navigation.StuckProgressWindowSeconds,
	"stuck recovery cooldown must prevent repeated repath thrash"
)
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
	EnemyConfig.Pressure.RoamingSpawnMaximumDistanceStuds >= EnemyConfig.Pressure.RoamingSpawnMinimumDistanceStuds,
	"roaming spawn ring must be ordered"
)
assert(EnemyConfig.Cleanup.CorpseCleanupSeconds > 0, "corpse cleanup must be bounded")
assert(EnemyConfig.Combat.GameplayVisibilityRadiusStuds > 0, "combat visibility radius must be positive")
assert(
	EnemyConfig.Combat.EvaluationIntervalSeconds >= 0.05,
	"combat evaluation cadence must stay bounded away from per-frame polling"
)
assert(
	EnemyConfig.Combat.MaximumLineOfSightRaycastsPerEvaluation > 0,
	"combat line-of-sight raycast budget must be positive"
)
assert(
	EnemyConfig.EvaluationIntervalSeconds >= 0.05,
	"enemy evaluation cadence must stay bounded away from per-frame polling"
)

return table.freeze(EnemyConfig)
