--!strict

-- Additive held-source registry shard for visual-production wave 3.
-- These definitions compose with EnvironmentAssetKitRegistry v4 and wave 2
-- under the same EnvironmentAssetKitContracts. They remain presentation-only/unmapped.

local Definitions = table.freeze({
	table.freeze({
		id = "env.cave.ritual.rib_arch_a",
		family = "Cave",
		variantId = "ritual.cave_rib_arch.a",
		biomeIds = table.freeze({ "biome.mine", "biome.corrupted_wilderness" }),
		scaleClass = "Large",
		collisionPolicy = "Blocker",
		streamingGroupId = "main_world.structures",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({
			table.freeze({ id = "socket.snap.left", kind = "Snap" }),
			table.freeze({ id = "socket.snap.right", kind = "Snap" }),
		}),
		sourceModelPath = "Environment/CaveRitual/CaveRibArchA",
		footprintStuds = table.freeze({ x = 9, y = 8, z = 3 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.structure.ritual.stone_altar_a",
		family = "Structure",
		variantId = "ritual.stone_altar.a",
		biomeIds = table.freeze({ "biome.mine", "biome.corrupted_wilderness" }),
		scaleClass = "Medium",
		collisionPolicy = "Simple",
		streamingGroupId = "main_world.structures",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({
			table.freeze({ id = "socket.prop.offering", kind = "Prop" }),
			table.freeze({ id = "socket.vfx.rune", kind = "VFX" }),
		}),
		sourceModelPath = "Environment/CaveRitual/RitualStoneAltarA",
		footprintStuds = table.freeze({ x = 6, y = 3, z = 4 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.structure.ritual.runic_pillar_a",
		family = "Structure",
		variantId = "ritual.runic_pillar.a",
		biomeIds = table.freeze({ "biome.mine", "biome.corrupted_wilderness" }),
		scaleClass = "Large",
		collisionPolicy = "Simple",
		streamingGroupId = "main_world.structures",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({
			table.freeze({ id = "socket.vfx.rune", kind = "VFX" }),
			table.freeze({ id = "socket.audio.hum", kind = "Audio" }),
		}),
		sourceModelPath = "Environment/CaveRitual/RunicStonePillarA",
		footprintStuds = table.freeze({ x = 3, y = 7, z = 3 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
	table.freeze({
		id = "env.prop.ritual.offering_brazier_a",
		family = "Prop",
		variantId = "ritual.offering_brazier.a",
		biomeIds = table.freeze({ "biome.mine", "biome.corrupted_wilderness" }),
		scaleClass = "Medium",
		collisionPolicy = "Simple",
		streamingGroupId = "main_world.resources",
		qualityTiers = table.freeze({ "Minimum", "Reduced", "Full" }),
		sockets = table.freeze({
			table.freeze({ id = "socket.vfx.embers", kind = "VFX" }),
			table.freeze({ id = "socket.audio.fire", kind = "Audio" }),
		}),
		sourceModelPath = "Environment/CaveRitual/OfferingBrazierA",
		footprintStuds = table.freeze({ x = 3, y = 3, z = 3 }),
		presentationOnly = true,
		gameplayAuthorityOwnerId = nil,
	}),
})

return table.freeze({
	Version = "ENV-ASSET-KIT-WAVE3-v1",
	Definitions = Definitions,
})
