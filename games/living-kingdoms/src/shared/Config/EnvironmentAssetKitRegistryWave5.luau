--!strict

-- Additive held-source registry shard for visual-production wave 5.
-- Interior dressing remains presentation-only and carries no loot/interact authority.

local Definitions = table.freeze({
	table.freeze({
		id = "env.prop.frontier.broken_table_a",
		family = "Prop",
		variantId = "frontier.interior.broken_table.a",
		biomeIds = table.freeze({ "biome.frontier", "biome.abandoned_industry" }),
		scaleClass = "Medium",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/Interiors/BrokenTableA",
		footprintStuds = table.freeze({ x = 6, y = 3, z = 4 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.prop.industry.rusted_locker_a",
		family = "Prop",
		variantId = "industry.interior.rusted_locker.a",
		biomeIds = table.freeze({ "biome.abandoned_industry", "biome.mine" }),
		scaleClass = "Medium",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({ table.freeze({ id = "socket.prop.top", kind = "Prop" }) }),
		sourceModelPath = "Environment/Interiors/RustedLockerA",
		footprintStuds = table.freeze({ x = 3, y = 6, z = 2 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.prop.frontier.cot_frame_a",
		family = "Prop",
		variantId = "frontier.interior.cot_frame.a",
		biomeIds = table.freeze({ "biome.frontier", "biome.abandoned_industry" }),
		scaleClass = "Medium",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({}),
		sourceModelPath = "Environment/Interiors/CotFrameA",
		footprintStuds = table.freeze({ x = 4, y = 2, z = 7 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.prop.frontier.wall_shelf_a",
		family = "Prop",
		variantId = "frontier.interior.wall_shelf.a",
		biomeIds = table.freeze({ "biome.frontier", "biome.abandoned_industry" }),
		scaleClass = "Medium",
		collisionPolicy = "None",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({ table.freeze({ id = "socket.prop.shelf", kind = "Prop" }) }),
		sourceModelPath = "Environment/Interiors/WallShelfA",
		footprintStuds = table.freeze({ x = 5, y = 5, z = 2 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
})

return table.freeze({
	Version = "ENV-ASSET-KIT-WAVE5-v1",
	Definitions = Definitions,
})
