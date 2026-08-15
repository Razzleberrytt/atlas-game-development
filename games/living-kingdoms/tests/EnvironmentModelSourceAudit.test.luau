--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local placementPath = "games/living-kingdoms/src/shared/Config/EnvironmentModelPlacementConfig.luau"
local worldConfigPath = "games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau"
local plannerPath = "games/living-kingdoms/src/server/EnvironmentCompositionPlanner.luau"
local factoryPath = "games/living-kingdoms/src/server/EnvironmentModelFactory.luau"
local dressingPath = "games/living-kingdoms/src/server/WorldVisualDressing.server.luau"

local function loadPureConfig(path)
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})()
end

local placementConfig = loadPureConfig(placementPath)
local world = loadPureConfig(worldConfigPath)

assert(placementConfig.Version == "environment-models-v3-seeded-fields", "environment model placement version changed")
assert(placementConfig.AlgorithmVersion == "gaussian-fields-poisson-v1", "composition algorithm identity changed")
assert(placementConfig.Seed == world.Seed, "environment composition must share the authored world seed")
assert(placementConfig.HalfExtentStuds <= world.PlayableHalfExtentStuds, "composition escaped authored world extent")
assert(placementConfig.CandidateCountPerAsset == 7000, "composition candidate budget changed")
assert(placementConfig.LandmarkPaddingStuds >= 8, "composition landmark padding is too small")

local allowedAssetIds = {
	["env.rock.frontier.boulder_a"] = true,
	["env.tree.corrupted.dead_pine_a"] = true,
	["env.structure.industry.mine_support_a"] = true,
	["env.camp.frontier.abandoned_fire_ring_a"] = true,
}
local allowedFields = {
	frontier = true,
	corruption = true,
	industry = true,
	camp = true,
}
local seenAssetIds = {}
local seenPrefixes = {}
local totalModelBudget = 0

assert(#placementConfig.AssetSpecs == 4, "starter composition must preserve four environment families")
for _, spec in placementConfig.AssetSpecs do
	assert(type(spec.idPrefix) == "string" and spec.idPrefix ~= "", "composition spec requires an id prefix")
	assert(not seenPrefixes[spec.idPrefix], "composition id prefixes must be unique: " .. spec.idPrefix)
	seenPrefixes[spec.idPrefix] = true
	assert(allowedAssetIds[spec.assetId], "composition uses unsupported starter asset: " .. spec.assetId)
	assert(allowedFields[spec.field], "composition uses unsupported story field: " .. spec.field)
	assert(not seenAssetIds[spec.assetId], "starter asset family duplicated in composition config: " .. spec.assetId)
	seenAssetIds[spec.assetId] = true
	assert(spec.count > 0, "composition family count must be positive")
	assert(spec.minSpacingStuds >= 30, "composition family spacing is too dense")
	assert(spec.minRouteDistanceStuds >= 28, "composition intrudes into the primary route readability lane")
	assert(spec.minCreekDistanceStuds >= 18, "composition intrudes into the creek readability lane")
	totalModelBudget += spec.count
end
assert(totalModelBudget == 29, "seeded environment model budget changed")

for assetId in allowedAssetIds do
	assert(seenAssetIds[assetId], "composition config is missing starter asset: " .. assetId)
end

for _, path in { plannerPath, factoryPath, dressingPath } do
	local loaded = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})
	assert(type(loaded) == "function", "environment model source must compile: " .. path)
end

local plannerSource = fs.readFile(plannerPath)
local factorySource = fs.readFile(factoryPath)
local dressingSource = fs.readFile(dressingPath)

for requiredPlannerToken in
	{
		"MODULUS = 2147483647",
		"MULTIPLIER = 48271",
		"local function gaussian",
		"local function polylineDistance",
		"local function minimumLandmarkClearance",
		"local function isFarEnough",
		"PlacementConfig.AssetSpecs",
		"WorldFoundationConfig.Dressing.TrailReflectorPositions",
		"WorldFoundationConfig.EnvironmentPresentation.Water.CreekPoints",
	}
do
	assert(
		string.find(plannerSource, requiredPlannerToken, 1, true),
		"environment composition planner is missing deterministic constraint: " .. requiredPlannerToken
	)
end

assert(
	string.find(factorySource, "EnvironmentAssetKitRegistry", 1, true),
	"factory must resolve semantic asset registry ids"
)
assert(string.find(factorySource, "part.Anchored = true", 1, true), "environment model parts must stay anchored")
assert(string.find(factorySource, "part.CanCollide = false", 1, true), "presentation models must not own collision")
assert(string.find(factorySource, "part.CanTouch = false", 1, true), "presentation models must not own touch authority")
assert(
	string.find(factorySource, "part.CanQuery = false", 1, true),
	"presentation models must not affect gameplay queries"
)
assert(
	string.find(factorySource, 'model:SetAttribute("EnvironmentPresentationOnly", true)', 1, true),
	"models must declare presentation-only ownership"
)
assert(
	not string.find(factorySource, 'Instance.new("PointLight")', 1, true),
	"environment models must add zero dynamic lights"
)
assert(
	not string.find(factorySource, 'Instance.new("SpotLight")', 1, true),
	"environment models must add zero dynamic lights"
)
assert(
	not string.find(factorySource, 'Instance.new("Script")', 1, true),
	"environment models must not add per-prop scripts"
)

for assetId in allowedAssetIds do
	assert(string.find(factorySource, assetId, 1, true), "factory is missing a registered starter builder: " .. assetId)
end

assert(
	string.find(dressingSource, "EnvironmentCompositionPlanner.Plan", 1, true),
	"world dressing must instantiate the deterministic composition plan"
)
assert(
	string.find(dressingSource, 'modelsFolder.Name = "EnvironmentModels"', 1, true),
	"world dressing must isolate environment models"
)
assert(
	string.find(dressingSource, 'worldRoot:FindFirstChild("TerrainFoundation")', 1, true),
	"environment models must ground against authored terrain geometry"
)
assert(
	string.find(dressingSource, "Workspace:Raycast", 1, true),
	"environment composition must resolve generated x/z coordinates onto world geometry"
)
assert(
	string.find(dressingSource, 'model:SetAttribute("EnvironmentField"', 1, true),
	"generated models must expose their mathematical story field for Studio inspection"
)

print("EnvironmentModelSourceAudit: seeded fields, budgets, semantic ids, grounding, and presentation authority passed")
