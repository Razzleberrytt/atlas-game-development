--!strict

-- Additive held-source registry shard for visual-production wave 4.
-- Dense ground clutter composes with the existing environment registries under
-- EnvironmentAssetKitContracts and remains presentation-only/runtime-unmapped.

local Definitions = table.freeze({
	table.freeze({
		id = "env.clutter.frontier.dry_brush_patch_a",
		family = "GroundClutter",
		variantId = "frontier.dry_brush_patch.a",
		biomeIds = table.freeze({ "biome.frontier", "biome.corrupted_wilderness" }),
		scaleClass = "Small",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/GroundClutter/DryBrushPatchA",
		footprintStuds = table.freeze({ x = 5, y = 2, z = 4 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.clutter.frontier.stone_shard_scatter_a",
		family = "GroundClutter",
		variantId = "frontier.stone_shard_scatter.a",
		biomeIds = table.freeze({ "biome.frontier", "biome.mine" }),
		scaleClass = "Small",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/GroundClutter/StoneShardScatterA",
		footprintStuds = table.freeze({ x = 5, y = 1, z = 5 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.clutter.industry.rusted_scrap_scatter_a",
		family = "GroundClutter",
		variantId = "industry.rusted_scrap_scatter.a",
		biomeIds = table.freeze({ "biome.abandoned_industry", "biome.mine" }),
		scaleClass = "Small",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/GroundClutter/RustedScrapScatterA",
		footprintStuds = table.freeze({ x = 5, y = 1, z = 4 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.clutter.corruption.tendril_mat_a",
		family = "GroundClutter",
		variantId = "corruption.tendril_mat.a",
		biomeIds = table.freeze({ "biome.corrupted_wilderness", "biome.abandoned_industry" }),
		scaleClass = "Medium",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({ table.freeze({ id = "socket.vfx.resin", kind = "VFX" }) }),
		sourceModelPath = "Environment/GroundClutter/CorruptionTendrilMatA",
		footprintStuds = table.freeze({ x = 5, y = 1, z = 5 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
})

return table.freeze({
	Version = "ENV-ASSET-KIT-WAVE4-v1",
	Definitions = Definitions,
})
