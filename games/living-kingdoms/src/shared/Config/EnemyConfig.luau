--!strict

local EnemyConfig = {
	Version = "P5-0104-v1",
	ArchetypeId = "Shambler",
	ModelFolderName = "ProductionEnemies",
	-- Must remain synchronized with WorldFoundationConfig.PlayableHalfExtentStuds;
	-- the focused fixture verifies the authored-world invariant.
	PlayableHalfExtentStuds = 320,
	MaximumHealth = 100,
	WalkSpeedStudsPerSecond = 9,
	AcquisitionRadiusStuds = 150,
	TargetLossRadiusStuds = 190,
	AttackRangeStuds = 4.5,
	AttackDamage = 20,
	AttackCadenceSeconds = 1.35,
	PathRefreshIntervalSeconds = 0.75,
	DirectMoveRefreshIntervalSeconds = 0.2,
	StuckEvaluationWindowSeconds = 2.5,
	MinimumFairSpawnDistanceStuds = 55,
	MaximumActiveEnemies = 24,
	CorpseLifetimeSeconds = 5,
	SimulationIntervalSeconds = 0.1,
	TargetEvaluationsPerTick = 4,
	PathRequestsPerTick = 2,
	MaximumWaypointsPerPath = 12,
	SpawnOverlapBoxSize = table.freeze({ x = 5, y = 7, z = 5 }),
	PlaceholderModel = table.freeze({
		RootSize = table.freeze({ x = 2.5, y = 2.5, z = 2.5 }),
		BodySize = table.freeze({ x = 3, y = 4.5, z = 2 }),
		HeadSize = table.freeze({ x = 2, y = 2, z = 2 }),
		HipHeight = 2.5,
	}),
}

assert(EnemyConfig.MaximumHealth > 0, "MaximumHealth must be positive")
assert(EnemyConfig.WalkSpeedStudsPerSecond > 0, "WalkSpeedStudsPerSecond must be positive")
assert(EnemyConfig.AcquisitionRadiusStuds > 0, "AcquisitionRadiusStuds must be positive")
assert(
	EnemyConfig.TargetLossRadiusStuds >= EnemyConfig.AcquisitionRadiusStuds,
	"TargetLossRadiusStuds must not be smaller than AcquisitionRadiusStuds"
)
assert(EnemyConfig.AttackRangeStuds > 0, "AttackRangeStuds must be positive")
assert(EnemyConfig.AttackDamage > 0, "AttackDamage must be positive")
assert(EnemyConfig.AttackCadenceSeconds > 0, "AttackCadenceSeconds must be positive")
assert(EnemyConfig.PathRefreshIntervalSeconds >= EnemyConfig.SimulationIntervalSeconds, "Path refresh must be bounded")
assert(
	EnemyConfig.DirectMoveRefreshIntervalSeconds >= EnemyConfig.SimulationIntervalSeconds,
	"Move refresh must be bounded"
)
assert(
	EnemyConfig.MinimumFairSpawnDistanceStuds > EnemyConfig.AttackRangeStuds,
	"Spawn distance must exceed attack range"
)
assert(EnemyConfig.MaximumActiveEnemies >= 1, "MaximumActiveEnemies must allow at least one enemy")
assert(EnemyConfig.CorpseLifetimeSeconds >= 0, "CorpseLifetimeSeconds must be non-negative")
assert(EnemyConfig.SimulationIntervalSeconds >= 0.1, "Production enemy simulation may not exceed 10 Hz")
assert(EnemyConfig.TargetEvaluationsPerTick >= 1, "TargetEvaluationsPerTick must be positive")
assert(EnemyConfig.PathRequestsPerTick >= 1, "PathRequestsPerTick must be positive")
assert(EnemyConfig.MaximumWaypointsPerPath >= 1, "MaximumWaypointsPerPath must be positive")

return table.freeze(EnemyConfig)
