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
	Version = "MVP-0.1-v5-appalachian-cycle",
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
		GeographicLatitude = 38,
		EnvironmentDiffuseScale = 0.7,
		EnvironmentSpecularScale = 0.5,
		GlobalShadows = true,
		ShadowSoftness = 0.38,
		Cycle = table.freeze({
			DurationSeconds = 1200,
			UpdateIntervalSeconds = 0.5,
			StartClockTime = 7.35,
		}),
		Day = table.freeze({
			Brightness = 2.45,
			ExposureCompensation = 0.08,
			Ambient = rgb(76, 80, 72),
			OutdoorAmbient = rgb(125, 132, 119),
			ColorShiftTop = rgb(12, 10, 6),
			ColorShiftBottom = rgb(4, 7, 5),
			FogColor = rgb(146, 170, 165),
			FogStart = 110,
			FogEnd = 660,
			Atmosphere = table.freeze({
				Color = rgb(194, 211, 204),
				Decay = rgb(88, 105, 96),
				Density = 0.22,
				Offset = 0.05,
				Glare = 0.06,
				Haze = 1.1,
			}),
			ColorGrade = table.freeze({
				Brightness = 0.005,
				Contrast = 0.08,
				Saturation = -0.08,
				TintColor = rgb(234, 238, 222),
			}),
			Bloom = table.freeze({
				Intensity = 0.1,
				Size = 22,
				Threshold = 1.4,
			}),
			BlurSize = 0.5,
			SunRaysIntensity = 0.035,
			Clouds = table.freeze({
				Cover = 0.4,
				Density = 0.45,
				Color = rgb(224, 225, 211),
			}),
		}),
		Night = table.freeze({
			Brightness = 1.4,
			ExposureCompensation = -0.12,
			Ambient = rgb(25, 31, 42),
			OutdoorAmbient = rgb(50, 61, 73),
			ColorShiftTop = rgb(8, 16, 28),
			ColorShiftBottom = rgb(2, 7, 13),
			FogColor = rgb(71, 88, 101),
			FogStart = 78,
			FogEnd = 405,
			Atmosphere = table.freeze({
				Color = rgb(144, 165, 178),
				Decay = rgb(43, 58, 70),
				Density = 0.3,
				Offset = 0.08,
				Glare = 0.015,
				Haze = 1.55,
			}),
			ColorGrade = table.freeze({
				Brightness = -0.01,
				Contrast = 0.12,
				Saturation = -0.2,
				TintColor = rgb(190, 207, 222),
			}),
			Bloom = table.freeze({
				Intensity = 0.18,
				Size = 24,
				Threshold = 1.28,
			}),
			BlurSize = 1.1,
			SunRaysIntensity = 0,
			Clouds = table.freeze({
				Cover = 0.56,
				Density = 0.52,
				Color = rgb(151, 165, 174),
			}),
		}),
		SunRaysSpread = 0.52,
		Sky = table.freeze({
			SkyboxBk = "rbxassetid://162001887",
			SkyboxDn = "rbxassetid://161998893",
			SkyboxFt = "rbxassetid://162001897",
			SkyboxLf = "rbxassetid://162001904",
			SkyboxRt = "rbxassetid://162001919",
			SkyboxUp = "rbxassetid://162001926",
			CelestialBodiesShown = true,
			StarCount = 2800,
			SunAngularSize = 10,
			MoonAngularSize = 9,
		}),
	}),
	Environment = table.freeze({
		Version = "environment-v2",
		Water = table.freeze({
			Color = rgb(36, 73, 83),
			Transparency = 0.3,
			Reflectance = 0.12,
			WaveSize = 0.08,
			WaveSpeed = 5,
		}),
		Mist = table.freeze({
			Color = rgb(177, 196, 195),
			Rate = 1.6,
			LifetimeMin = 6,
			LifetimeMax = 9,
			SpeedMin = 0.22,
			SpeedMax = 0.48,
			Anchors = table.freeze({
				point(25, 2.2, 12),
				point(-92, 2.0, 45),
				point(218, 1.8, 58),
			}),
		}),
		AccentLights = table.freeze({
			table.freeze({
				kind = "Point",
				position = point(-220, 8.5, -188),
				color = rgb(255, 176, 112),
				brightness = 1.15,
				range = 30,
			}),
			table.freeze({
				kind = "Spot",
				position = point(218, 12, 18),
				target = point(218, 1.2, 58),
				color = rgb(230, 218, 181),
				brightness = 1.65,
				range = 48,
				angle = 55,
			}),
		}),
	}),
	Dressing = table.freeze({
		Version = "readability-v2",
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
