--!strict

-- P5-0101 authored-world constants. The geometry remains graybox, but these
-- stable IDs and positions establish the operation's traversal language.
local WorldFoundationConfig = {
	Version = "P5-0101-v1",
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
		PineCount = 118,
		HardwoodCount = 52,
		FallenLogCount = 18,
		BoulderCount = 58,
		MinimumLandmarkClearanceStuds = 10,
	}),
	Lighting = table.freeze({
		ClockTime = 2.15,
		Brightness = 2.1,
		ExposureCompensation = 0.08,
		FogStart = 60,
		FogEnd = 480,
	}),
}

return table.freeze(WorldFoundationConfig)
