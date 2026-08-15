--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local placementPath = "games/living-kingdoms/src/shared/Config/EnvironmentModelPlacementConfig.luau"
local factoryPath = "games/living-kingdoms/src/server/EnvironmentModelFactory.luau"
local dressingPath = "games/living-kingdoms/src/server/WorldVisualDressing.server.luau"

local placements = luau.load(fs.readFile(placementPath), {
	debugName = "EnvironmentModelPlacementConfig",
	injectGlobals = true,
})()
local factorySource = fs.readFile(factoryPath)
local dressingSource = fs.readFile(dressingPath)

assert(placements.Version == "environment-models-v1", "environment model placement version changed unexpectedly")
assert(#placements.Placements == 10, "environment dressing budget must remain at ten hero placements")

local allowedAssetIds = {
	["env.rock.frontier.boulder_a"] = true,
	["env.tree.corrupted.dead_pine_a"] = true,
	["env.structure.industry.mine_support_a"] = true,
	["env.camp.frontier.abandoned_fire_ring_a"] = true,
}
local placementIds = {}
for _, placement in placements.Placements do
	assert(type(placement.id) == "string" and placement.id ~= "", "environment placement requires a stable id")
	assert(not placementIds[placement.id], "environment placement ids must be unique: " .. placement.id)
	placementIds[placement.id] = true
	assert(allowedAssetIds[placement.assetId], "environment placement uses an unsupported starter asset: " .. placement.assetId)
end

assert(string.find(factorySource, "EnvironmentAssetKitRegistry", 1, true), "factory must resolve semantic asset registry ids")
assert(string.find(factorySource, "part.Anchored = true", 1, true), "environment model parts must stay anchored")
assert(string.find(factorySource, "part.CanCollide = false", 1, true), "presentation models must not own collision")
assert(string.find(factorySource, "part.CanTouch = false", 1, true), "presentation models must not own touch authority")
assert(string.find(factorySource, "part.CanQuery = false", 1, true), "presentation models must not affect gameplay queries")
assert(string.find(factorySource, 'model:SetAttribute("EnvironmentPresentationOnly", true)', 1, true), "models must declare presentation-only ownership")
assert(not string.find(factorySource, 'Instance.new("PointLight")', 1, true), "environment models must not add dynamic PointLights")
assert(not string.find(factorySource, 'Instance.new("SpotLight")', 1, true), "environment models must not add dynamic SpotLights")
assert(not string.find(factorySource, 'Instance.new("Script")', 1, true), "environment models must not add per-prop scripts")

for assetId in allowedAssetIds do
	assert(string.find(factorySource, assetId, 1, true), "factory is missing a registered starter builder: " .. assetId)
end

assert(string.find(dressingSource, "EnvironmentModelFactory.Build", 1, true), "world dressing must instantiate model placements")
assert(string.find(dressingSource, 'modelsFolder.Name = "EnvironmentModels"', 1, true), "world dressing must isolate environment models")
assert(string.find(dressingSource, "EnvironmentModelPlacementConfig.Placements", 1, true), "world dressing must remain data-driven")

print("EnvironmentModelSourceAudit: semantic ids, ten-placement budget, and presentation-only authority passed")
