--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/world/environment-kits/dense-ground-clutter/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "DenseGroundClutterEnvironmentKit assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local manifest = serde.decode("json", fs.readFile(ROOT .. "asset-manifest.json"))
local baseRegistry = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistry.luau",
	"EnvironmentAssetKitRegistry"
)
local wave2Registry = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistryWave2.luau",
	"EnvironmentAssetKitRegistryWave2"
)
local wave3Registry = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistryWave3.luau",
	"EnvironmentAssetKitRegistryWave3"
)
local wave4Registry = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistryWave4.luau",
	"EnvironmentAssetKitRegistryWave4"
)
local contracts = loadModule(
	"games/living-kingdoms/src/shared/World/EnvironmentAssetKitContracts.luau",
	"EnvironmentAssetKitContracts"
)
local gatheringContracts =
	loadModule("games/living-kingdoms/src/shared/Gathering/GatheringContracts.luau", "GatheringContracts")

check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(#manifest.assets == 4)
check(wave4Registry.Version == "ENV-ASSET-KIT-WAVE4-v1")
check(#wave4Registry.Definitions == 4)
check(gatheringContracts.RuntimeConsumptionActive == false)
check(gatheringContracts.MutationIntentAllowed == false)

local combined = {}
for _, registry in { baseRegistry, wave2Registry, wave3Registry, wave4Registry } do
	for _, definition in registry.Definitions do
		table.insert(combined, definition)
	end
end
check(contracts.isValid(combined), "environment registry waves 1-4 must compose under canonical contracts")

local byId = {}
for _, definition in combined do
	check(byId[definition.id] == nil, "duplicate environment semantic id: " .. definition.id)
	byId[definition.id] = definition
end

for _, asset in manifest.assets do
	local definition = byId[asset.semanticId]
	check(definition ~= nil, "registry missing dense clutter asset " .. asset.semanticId)
	check(definition.sourceModelPath == asset.registrySourceModelPath)
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)
	check(definition.collisionPolicy == "None")

	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	check(model.ClassName == "Model")
	local partCount = 0
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true, "environment Parts must be anchored")
			check(node.Properties.CanCollide == false, "dense ground clutter must remain non-colliding")
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.semanticId .. " has too few source Parts")
end
