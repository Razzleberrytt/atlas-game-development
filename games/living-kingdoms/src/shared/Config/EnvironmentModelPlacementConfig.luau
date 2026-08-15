--!strict

-- Runtime-agnostic placement data for repository-owned presentation models.
-- Coordinates intentionally sit outside critical route centers and landmark cores.

local function placement(id: string, assetId: string, x: number, y: number, z: number, yawDegrees: number)
	return table.freeze({
		id = id,
		assetId = assetId,
		x = x,
		y = y,
		z = z,
		yawDegrees = yawDegrees,
	})
end

local EnvironmentModelPlacementConfig = {
	Version = "environment-models-v1",
	Placements = table.freeze({
		-- Rocky Overlook: layered stone silhouettes frame the landmark without
		-- narrowing the approach route.
		placement("overlook.boulder.west", "env.rock.frontier.boulder_a", 132, 0.15, 183, -24),
		placement("overlook.boulder.north", "env.rock.frontier.boulder_a", 157, 0.05, 207, 31),
		placement("overlook.boulder.east", "env.rock.frontier.boulder_a", 185, 0.10, 190, 73),
		placement("overlook.boulder.south", "env.rock.frontier.boulder_a", 177, 0.12, 151, -51),

		-- Extraction-side corruption: dead pines make the east side of the forest
		-- visually distinct while remaining presentation-only.
		placement("corruption.dead_pine.a", "env.tree.corrupted.dead_pine_a", 246, 0.0, 93, -11),
		placement("corruption.dead_pine.b", "env.tree.corrupted.dead_pine_a", 256, 0.0, 28, 23),
		placement("corruption.dead_pine.c", "env.tree.corrupted.dead_pine_a", 213, 0.0, 112, -37),

		-- Logging Road: abandoned timber supports read as industrial remnants on
		-- the road shoulder without becoming collision or navigation authority.
		placement("logging.mine_support.a", "env.structure.industry.mine_support_a", 44, 0.0, -91, 12),
		placement("logging.mine_support.b", "env.structure.industry.mine_support_a", 74, 0.0, -102, -16),

		-- Campground hero prop.
		placement("campground.fire_ring", "env.camp.frontier.abandoned_fire_ring_a", -82, 0.0, 52, 18),
	}),
}

return table.freeze(EnvironmentModelPlacementConfig)
