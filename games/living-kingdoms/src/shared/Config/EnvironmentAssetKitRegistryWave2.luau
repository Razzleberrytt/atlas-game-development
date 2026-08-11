--!strict

-- Additive held-source registry shard for visual-production wave 2.
-- These definitions compose with EnvironmentAssetKitRegistry v4 under the
-- same EnvironmentAssetKitContracts. They remain presentation-only/unmapped.

local Definitions = table.freeze({
	table.freeze({
		id = "env.structure.industry.rail_track_section_a",
		family = "Industrial",
		variantId = "rail.track_section.a",
		biomeIds = table.freeze({ "biome.abandoned_industry", "biome.mine" }),
		scaleClass = "Large",
		collisionPolicy = "Simple",
		streamingGroupId = "main_world.structures",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/Industry/RailTrackSectionA",
		footprintStuds = table.freeze({ x = 6, y = 1, z = 16 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.structure.industry.broken_rail_bend_a",
		family = "Industrial",
		variantId = "rail.broken_bend.a",
		biomeIds = table.freeze({ "biome.abandoned_industry", "biome.mine" }),
		scaleClass = "Large",
		collisionPolicy = "Simple",
		streamingGroupId = "main_world.structures",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/Industry/BrokenRailBendA",
		footprintStuds = table.freeze({ x = 7, y = 2, z = 10 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.prop.industry.signal_post_a",
		family = "Prop",
		variantId = "rail.signal_post.a",
		biomeIds = table.freeze({ "biome.abandoned_industry", "biome.mine" }),
		scaleClass = "Large",
		collisionPolicy = "Simple",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({ table.freeze({ id = "socket.vfx.signal", kind = "VFX" }) }),
		sourceModelPath = "Environment/Industry/SignalPostA",
		footprintStuds = table.freeze({ x = 4, y = 9, z = 4 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.prop.industry.collapsed_pipe_stack_a",
		family = "Prop",
		variantId = "industry.collapsed_pipe_stack.a",
		biomeIds = table.freeze({ "biome.abandoned_industry", "biome.mine" }),
		scaleClass = "Large",
		collisionPolicy = "Simple",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/Industry/CollapsedPipeStackA",
		footprintStuds = table.freeze({ x = 11, y = 5, z = 8 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
})

return table.freeze({
	Version = "ENV-ASSET-KIT-WAVE2-v1",
	Definitions = Definitions,
})
