--!strict

-- Presentation-only starter registry for the Living Kingdoms environment content factory.
-- Final meshes may replace these source paths without changing semantic IDs or gameplay authority.

local Registry = {
	Version = "ENV-ASSET-KIT-v1",
	Definitions = table.freeze({
		table.freeze({
			id = "env.rock.frontier.boulder_a",
			family = "Rock",
			variantId = "frontier.boulder.a",
			biomeIds = table.freeze({ "biome.frontier", "biome.corrupted_wilderness" }),
			scaleClass = "Large",
			collisionPolicy = "Simple",
			streamingGroupId = "main_world.resources",
			qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
			sockets = table.freeze({}),
			sourceModelPath = "Environment/Rocks/FrontierBoulderA",
			footprintStuds = table.freeze({ x = 12, y = 8, z = 10 }),
			presentationOnly = true,
			gameplayAuthorityOwnerId = nil,
		}),
		table.freeze({
			id = "env.tree.corrupted.dead_pine_a",
			family = "DeadTree",
			variantId = "corrupted.dead_pine.a",
			biomeIds = table.freeze({ "biome.corrupted_wilderness" }),
			scaleClass = "Hero",
			collisionPolicy = "Simple",
			streamingGroupId = "main_world.resources",
			qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
			sockets = table.freeze({
				table.freeze({ id = "socket.vfx.canopy", kind = "VFX" }),
				table.freeze({ id = "socket.audio.creak", kind = "Audio" }),
			}),
			sourceModelPath = "Environment/Foliage/CorruptedDeadPineA",
			footprintStuds = table.freeze({ x = 10, y = 30, z = 10 }),
			presentationOnly = true,
			gameplayAuthorityOwnerId = nil,
		}),
		table.freeze({
			id = "env.structure.industry.mine_support_a",
			family = "Industrial",
			variantId = "mine.support.a",
			biomeIds = table.freeze({ "biome.abandoned_industry", "biome.mine" }),
			scaleClass = "Large",
			collisionPolicy = "Blocker",
			streamingGroupId = "main_world.structures",
			qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
			sockets = table.freeze({
				table.freeze({ id = "socket.snap.left", kind = "Snap" }),
				table.freeze({ id = "socket.snap.right", kind = "Snap" }),
				table.freeze({ id = "socket.prop.lantern", kind = "Prop" }),
			}),
			sourceModelPath = "Environment/Industry/MineSupportA",
			footprintStuds = table.freeze({ x = 16, y = 16, z = 8 }),
			presentationOnly = true,
			gameplayAuthorityOwnerId = nil,
		}),
		table.freeze({
			id = "env.camp.frontier.abandoned_fire_ring_a",
			family = "Camp",
			variantId = "frontier.abandoned_fire_ring.a",
			biomeIds = table.freeze({ "biome.frontier", "biome.corrupted_wilderness" }),
			scaleClass = "Medium",
			collisionPolicy = "None",
			streamingGroupId = "main_world.resources",
			qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
			sockets = table.freeze({
				table.freeze({ id = "socket.vfx.embers", kind = "VFX" }),
				table.freeze({ id = "socket.audio.fire", kind = "Audio" }),
			}),
			sourceModelPath = "Environment/Camps/AbandonedFireRingA",
			footprintStuds = table.freeze({ x = 8, y = 2, z = 8 }),
			presentationOnly = true,
			gameplayAuthorityOwnerId = nil,
		}),
	}),
}

return table.freeze(Registry)
