--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/world/environment-kits/abandoned-mine/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "AbandonedMineEnvironmentKit assertion failed", 2)
	end
end

local function decodeJson(path: string)
	return serde.decode("json", fs.readFile(path))
end

local registry = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistry.luau"), {
	debugName = "EnvironmentAssetKitRegistry",
	injectGlobals = true,
})()

local registryById = {}
for _, definition in registry.Definitions do
	registryById[definition.id] = definition
end

local manifest = decodeJson(ROOT .. "asset-manifest.json")
check(manifest.assetKey == "world.environment-kit.abandoned-mine")
check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(#manifest.assets == 4)

local function visit(node, state)
	check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
	check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
	if node.ClassName == "Part" then
		state.partCount += 1
		check(node.Properties ~= nil and node.Properties.Anchored == true, "source kit Parts must be anchored")
	end
	if node.ClassName == "Attachment" then
		state.attachments[node.Name] = true
	end
	for _, child in node.Children or {} do
		visit(child, state)
	end
end

for _, asset in manifest.assets do
	local definition = registryById[asset.semanticId]
	check(definition ~= nil, "manifest asset must exist in EnvironmentAssetKitRegistry: " .. asset.semanticId)
	check(definition.sourceModelPath == asset.registrySourceModelPath, "manifest/registry source path drift")
	check(string.find(asset.file, "..", 1, true) == nil, "asset file may not escape kit root")
	local model = decodeJson(ROOT .. asset.file)
	check(model.ClassName == "Model", "environment source file must decode to a Model")
	local state = { partCount = 0, attachments = {} }
	visit(model, state)
	check(state.partCount >= asset.minimumPartCount, "source model lost required geometry: " .. asset.semanticId)
	if asset.semanticId == "env.structure.industry.mine_support_a" then
		for _, socket in definition.sockets do
			check(state.attachments[socket.id] == true, "MineSupportA missing registry socket: " .. socket.id)
		end
	end
end
