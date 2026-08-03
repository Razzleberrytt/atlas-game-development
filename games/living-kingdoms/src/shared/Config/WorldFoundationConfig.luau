--!strict

-- P5-0102 authored-world constants. Geometry remains replaceable graybox, but
-- these stable routes and landmark IDs preserve the operation's visual language.
local WorldFoundationConfig = {
	Version = "P5-0102-v2-immersive-expanse",
	Seed = 1847,
	WorldRootName = "LivingKingdomsWorld",
	PlayableHalfExtentStuds = 640,
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
		PineCount = 290,
		HardwoodCount = 118,
		FallenLogCount = 38,
		BoulderCount = 124,
		ShrubClusterCount = 180,
		MinimumLandmarkClearanceStuds = 14,
		RouteClearanceStuds = 18,
	}),
	Lighting = table.freeze({
		ClockTime = 3.85,
		GeographicLatitude = 38,
		Brightness = 2.35,
		ExposureCompensation = 0.24,
		FogStart = 85,
		FogEnd = 485,
	}),
}

return table.freeze(WorldFoundationConfig)
