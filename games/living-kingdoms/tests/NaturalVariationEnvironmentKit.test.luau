--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/world/environment-kits/natural-variation/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "NaturalVariationEnvironmentKit assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local contracts = loadModule(
	"games/living-kingdoms/src/shared/World/EnvironmentAssetKitContracts.luau",
	"EnvironmentAssetKitContracts"
)
local wave7 = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistryWave7.luau",
	"EnvironmentAssetKitRegistryWave7"
)
local manifest = serde.decode("json", fs.readFile(ROOT .. "asset-manifest.json"))

check(wave7.Version == "ENV-ASSET-KIT-WAVE7-v1")
check(#wave7.Definitions == 4)
check(contracts.isValid(wave7.Definitions))
check(#manifest.assets == 4)
check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)

local byId = {}
for _, definition in wave7.Definitions do
	byId[definition.id] = definition
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)
end

for _, asset in manifest.assets do
	local definition = byId[asset.semanticId]
	check(definition ~= nil, "wave7 registry missing " .. asset.semanticId)
	check(definition.sourceModelPath == asset.registrySourceModelPath)
	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	local partCount = 0
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true)
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount)
end
