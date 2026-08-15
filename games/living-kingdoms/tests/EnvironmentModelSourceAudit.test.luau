--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local placementPath = "games/living-kingdoms/src/shared/Config/EnvironmentModelPlacementConfig.luau"
local worldConfigPath = "games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau"
local factoryPath = "games/living-kingdoms/src/server/EnvironmentModelFactory.luau"
local dressingPath = "games/living-kingdoms/src/server/WorldVisualDressing.server.luau"

local function loadPureConfig(path)
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})()
end

local placements = loadPureConfig(placementPath)
local world = loadPureConfig(worldConfigPath)

assert(placements.Version == "environment-models-v2-landmark-framing", "environment model placement version changed")
assert(#placements.Placements == 10, "environment model placement budget changed")

local allowedAssetIds = {
	["env.rock.frontier.boulder_a"] = true,
	["env.tree.corrupted.dead_pine_a"] = true,
	["env.structure.industry.mine_support_a"] = true,
	["env.camp.frontier.abandoned_fire_ring_a"] = true,
}
local placementIds = {}

local landmarks = {}
for _, landmark in world.Landmarks do
	landmarks[landmark.id] = landmark
end
local overlook = landmarks.RockyOverlook
local extraction = landmarks.ExtractionClearing
assert(overlook ~= nil and extraction ~= nil, "required landmark geometry is missing")

local function distance2d(x1, z1, x2, z2)
	local dx = x1 - x2
	local dz = z1 - z2
	return math.sqrt(dx * dx + dz * dz)
end

for _, placement in placements.Placements do
	assert(type(placement.id) == "string" and placement.id ~= "", "environment placement requires a stable id")
	assert(not placementIds[placement.id], "environment placement ids must be unique: " .. placement.id)
	placementIds[placement.id] = true
	assert(
		allowedAssetIds[placement.assetId],
		"environment placement uses an unsupported starter asset: " .. placement.assetId
	)
	assert(math.abs(placement.x) <= world.PlayableHalfExtentStuds, "environment model escaped authored x extent")
	assert(math.abs(placement.z) <= world.PlayableHalfExtentStuds, "environment model escaped authored z extent")

	if string.find(placement.id, "overlook.boulder.", 1, true) == 1 then
		assert(
			distance2d(placement.x, placement.z, overlook.x, overlook.z) > overlook.radius + 5,
			"overlook boulder intrudes into the authored landmark core: " .. placement.id
		)
	elseif string.find(placement.id, "corruption.dead_pine.", 1, true) == 1 then
		assert(
			distance2d(placement.x, placement.z, extraction.x, extraction.z) > extraction.radius + 10,
			"corrupted pine intrudes into the extraction readability core: " .. placement.id
		)
	elseif string.find(placement.id, "logging.mine_support.", 1, true) == 1 then
		assert(
			distance2d(placement.x, placement.z, 45, -91) > 30,
			"mine support visually collides with the existing log loader: " .. placement.id
		)
	end
end

for _, path in { factoryPath, dressingPath } do
	local loaded = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})
	assert(type(loaded) == "function", "environment model source must compile: " .. path)
end

local factorySource = fs.readFile(factoryPath)
local dressingSource = fs.readFile(dressingPath)
assert(string.find(factorySource, "EnvironmentAssetKitRegistry", 1, true), "factory must resolve semantic asset registry ids")
assert(string.find(factorySource, "part.Anchored = true", 1, true), "environment model parts must stay anchored")
assert(string.find(factorySource, "part.CanCollide = false", 1, true), "presentation models must not own collision")
assert(string.find(factorySource, "part.CanTouch = false", 1, true), "presentation models must not own touch authority")
assert(string.find(factorySource, "part.CanQuery = false", 1, true), "presentation models must not affect gameplay queries")
assert(
	string.find(factorySource, 'model:SetAttribute("EnvironmentPresentationOnly", true)', 1, true),
	"models must declare presentation-only ownership"
)
assert(not string.find(factorySource, 'Instance.new("PointLight")', 1, true), "environment models must add zero dynamic lights")
assert(not string.find(factorySource, 'Instance.new("SpotLight")', 1, true), "environment models must add zero dynamic lights")
assert(not string.find(factorySource, 'Instance.new("Script")', 1, true), "environment models must not add per-prop scripts")

for assetId in allowedAssetIds do
	assert(string.find(factorySource, assetId, 1, true), "factory is missing a registered starter builder: " .. assetId)
end

assert(string.find(dressingSource, "EnvironmentModelFactory.Build", 1, true), "world dressing must instantiate model placements")
assert(
	string.find(dressingSource, 'modelsFolder.Name = "EnvironmentModels"', 1, true),
	"world dressing must isolate environment models"
)
assert(
	string.find(dressingSource, "EnvironmentModelPlacementConfig.Placements", 1, true),
	"world dressing must remain data-driven"
)

print("EnvironmentModelSourceAudit: semantic ids, placement clearance, budgets, and presentation authority passed")
