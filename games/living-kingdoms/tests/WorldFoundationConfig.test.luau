local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau")
local config = luau.load(source, {
	debugName = "WorldFoundationConfig",
	environment = {},
	injectGlobals = true,
})()

assert(config.Version == "P5-0102-v1", "world version changed")
assert(config.PlayableHalfExtentStuds == 320, "playable extent changed")
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
assert(config.Vegetation.PineCount >= 100, "primary forest canopy is no longer dense")
assert(config.Vegetation.HardwoodCount >= 40, "mixed hardwood layer is too sparse")
assert(config.Vegetation.RouteClearanceStuds >= 16, "authored routes need camera-readable canopy clearance")
assert(
	config.Vegetation.PineCount + config.Vegetation.HardwoodCount <= 160,
	"readability pass exceeded the prototype tree budget"
)
assert(config.Lighting.FogStart < config.Lighting.FogEnd, "fog bounds must be ordered")
assert(config.Lighting.FogStart >= 60, "near-route fog should preserve gameplay-camera readability")
assert(config.Lighting.FogEnd >= 500, "landmarks need a useful long-range reveal distance")
assert(
	config.InsertionPosition.x == -224 and config.InsertionPosition.z == -208,
	"insertion must remain at the ranger station"
)

for _, path in
	{
		"games/living-kingdoms/src/server/Systems/WorldFoundationService.luau",
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
	}
do
	assert(
		string.find(worldSource, requiredIdentity, 1, true) ~= nil,
		"missing landmark identity: " .. requiredIdentity
	)
end
assert(string.find(worldSource, "ROUTE_CORRIDORS", 1, true) ~= nil, "route-aware vegetation clearance is missing")
assert(string.find(worldSource, "buildEvacuationStory", 1, true) ~= nil, "evacuation storytelling pass is missing")

print("WorldFoundationConfig fixtures passed")
