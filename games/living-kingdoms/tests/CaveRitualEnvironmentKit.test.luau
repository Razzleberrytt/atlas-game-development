--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/world/environment-kits/cave-ritual/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "CaveRitualEnvironmentKit assertion failed", 2)
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
local contracts = loadModule(
	"games/living-kingdoms/src/shared/World/EnvironmentAssetKitContracts.luau",
	"EnvironmentAssetKitContracts"
)

check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(#manifest.assets == 4)
check(wave3Registry.Version == "ENV-ASSET-KIT-WAVE3-v1")
check(#wave3Registry.Definitions == 4)

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
check(contracts.isValid(combined), "base + wave-2 + wave-3 environment definitions must compose")

local byId = {}
for _, definition in combined do
	check(byId[definition.id] == nil, "duplicate environment semantic id: " .. definition.id)
	byId[definition.id] = definition
end

local expectedAttachments = {
	["env.cave.ritual.rib_arch_a"] = { LeftSnap = true, RightSnap = true },
	["env.structure.ritual.stone_altar_a"] = { OfferingSocket = true, RuneVfxSocket = true },
	["env.structure.ritual.runic_pillar_a"] = { RuneVfxSocket = true, HumAudioSocket = true },
	["env.prop.ritual.offering_brazier_a"] = { EmberVfxSocket = true, FireAudioSocket = true },
}

for _, asset in manifest.assets do
	local definition = byId[asset.semanticId]
	check(definition ~= nil, "registry missing cave ritual asset " .. asset.semanticId)
	check(definition.sourceModelPath == asset.registrySourceModelPath)
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)

	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	check(model.ClassName == "Model")
	local partCount = 0
	local foundAttachments = {}
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true, "environment Parts must be anchored")
		elseif node.ClassName == "Attachment" then
			foundAttachments[node.Name] = true
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.semanticId .. " has too few source Parts")

	for attachmentName in expectedAttachments[asset.semanticId] or {} do
		check(foundAttachments[attachmentName] == true, asset.semanticId .. " missing " .. attachmentName)
	end
end
