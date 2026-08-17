--!strict

--[[
	Shared balance home for the production enemy runtime. Wave 2 keeps the legacy
	Walker table byte-for-value compatible while adding a compact ordinary-
	archetype catalog consumed by the shared pure behavior resolver.
]]

local EnemyContracts = require(script.Parent.Parent.Combat.EnemyContracts)
local WorldFoundationConfig = require(script.Parent.WorldFoundationConfig)

local MovementIds = EnemyContracts.EnemyMovementBehaviorIds
local AttackIds = EnemyContracts.EnemyAttackBehaviorIds
local ArchetypeIds = EnemyContracts.EnemyArchetypeIds

local Walker = table.freeze({
	ArchetypeId = ArchetypeIds.ExclusionWalker,
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
	MovementBehaviorId = MovementIds.DirectPursuit,
	AttackBehaviorId = AttackIds.Melee,
	WeakPointPartName = "Head",
	WeakPointDamageMultiplier = 1.5,
	FactionId = "faction.exclusion",
	EliteEligible = true,
	SpawnCost = 1,
	EncounterWeight = 6,
	BaseFieldXp = 10,
	LootProfileId = "enemy.standard",
	Tags = table.freeze({ "Common", "Melee", "Rusher" }),
})

local RazorRunner = table.freeze({
	ArchetypeId = ArchetypeIds.RazorRunner,
	DisplayName = "Razor Runner",
	MaximumHealth = 48,
	PursuitSpeedStudsPerSecond = 21,
	RoamSpeedStudsPerSecond = 8,
	DetectionRadiusStuds = 145,
	PursuitDropRadiusStuds = 185,
	AttackRangeStuds = 6,
	AttackDamage = 13,
	AttackWindupSeconds = 0.45,
	AttackCooldownSeconds = 1.45,
	RoamWanderRadiusStuds = 18,
	RoamRetargetIntervalSeconds = 2.8,
	MovementBehaviorId = MovementIds.Skirmish,
	AttackBehaviorId = AttackIds.Melee,
	WeakPointPartName = "Head",
	WeakPointDamageMultiplier = 1.6,
	FactionId = "faction.exclusion",
	EliteEligible = true,
	SpawnCost = 1,
	EncounterWeight = 3,
	BaseFieldXp = 12,
	LootProfileId = "enemy.standard",
	Tags = table.freeze({ "Common", "Melee", "Skirmisher", "Fast" }),
})

local GriefBrute = table.freeze({
	ArchetypeId = ArchetypeIds.GriefBrute,
	DisplayName = "Grief Brute",
	MaximumHealth = 150,
	PursuitSpeedStudsPerSecond = 10.5,
	RoamSpeedStudsPerSecond = 4,
	DetectionRadiusStuds = 120,
	PursuitDropRadiusStuds = 155,
	AttackRangeStuds = 8.5,
	AttackDamage = 34,
	AttackWindupSeconds = 1.05,
	AttackCooldownSeconds = 2.8,
	RoamWanderRadiusStuds = 8,
	RoamRetargetIntervalSeconds = 5.5,
	MovementBehaviorId = MovementIds.HeavyPressure,
	AttackBehaviorId = AttackIds.Melee,
	WeakPointPartName = "Head",
	WeakPointDamageMultiplier = 1.35,
	FactionId = "faction.exclusion",
	EliteEligible = true,
	SpawnCost = 3,
	EncounterWeight = 2,
	BaseFieldXp = 28,
	LootProfileId = "enemy.heavy",
	Tags = table.freeze({ "Heavy", "Melee", "Bruiser" }),
})

local OrdinaryArchetypesById = table.freeze({
	[ArchetypeIds.ExclusionWalker] = Walker,
	[ArchetypeIds.RazorRunner] = RazorRunner,
	[ArchetypeIds.GriefBrute] = GriefBrute,
})

local EnemyConfig = {
	Version = "MVP-0.1-v7-wave2-archetypes",
	Walker = Walker,
	RazorRunner = RazorRunner,
	GriefBrute = GriefBrute,
	OrdinaryArchetypesById = OrdinaryArchetypesById,
	Navigation = table.freeze({
		PursuitRepathIntervalSeconds = 0.45,
		AgentRadiusStuds = 2.5,
		AgentHeightStuds = 4,
		WaypointSpacingStuds = 5,
		MaximumPathComputationsPerEvaluation = 4,
		PackFlankOffsetStuds = 4.5,
		FlankActivationDistanceStuds = 38,
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
	Cleanup = table.freeze({ CorpseCleanupSeconds = 5 }),
	Combat = table.freeze({
		GameplayVisibilityRadiusStuds = 60,
		EvaluationIntervalSeconds = 0.08,
		MaximumLineOfSightRaycastsPerEvaluation = 8,
	}),
	EvaluationIntervalSeconds = 0.1,
}

function EnemyConfig.getOrdinaryArchetype(archetypeId: unknown)
	if type(archetypeId) ~= "string" then
		return nil
	end
	return OrdinaryArchetypesById[archetypeId]
end

local function validateOrdinary(definition)
	assert(definition.MaximumHealth > 0, "enemy health must be positive")
	assert(definition.PursuitSpeedStudsPerSecond > 0, "pursuit speed must be positive")
	assert(
		definition.RoamSpeedStudsPerSecond > 0
			and definition.RoamSpeedStudsPerSecond <= definition.PursuitSpeedStudsPerSecond,
		"roam speed must be positive and no faster than pursuit"
	)
	assert(definition.DetectionRadiusStuds > definition.AttackRangeStuds, "detection must reach beyond attack range")
	assert(definition.PursuitDropRadiusStuds > definition.DetectionRadiusStuds, "pursuit drop must exceed detection")
	assert(definition.AttackDamage > 0, "attack damage must be positive")
	assert(
		definition.AttackWindupSeconds >= EnemyConfig.EvaluationIntervalSeconds
			and definition.AttackWindupSeconds < definition.AttackCooldownSeconds,
		"attack windup must be visible and shorter than cooldown"
	)
	assert(definition.AttackCooldownSeconds > 0, "attack cooldown must be positive")
	assert(definition.SpawnCost > 0 and definition.EncounterWeight > 0, "encounter cost/weight must be positive")
	assert(definition.BaseFieldXp >= 0, "base Field XP hook must be non-negative")
end

for _, definition in OrdinaryArchetypesById do
	validateOrdinary(definition)
end

assert(
	EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation > 0
		and EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation % 1 == 0
		and EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation
			<= EnemyConfig.Population.AbsoluteMaximumConcurrent,
	"the path-computation budget must be a positive bounded integer"
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
