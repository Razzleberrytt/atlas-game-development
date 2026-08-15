--!strict

-- P5-0102 authored-world constants. Geometry remains replaceable graybox, but
-- these stable routes, landmarks, and presentation profiles preserve the
-- operation's visual language while keeping runtime tuning centralized.
-- Keep this module runtime-agnostic: Lune fixtures load it without Roblox globals.
local function rgb(r: number, g: number, b: number)
	return table.freeze({ r = r, g = g, b = b })
end

local function point(x: number, y: number, z: number)
	return table.freeze({ x = x, y = y, z = z })
end

local WorldFoundationConfig = {
	Version = "MVP-0.1-v4-forest-clarity",
	Seed = 1847,
	WorldRootName = "LivingKingdomsWorld",
	PlayableHalfExtentStuds = 640,
	InsertionPosition = table.freeze({ x = -224, y = 3.4, z = -208 }),
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
		FernClusterCount = 42,
		WildflowerClusterCount = 24,
		MushroomClusterCount = 18,
		MinimumLandmarkClearanceStuds = 14,
		RouteClearanceStuds = 18,
	}),
	Lighting = table.freeze({
		ClockTime = 7.35,
		GeographicLatitude = 38,
		Brightness = 2.65,
		ExposureCompensation = 0.12,
		Ambient = rgb(91, 85, 71),
		OutdoorAmbient = rgb(132, 126, 104),
		EnvironmentDiffuseScale = 0.7,
		EnvironmentSpecularScale = 0.5,
		GlobalShadows = true,
		ShadowSoftness = 0.38,
		FogColor = rgb(151, 178, 172),
		FogStart = 120,
		FogEnd = 620,
		Atmosphere = table.freeze({
			Color = rgb(196, 216, 205),
			Decay = rgb(82, 106, 95),
			Density = 0.22,
			Offset = 0.05,
			Glare = 0.08,
			Haze = 1.05,
		}),
		ColorGrade = table.freeze({
			Brightness = 0.015,
			Contrast = 0.08,
			Saturation = 0.16,
			TintColor = rgb(255, 238, 208),
		}),
		Bloom = table.freeze({
			Intensity = 0.18,
			Size = 24,
			Threshold = 1.35,
		}),
		SunRays = table.freeze({
			Intensity = 0.045,
			Spread = 0.52,
		}),
		Clouds = table.freeze({
			Cover = 0.38,
			Density = 0.44,
			Color = rgb(232, 225, 205),
		}),
		Night = table.freeze({
			BrightnessStart = 2.05,
			BrightnessEnd = 1.25,
			ExposureStart = 0.12,
			ExposureEnd = -0.30,
			FogEndStart = 485,
			AmbientStart = rgb(35, 44, 56),
			AmbientEnd = rgb(15, 19, 31),
		}),
	}),
	Dressing = table.freeze({
		Version = "readability-v1",
		-- Emissive-only route markers deliberately add no dynamic lights. They are
		-- presentation-only and sit outside gameplay/query surfaces.
		TrailReflectorPositions = table.freeze({
			point(-205, 2.35, -190),
			point(-174, 2.35, -174),
			point(-140, 2.35, -162),
			point(-105, 2.35, -151),
			point(-67, 2.35, -142),
			point(-28, 2.35, -130),
			point(12, 2.35, -118),
			point(52, 2.35, -122),
			point(94, 2.35, -140),
			point(136, 2.35, -158),
			point(178, 2.35, -176),
			point(205, 2.35, -132),
		}),
	}),
}

return table.freeze(WorldFoundationConfig)
