--!strict

-- Additive held-source registry shard for visual-production wave 4.
-- Dense clutter remains presentation-only and carries no gathering/resource authority.

local Definitions = table.freeze({
	table.freeze({
		id = "env.clutter.frontier.pebble_scatter_a",
		family = "GroundClutter",
		variantId = "frontier.pebble_scatter.a",
		biomeIds = table.freeze({ "biome.frontier", "biome.abandoned_industry", "biome.mine" }),
		scaleClass = "Small",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/GroundClutter/PebbleScatterA",
		footprintStuds = table.freeze({ x = 4, y = 1, z = 3 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.clutter.frontier.fallen_branch_tangle_a",
		family = "GroundClutter",
		variantId = "frontier.fallen_branch_tangle.a",
		biomeIds = table.freeze({ "biome.frontier", "biome.corrupted_wilderness" }),
		scaleClass = "Small",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/GroundClutter/FallenBranchTangleA",
		footprintStuds = table.freeze({ x = 5, y = 1, z = 4 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.clutter.cave.shard_scatter_a",
		family = "GroundClutter",
		variantId = "cave.shard_scatter.a",
		biomeIds = table.freeze({ "biome.mine", "biome.corrupted_wilderness" }),
		scaleClass = "Small",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({ table.freeze({ id = "socket.vfx.dust", kind = "VFX" }) }),
		sourceModelPath = "Environment/GroundClutter/CaveShardScatterA",
		footprintStuds = table.freeze({ x = 4, y = 2, z = 3 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.brush.frontier.dead_brush_mat_a",
		family = "Brush",
		variantId = "frontier.dead_brush_mat.a",
		biomeIds = table.freeze({ "biome.frontier", "biome.corrupted_wilderness" }),
		scaleClass = "Small",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/GroundClutter/DeadBrushMatA",
		footprintStuds = table.freeze({ x = 4, y = 2, z = 3 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
})

return table.freeze({
	Version = "ENV-ASSET-KIT-WAVE4-v1",
	Definitions = Definitions,
})
