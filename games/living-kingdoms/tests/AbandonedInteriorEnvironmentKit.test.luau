--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/world/environment-kits/abandoned-interiors/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "AbandonedInteriorEnvironmentKit assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local contracts = loadModule(
	"games/living-kingdoms/src/shared/World/EnvironmentAssetKitContracts.luau",
	"EnvironmentAssetKitContracts"
)
local base = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistry.luau",
	"EnvironmentAssetKitRegistry"
)
local wave2 = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistryWave2.luau",
	"EnvironmentAssetKitRegistryWave2"
)
local wave3 = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistryWave3.luau",
	"EnvironmentAssetKitRegistryWave3"
)
local wave4 = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistryWave4.luau",
	"EnvironmentAssetKitRegistryWave4"
)
local wave5 = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistryWave5.luau",
	"EnvironmentAssetKitRegistryWave5"
)
local manifest = serde.decode("json", fs.readFile(ROOT .. "asset-manifest.json"))

check(wave5.Version == "ENV-ASSET-KIT-WAVE5-v1")
check(#wave5.Definitions == 4)
check(#manifest.assets == 4)
check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)

local combined = {}
for _, registry in { base, wave2, wave3, wave4, wave5 } do
	for _, definition in registry.Definitions do
		table.insert(combined, definition)
	end
end
check(contracts.isValid(combined), "environment registry waves 1-5 must compose")

local byId = {}
for _, definition in wave5.Definitions do
	byId[definition.id] = definition
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)
	check(definition.family == "Prop")
end

local socketCount = 0
for _, asset in manifest.assets do
	local definition = byId[asset.semanticId]
	check(definition ~= nil, "wave5 registry missing " .. asset.semanticId)
	check(definition.sourceModelPath == asset.registrySourceModelPath)
	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	check(model.ClassName == "Model")
	local partCount = 0
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true, "interior Parts must be anchored")
		end
		if node.ClassName == "Attachment" then
			socketCount += 1
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.semanticId .. " has too few source Parts")
end
check(socketCount >= 2, "interior kit must preserve presentation prop sockets")
