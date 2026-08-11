--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/world/environment-kits/ground-clutter-wave4/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "GroundClutterWave4 assertion failed", 2)
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

check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(#manifest.assets == 4)
check(wave4Registry.Version == "ENV-ASSET-KIT-WAVE4-v1")
check(#wave4Registry.Definitions == 4)

local combined = {}
for _, definition in baseRegistry.Definitions do
	table.insert(combined, definition)
end
for _, definition in wave2Registry.Definitions do
	table.insert(combined, definition)
end
for _, definition in wave3Registry.Definitions do
	table.insert(combined, definition)
end
for _, definition in wave4Registry.Definitions do
	table.insert(combined, definition)
end
check(contracts.isValid(combined), "base + wave-2 + wave-3 + wave-4 environment definitions must compose")

local byId = {}
for _, definition in combined do
	check(byId[definition.id] == nil, "duplicate environment semantic id: " .. definition.id)
	byId[definition.id] = definition
end

local tendrilVfxSocket = false
for _, asset in manifest.assets do
	local definition = byId[asset.semanticId]
	check(definition ~= nil, "registry missing ground clutter asset " .. asset.semanticId)
	check(definition.sourceModelPath == asset.registrySourceModelPath)
	check(definition.family == "GroundClutter")
	check(definition.collisionPolicy == "None")
	check(definition.streamingGroupId == "main_world.resources")
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)

	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	check(model.ClassName == "Model")
	local partCount = 0
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		check(node.ClassName ~= "ProximityPrompt" and node.ClassName ~= "ClickDetector")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true, "ground clutter Parts must be anchored")
			check(node.Properties.CanCollide == false, "dense ground clutter must remain non-colliding")
		end
		if asset.semanticId == "env.clutter.corruption.tendril_mat_a" and node.Name == "VfxSocket" then
			tendrilVfxSocket = node.ClassName == "Attachment"
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.semanticId .. " has too few source Parts")
end

check(tendrilVfxSocket, "corruption tendril mat must preserve its VFX presentation socket")
