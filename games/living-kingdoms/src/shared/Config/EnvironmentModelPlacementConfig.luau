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
	Version = "environment-models-v2-landmark-framing",
	Placements = table.freeze({
		-- Rocky Overlook: layered stone silhouettes frame the landmark from just
		-- outside its authored core instead of crowding the combat/readability zone.
		placement("overlook.boulder.west", "env.rock.frontier.boulder_a", 105, 0.15, 181, -24),
		placement("overlook.boulder.north", "env.rock.frontier.boulder_a", 158, 0.05, 231, 31),
		placement("overlook.boulder.east", "env.rock.frontier.boulder_a", 211, 0.10, 188, 73),
		placement("overlook.boulder.south", "env.rock.frontier.boulder_a", 181, 0.12, 127, -51),

		-- Extraction-side corruption: dead pines sit beyond the extraction core so
		-- they establish a corrupted eastern silhouette without obscuring approach.
		placement("corruption.dead_pine.a", "env.tree.corrupted.dead_pine_a", 292, 0.0, 105, -11),
		placement("corruption.dead_pine.b", "env.tree.corrupted.dead_pine_a", 306, 0.0, 42, 23),
		placement("corruption.dead_pine.c", "env.tree.corrupted.dead_pine_a", 278, 0.0, 135, -37),

		-- Logging Road: abandoned timber supports live on opposite shoulders and
		-- avoid the existing log-loader/cut-log composition.
		placement("logging.mine_support.a", "env.structure.industry.mine_support_a", -42, 0.0, -86, 8),
		placement("logging.mine_support.b", "env.structure.industry.mine_support_a", 86, 0.0, -96, -16),

		-- Campground hero prop.
		placement("campground.fire_ring", "env.camp.frontier.abandoned_fire_ring_a", -82, 0.0, 52, 18),
	}),
}

return table.freeze(EnvironmentModelPlacementConfig)
