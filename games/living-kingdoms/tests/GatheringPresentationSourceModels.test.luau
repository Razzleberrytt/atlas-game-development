--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/gathering/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "GatheringPresentationSourceModels assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local manifestSource = fs.readFile(ROOT .. "asset-manifest.json")
local manifest = serde.decode("json", manifestSource)
local gatheringContracts =
	loadModule("games/living-kingdoms/src/shared/Gathering/GatheringContracts.luau", "GatheringContracts")

check(manifest.version == "GATHERING-SOURCE-MODELS-v1")
check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(manifest.canonicalBindings == false)
check(#manifest.assets == 4)
check(gatheringContracts.RuntimeConsumptionActive == false)
check(gatheringContracts.MutationIntentAllowed == false)
check(string.find(manifestSource, "ResourceRefId", 1, true) == nil)
check(string.find(manifestSource, "RequiredToolRefId", 1, true) == nil)
check(string.find(manifestSource, "RespawnPolicyRefId", 1, true) == nil)
check(string.find(manifestSource, "RewardRefId", 1, true) == nil)
check(string.find(manifestSource, "canonicalRefId", 1, true) == nil)

local seenPresentationIds = {}
local requiredAttachments = {
	GroundSnap = true,
	GatherVfx = true,
	GatherAudio = true,
}

for _, asset in manifest.assets do
	check(type(asset.presentationId) == "string" and asset.presentationId ~= "")
	check(type(asset.modelPath) == "string" and asset.modelPath ~= "")
	check(seenPresentationIds[asset.presentationId] == nil, "duplicate gathering presentation id")
	seenPresentationIds[asset.presentationId] = true

	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	check(model.ClassName == "Model")
	local partCount = 0
	local foundAttachments = {}
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true, "gathering source Parts must be anchored")
		elseif node.ClassName == "Attachment" then
			foundAttachments[node.Name] = true
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.presentationId .. " has too few source Parts")

	for attachmentName in requiredAttachments do
		check(foundAttachments[attachmentName] == true, asset.presentationId .. " missing " .. attachmentName)
	end
end
