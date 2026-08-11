--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/world/environment-kits/corruption-growth/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "CorruptionGrowthEnvironmentKit assertion failed", 2)
	end
end

local manifest = serde.decode("json", fs.readFile(ROOT .. "asset-manifest.json"))
local registry =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistry.luau"), {
		debugName = "EnvironmentAssetKitRegistry",
		injectGlobals = true,
	})()

check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(#manifest.assets == 4)

local byId = {}
for _, definition in registry.Definitions do
	byId[definition.id] = definition
end

local resinHasVfxSocket = false
local sporeHasVfxSocket = false
local sporeHasAudioSocket = false
for _, asset in manifest.assets do
	local definition = byId[asset.semanticId]
	check(definition ~= nil, "registry missing corruption growth asset " .. asset.semanticId)
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
		if asset.semanticId == "env.growth.corruption.resin_cluster_a" and node.Name == "VfxSocket" then
			resinHasVfxSocket = node.ClassName == "Attachment"
		end
		if asset.semanticId == "env.growth.corruption.spore_lantern_a" and node.Name == "SporeVfxSocket" then
			sporeHasVfxSocket = node.ClassName == "Attachment"
		end
		if asset.semanticId == "env.growth.corruption.spore_lantern_a" and node.Name == "AudioSocket" then
			sporeHasAudioSocket = node.ClassName == "Attachment"
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.semanticId .. " has too few source Parts")
end

check(resinHasVfxSocket, "resin cluster must preserve its VFX presentation socket")
check(sporeHasVfxSocket, "spore lantern must preserve its VFX presentation socket")
check(sporeHasAudioSocket, "spore lantern must preserve its audio presentation socket")
