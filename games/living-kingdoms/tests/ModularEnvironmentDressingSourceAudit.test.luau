--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local configPath = "games/living-kingdoms/src/shared/Config/ModularEnvironmentDressingConfig.luau"
local catalogPath = "games/living-kingdoms/src/shared/Config/ModularAssetProductionCatalog.luau"
local sourcePath = "games/living-kingdoms/src/server/ModularEnvironmentDressing.server.luau"

local function loadPure(path: string): any
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})()
end

local config = loadPure(configPath)
local catalog = loadPure(catalogPath)
local source = fs.readFile(sourcePath)

assert(config.Version == "modular-field-dressing-v1", "modular environment dressing version changed")
assert(config.FolderName == "ModularFieldProps", "modular environment dressing folder identity changed")
assert(config.MaximumPropCount == 18, "secondary environment prop budget changed")
assert(config.MinimumOffsetStuds >= 7, "secondary props are too close to hero silhouettes")
assert(config.MaximumOffsetStuds <= 11, "secondary props can drift too far from accepted hero anchors")
assert(config.MinimumOffsetStuds < config.MaximumOffsetStuds, "secondary prop offset range is invalid")
assert(config.GeneratedAssetWaitSeconds <= 8, "modular prop readiness wait is too long")

local catalogPropIds = {}
for _, definition in catalog.Props.Categories do
	catalogPropIds[definition.id] = true
end

local expectedFields = {
	frontier = true,
	corruption = true,
	industry = true,
	camp = true,
}
local total = 0
for field, fieldSpec in config.FieldSpecs do
	assert(expectedFields[field], "modular environment dressing uses an unknown story field: " .. field)
	assert(fieldSpec.count > 0, "modular environment field requires a positive prop count: " .. field)
	total += fieldSpec.count
	for _, assetId in fieldSpec.assetIds do
		assert(catalogPropIds[assetId], "modular environment dressing uses an uncataloged prop: " .. assetId)
	end
end
assert(total == config.MaximumPropCount, "modular environment field counts exceed the owned prop budget")

for field in expectedFields do
	assert(config.FieldSpecs[field] ~= nil, "modular environment dressing is missing story field: " .. field)
end

for _, required in
	{
		"ModularAssetResolver.CloneByAssetId",
		"ModularAssetResolver.GetGeneratedRoot",
		"ModularAssetResolver.FindByAssetId",
		"EnvironmentModels",
		"EnvironmentField",
		"TerrainFoundation",
		"Workspace:Raycast",
		"HASH_MODULUS = 2147483647",
		"HASH_MULTIPLIER = 131",
		"Workspace:GetServerTimeNow() + Config.GeneratedAssetWaitSeconds",
		"task.wait(ASSET_READY_POLL_SECONDS)",
		"descendant.CanCollide = false",
		"descendant.CanTouch = false",
		"descendant.CanQuery = false",
		"instance.CanCollide = false",
		"instance.CanTouch = false",
		"instance.CanQuery = false",
		'descendant:IsA("ProximityPrompt")',
		'descendant:IsA("ClickDetector")',
		'output:SetAttribute("EnvironmentPresentationOnly", true)',
		'output:SetAttribute("EnvironmentPropBudget", Config.MaximumPropCount)',
		'worldRoot:SetAttribute("ModularEnvironmentDressingVersion", Config.Version)',
	}
do
	assert(string.find(source, required, 1, true), "modular environment dressing is missing contract: " .. required)
end

for _, forbidden in
	{
		"math.random",
		"Random.new",
		"RunService.Heartbeat",
		"while true",
		'Instance.new("PointLight")',
		'Instance.new("SpotLight")',
		'Instance.new("Script")',
	}
do
	assert(
		not string.find(source, forbidden, 1, true),
		"modular environment dressing contains forbidden behavior: " .. forbidden
	)
end

print(
	"ModularEnvironmentDressingSourceAudit: catalog binding, readiness, 18-prop budget, grounding, and query isolation passed"
)
