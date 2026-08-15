local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau")
local config = luau.load(source, {
	debugName = "WorldFoundationConfig",
	environment = {},
	injectGlobals = true,
})()

assert(config.Version == "MVP-0.1-v4-forest-clarity", "world version changed")
assert(config.PlayableHalfExtentStuds == 640, "immersive expanse must retain its authored extent")
assert(config.Seed == 1847, "deterministic seed changed")
assert(#config.Landmarks == 8, "required landmark count changed")

local expectedIds = {
	RangerStation = true,
	LoggingRoad = true,
	LookoutTower = true,
	Campground = true,
	CreekCrossing = true,
	RockyOverlook = true,
	MilitaryRoadblock = true,
	ExtractionClearing = true,
}

for _, landmark in config.Landmarks do
	assert(expectedIds[landmark.id], "unexpected landmark " .. landmark.id)
	assert(type(landmark.displayName) == "string" and #landmark.displayName > 0, "landmark needs a name")
	assert(
		type(landmark.x) == "number" and math.abs(landmark.x) <= config.PlayableHalfExtentStuds,
		"landmark x is outside the operation"
	)
	assert(
		type(landmark.z) == "number" and math.abs(landmark.z) <= config.PlayableHalfExtentStuds,
		"landmark z is outside the operation"
	)
	assert(type(landmark.radius) == "number" and landmark.radius > 0, "landmark radius must be positive")
	expectedIds[landmark.id] = nil
end

assert(next(expectedIds) == nil, "all required landmarks must be present exactly once")
assert(config.Vegetation.PineCount >= 280, "expanded primary forest canopy is no longer dense")
assert(config.Vegetation.HardwoodCount >= 110, "expanded mixed hardwood layer is too sparse")
assert(config.Vegetation.ShrubClusterCount >= 170, "expanded understory is too sparse")
assert(config.Vegetation.RouteClearanceStuds >= 16, "authored routes need camera-readable canopy clearance")
assert(
	config.Vegetation.PineCount + config.Vegetation.HardwoodCount <= 440,
	"immersive expanse exceeded the authored tree budget"
)
assert(config.Lighting.FogStart < config.Lighting.FogEnd, "fog bounds must be ordered")
assert(config.Vegetation.FernClusterCount >= 36, "near-camera fern detail is too sparse")
assert(config.Vegetation.WildflowerClusterCount >= 20, "the operation needs bounded color accents")
assert(config.Vegetation.MushroomClusterCount >= 16, "forest-floor identity is too sparse")
assert(
	config.Lighting.ClockTime >= 7 and config.Lighting.ClockTime <= 9,
	"safe arrival must begin in warm morning light"
)
assert(config.Lighting.Brightness >= 2.5, "world lighting must preserve terrain and enemy silhouettes")
assert(config.Lighting.ExposureCompensation >= 0, "world lighting must not crush dark materials")
assert(config.Lighting.FogStart >= 110, "near-route fog should preserve exploration readability")
assert(config.Lighting.FogEnd >= 600, "major landmarks need a useful reveal distance")
assert(config.Lighting.EnvironmentDiffuseScale <= 1, "diffuse environment contribution must remain bounded")
assert(config.Lighting.EnvironmentSpecularScale <= 1, "specular environment contribution must remain bounded")
assert(
	config.Lighting.Atmosphere.Density > 0 and config.Lighting.Atmosphere.Density < 0.5,
	"atmosphere must stay readable"
)
assert(config.Lighting.Bloom.Intensity <= 0.25, "bloom must remain restrained")
assert(config.Lighting.Night.BrightnessEnd < config.Lighting.Night.BrightnessStart, "night must darken progressively")
assert(config.Lighting.Night.FogEndStart < config.Lighting.FogEnd, "night must close the long-distance reveal")
assert(config.Dressing.Version == "readability-v1", "readability dressing version changed")
assert(#config.Dressing.TrailReflectorPositions == 12, "trail reflector budget changed")
for _, position in config.Dressing.TrailReflectorPositions do
	assert(
		type(position.x) == "number" and type(position.y) == "number" and type(position.z) == "number",
		"dressing coordinates must remain pure data"
	)
	assert(
		math.abs(position.x) <= config.PlayableHalfExtentStuds
			and math.abs(position.z) <= config.PlayableHalfExtentStuds,
		"dressing marker escaped the authored world"
	)
end
assert(
	config.InsertionPosition.x == -224 and config.InsertionPosition.z == -208,
	"insertion must remain at the ranger station"
)

for _, path in
	{
		"games/living-kingdoms/src/server/Systems/WorldFoundationService.luau",
		"games/living-kingdoms/src/server/Systems/EnvironmentProfileService.luau",
		"games/living-kingdoms/src/server/WorldVisualDressing.server.luau",
		"games/living-kingdoms/src/client/Controllers/EnvironmentAmbienceController.luau",
	}
do
	local loaded = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})
	assert(type(loaded) == "function", "environment source must compile: " .. path)
end

local worldSource = fs.readFile("games/living-kingdoms/src/server/Systems/WorldFoundationService.luau")
for _, requiredIdentity in
	{
		"RangerGenerator",
		"RadioMast",
		"AbandonedLogLoader",
		"AviationWarningLight",
		"PicnicTableTop",
		"ShallowCrossingRock",
		"DistantTownLight",
		"CheckpointFloodlight",
		"DormantFlarePosition",
		"ApproachCorridorCenterline",
		"BlackPineBasin",
		"WhisperMarsh",
		"MoonfallQuarry",
		"AshenFirebreak",
		"HollowCreekRuins",
		"LostInfrastructure",
		"AtmosphericVista",
		"WillOWisp",
		"DistantValleyLight",
	}
do
	assert(
		string.find(worldSource, requiredIdentity, 1, true) ~= nil,
		"missing landmark identity: " .. requiredIdentity
	)
end
assert(string.find(worldSource, "ROUTE_CORRIDORS", 1, true) ~= nil, "route-aware vegetation clearance is missing")
assert(string.find(worldSource, "buildEvacuationStory", 1, true) ~= nil, "evacuation storytelling pass is missing")
assert(string.find(worldSource, "buildImmersiveExpanse", 1, true) ~= nil, "immersive outer-region pass is missing")
assert(string.find(worldSource, "buildLivingGroundDetail", 1, true) ~= nil, "living ground-detail pass is missing")
assert(string.find(worldSource, "grade.Saturation = 0.16", 1, true) ~= nil, "warm color grade is missing")

local environmentProfileSource = fs.readFile("games/living-kingdoms/src/server/Systems/EnvironmentProfileService.luau")
assert(
	string.find(environmentProfileSource, "LivingKingdomsAtmosphere", 1, true),
	"canonical atmosphere owner is missing"
)
assert(
	string.find(environmentProfileSource, "LivingKingdomsColorGrade", 1, true),
	"canonical color-grade owner is missing"
)
assert(string.find(environmentProfileSource, "LivingKingdomsBloom", 1, true), "canonical bloom owner is missing")
assert(string.find(environmentProfileSource, "LivingKingdomsSunRays", 1, true), "canonical sun-ray owner is missing")
assert(string.find(environmentProfileSource, "LivingKingdomsClouds", 1, true), "canonical cloud owner is missing")

local dressingSource = fs.readFile("games/living-kingdoms/src/server/WorldVisualDressing.server.luau")
assert(string.find(dressingSource, "CanCollide = false", 1, true), "readability dressing must not alter collision")
assert(string.find(dressingSource, "CanQuery = false", 1, true), "readability dressing must not alter gameplay queries")
assert(string.find(dressingSource, "Enum.Material.Neon", 1, true), "reflective markers need emissive readability")
assert(not string.find(dressingSource, "PointLight", 1, true), "readability dressing must add zero dynamic lights")

print("WorldFoundationConfig fixtures passed")
