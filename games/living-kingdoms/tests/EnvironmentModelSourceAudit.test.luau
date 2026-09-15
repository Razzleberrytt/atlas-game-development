--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local placementPath = "games/living-kingdoms/src/shared/Config/EnvironmentModelPlacementConfig.luau"
local worldConfigPath = "games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau"
local mathPath = "games/living-kingdoms/src/shared/Environment/EnvironmentCompositionMath.luau"
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

assert(
	placementConfig.Version == "environment-models-v4-hierarchical-packing",
	"environment model placement version changed"
)
assert(
	placementConfig.AlgorithmVersion == "gaussian-fields-hierarchical-poisson-v2",
	"composition algorithm identity changed"
)
assert(placementConfig.Seed == world.Seed, "environment composition must share the authored world seed")
assert(placementConfig.HalfExtentStuds <= world.PlayableHalfExtentStuds, "composition escaped authored world extent")
assert(placementConfig.CandidateCountPerAsset == 7000, "composition candidate budget changed")
assert(placementConfig.LandmarkPaddingStuds >= 8, "composition landmark padding is too small")
assert(
	placementConfig.CrossFamilySpacingScale >= 0.8,
	"cross-family packing scale must preserve visible footprint separation"
)
assert(#placementConfig.TierOrder == 3, "hierarchical environment composition must preserve three tiers")
assert(placementConfig.TierOrder[1] == "Anchor", "Anchor composition must run first")
assert(placementConfig.TierOrder[2] == "Mass", "Mass composition must run second")
assert(placementConfig.TierOrder[3] == "Detail", "Detail composition must run last")

local allowedAssetIds = {
	["env.rock.frontier.boulder_a"] = true,
	["env.tree.corrupted.dead_pine_a"] = true,
	["env.root.corrupted.fallen_mass_a"] = true,
	["env.root.corrupted.stump_cluster_a"] = true,
	["env.structure.industry.mine_support_a"] = true,
	["env.structure.industry.broken_support_a"] = true,
	["env.prop.industry.ore_cart_a"] = true,
	["env.camp.frontier.abandoned_fire_ring_a"] = true,
	["env.camp.frontier.torn_shelter_a"] = true,
	["env.prop.frontier.supply_crate_stack_a"] = true,
}
local allowedFields = {
	frontier = true,
	corruption = true,
	industry = true,
	camp = true,
}
local allowedTiers = {
	Anchor = true,
	Mass = true,
	Detail = true,
}
local seenAssetIds = {}
local seenPrefixes = {}
local tierCounts = {
	Anchor = 0,
	Mass = 0,
	Detail = 0,
}
local totalModelBudget = 0

assert(#placementConfig.AssetSpecs == 10, "hierarchical composition must preserve ten environment families")
for _, spec in placementConfig.AssetSpecs do
	assert(type(spec.idPrefix) == "string" and spec.idPrefix ~= "", "composition spec requires an id prefix")
	assert(not seenPrefixes[spec.idPrefix], "composition id prefixes must be unique: " .. spec.idPrefix)
	seenPrefixes[spec.idPrefix] = true
	assert(allowedAssetIds[spec.assetId], "composition uses unsupported environment asset: " .. spec.assetId)
	assert(allowedFields[spec.field], "composition uses unsupported story field: " .. spec.field)
	assert(allowedTiers[spec.tier], "composition uses unsupported hierarchy tier: " .. spec.tier)
	assert(
		not seenAssetIds[spec.assetId],
		"environment asset family duplicated in composition config: " .. spec.assetId
	)
	seenAssetIds[spec.assetId] = true
	assert(spec.count > 0, "composition family count must be positive")
	assert(spec.packingRadiusStuds >= 4, "composition family packing radius is too small")
	assert(spec.minSpacingStuds >= 28, "composition family spacing is too dense")
	assert(spec.minRouteDistanceStuds >= 26, "composition intrudes into the primary route readability lane")
	assert(spec.minCreekDistanceStuds >= 16, "composition intrudes into the creek readability lane")
	tierCounts[spec.tier] += spec.count
	totalModelBudget += spec.count
end
assert(totalModelBudget == 59, "hierarchical environment model budget changed")
assert(tierCounts.Anchor == 20, "anchor silhouette budget changed")
assert(tierCounts.Mass == 18, "mass silhouette budget changed")
assert(tierCounts.Detail == 21, "detail silhouette budget changed")

for assetId in allowedAssetIds do
	assert(seenAssetIds[assetId], "composition config is missing environment asset: " .. assetId)
end

for _, path in { mathPath, plannerPath, factoryPath, dressingPath } do
	local loaded = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})
	assert(type(loaded) == "function", "environment model source must compile: " .. path)
end

local mathSource = fs.readFile(mathPath)
local plannerSource = fs.readFile(plannerPath)
local factorySource = fs.readFile(factoryPath)
local dressingSource = fs.readFile(dressingPath)

for requiredMathToken in
	{
		"MODULUS = 2147483647",
		"MULTIPLIER = 48271",
		"local function gaussian",
		"local function polylineDistance",
		"local function minimumLandmarkClearance",
		"local function isFarEnough",
		"local function isGloballyFarEnough",
		"placementConfig.CrossFamilySpacingScale",
		"placementConfig.TierOrder",
		"placementConfig.AssetSpecs",
		"worldConfig.Dressing.TrailReflectorPositions",
		"worldConfig.EnvironmentPresentation.Water.CreekPoints",
		"function EnvironmentCompositionMath.EvaluatePoint",
		"function EnvironmentCompositionMath.Plan",
	}
do
	assert(
		string.find(mathSource, requiredMathToken, 1, true),
		"shared environment composition math is missing deterministic constraint: " .. requiredMathToken
	)
end

assert(
	string.find(
		plannerSource,
		"EnvironmentCompositionMath.Plan(WorldFoundationConfig, EnvironmentModelPlacementConfig)",
		1,
		true
	),
	"server environment planner must delegate to the shared composition kernel"
)
assert(
	not string.find(plannerSource, "MODULUS = 2147483647", 1, true),
	"server environment planner must not duplicate deterministic composition math"
)

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
	assert(string.find(factorySource, assetId, 1, true), "factory is missing a registered builder: " .. assetId)
end

assert(
	string.find(dressingSource, "EnvironmentCompositionPlanner.Plan", 1, true),
	"world dressing must instantiate the deterministic composition plan"
)
assert(
	string.find(dressingSource, 'local ENVIRONMENT_MODELS_FOLDER_NAME = "EnvironmentModels"', 1, true)
		and string.find(dressingSource, "modelsFolder.Name = ENVIRONMENT_MODELS_FOLDER_NAME", 1, true)
		and string.find(dressingSource, 'modelsFolder:SetAttribute("EnvironmentPresentationOnly", true)', 1, true),
	"world dressing must isolate generated models in a presentation-only EnvironmentModels container"
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
assert(
	string.find(dressingSource, 'model:SetAttribute("EnvironmentCompositionTier"', 1, true),
	"generated models must expose hierarchical composition tier for Studio inspection"
)
assert(
	string.find(dressingSource, 'model:SetAttribute("EnvironmentPackingRadiusStuds"', 1, true),
	"generated models must expose packing radius for Studio inspection"
)

print(
	"EnvironmentModelSourceAudit: shared math, hierarchy, packing, semantic ids, grounding, and presentation authority passed"
)
