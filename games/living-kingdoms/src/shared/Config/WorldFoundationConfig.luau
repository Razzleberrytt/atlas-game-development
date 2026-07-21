--!strict

-- P5-0102 authored-world constants. Geometry remains replaceable graybox, but
-- these stable routes and landmark IDs preserve the operation's visual language.
local WorldFoundationConfig = {
	Version = "P5-0102-v1",
	Seed = 1847,
	WorldRootName = "LivingKingdomsWorld",
	PlayableHalfExtentStuds = 320,
	InsertionPosition = table.freeze({ x = -224, y = 5, z = -208 }),
	Landmarks = table.freeze({
		table.freeze({ id = "RangerStation", displayName = "Ranger Station", x = -220, z = -190, radius = 44 }),
		table.freeze({ id = "LoggingRoad", displayName = "Logging Road", x = 0, z = -112, radius = 32 }),
		table.freeze({ id = "LookoutTower", displayName = "Forest Service Lookout", x = -205, z = 170, radius = 38 }),
		table.freeze({ id = "Campground", displayName = "Campground", x = -92, z = 45, radius = 42 }),
		table.freeze({ id = "CreekCrossing", displayName = "Creek Crossing", x = 25, z = 12, radius = 32 }),
		table.freeze({ id = "RockyOverlook", displayName = "Rocky Overlook", x = 158, z = 176, radius = 42 }),
		table.freeze({ id = "MilitaryRoadblock", displayName = "Military Roadblock", x = 180, z = -178, radius = 44 }),
		table.freeze({
			id = "ExtractionClearing",
			displayName = "Forest Extraction Clearing",
			x = 218,
			z = 58,
			radius = 58,
		}),
	}),
	Vegetation = table.freeze({
		PineCount = 104,
		HardwoodCount = 44,
		FallenLogCount = 15,
		BoulderCount = 52,
		MinimumLandmarkClearanceStuds = 14,
		RouteClearanceStuds = 18,
	}),
	Lighting = table.freeze({
		ClockTime = 4.2,
		GeographicLatitude = 38,
		Brightness = 2.8,
		ExposureCompensation = 0.5,
		FogStart = 96,
		FogEnd = 600,
	}),
}

return table.freeze(WorldFoundationConfig)
