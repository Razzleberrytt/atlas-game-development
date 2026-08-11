--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/world/environment-kits/industrial-rail-debris/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "IndustrialRailDebrisEnvironmentKit assertion failed", 2)
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
local contracts = loadModule(
	"games/living-kingdoms/src/shared/World/EnvironmentAssetKitContracts.luau",
	"EnvironmentAssetKitContracts"
)

check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(#manifest.assets == 4)
check(wave2Registry.Version == "ENV-ASSET-KIT-WAVE2-v1")
check(#wave2Registry.Definitions == 4)

local combined = {}
for _, definition in baseRegistry.Definitions do
	table.insert(combined, definition)
end
for _, definition in wave2Registry.Definitions do
	table.insert(combined, definition)
end
check(contracts.isValid(combined), "base + wave-2 environment definitions must compose under canonical contracts")

local byId = {}
for _, definition in combined do
	check(byId[definition.id] == nil, "duplicate environment semantic id: " .. definition.id)
	byId[definition.id] = definition
end

local signalHasVfxSocket = false
for _, asset in manifest.assets do
	local definition = byId[asset.semanticId]
	check(definition ~= nil, "registry missing industrial asset " .. asset.semanticId)
	check(definition.sourceModelPath == asset.registrySourceModelPath)
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)

	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	check(model.ClassName == "Model")
	local partCount = 0
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true, "environment Parts must be anchored")
		end
		if asset.semanticId == "env.prop.industry.signal_post_a" and node.Name == "VfxSocket" then
			signalHasVfxSocket = node.ClassName == "Attachment"
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.semanticId .. " has too few source Parts")
end

check(signalHasVfxSocket, "signal post must preserve its VFX presentation socket")
