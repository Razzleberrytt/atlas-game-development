--!strict

-- Deterministic composition rules for repository-owned environmental models.
-- The runtime planner turns these constraints into stable placements using the
-- world seed, Gaussian story fields, route/creek clearances, and Poisson-like
-- spacing. No gameplay authority is created by this configuration.

local EnvironmentModelPlacementConfig = {
	Version = "environment-models-v3-seeded-fields",
	AlgorithmVersion = "gaussian-fields-poisson-v1",
	Seed = 1847,
	HalfExtentStuds = 320,
	CandidateCountPerAsset = 7000,
	LandmarkPaddingStuds = 8,
	AssetSpecs = table.freeze({
		table.freeze({
			idPrefix = "frontier.boulder",
			assetId = "env.rock.frontier.boulder_a",
			field = "frontier",
			count = 11,
			minSpacingStuds = 38,
			minRouteDistanceStuds = 28,
			minCreekDistanceStuds = 18,
		}),
		table.freeze({
			idPrefix = "corruption.dead_pine",
			assetId = "env.tree.corrupted.dead_pine_a",
			field = "corruption",
			count = 9,
			minSpacingStuds = 34,
			minRouteDistanceStuds = 28,
			minCreekDistanceStuds = 18,
		}),
		table.freeze({
			idPrefix = "industry.mine_support",
			assetId = "env.structure.industry.mine_support_a",
			field = "industry",
			count = 5,
			minSpacingStuds = 42,
			minRouteDistanceStuds = 34,
			minCreekDistanceStuds = 24,
		}),
		table.freeze({
			idPrefix = "camp.fire_ring",
			assetId = "env.camp.frontier.abandoned_fire_ring_a",
			field = "camp",
			count = 4,
			minSpacingStuds = 55,
			minRouteDistanceStuds = 32,
			minCreekDistanceStuds = 24,
		}),
	}),
}

return table.freeze(EnvironmentModelPlacementConfig)
