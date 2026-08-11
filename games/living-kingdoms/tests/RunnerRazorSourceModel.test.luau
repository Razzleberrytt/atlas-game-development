--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/enemy/runner-razor-v1/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RunnerRazorSourceModel assertion failed", 2)
	end
end

local manifest = serde.decode("json", fs.readFile(ROOT .. "asset-manifest.json"))
local model = serde.decode("json", fs.readFile(ROOT .. "RunnerRazorV1.model.json"))
local registry =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyHorrorPresentationRegistry.luau"), {
		debugName = "EnemyHorrorPresentationRegistry",
		injectGlobals = true,
	})()

local definition = nil
for _, candidate in registry.Definitions do
	if candidate.presentationId == manifest.assetKey then
		definition = candidate
		break
	end
end
check(definition ~= nil, "Runner Razor manifest must bind the horror presentation registry")
check(definition.modelPath == manifest.registryModelPath)
check(definition.silhouetteClass == "RazorSprinter")
check(definition.locomotionClass == "Sprint")
check(definition.presentationOnly == true)
check(definition.gameplayAuthorityOwnerId == nil)
check(model.ClassName == "Model")
check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)

local parts = {}
local attachments = {}
local partCount = 0
local function visit(node)
	check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
	check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
	if node.ClassName == "Part" then
		partCount += 1
		parts[node.Name] = true
		check(
			node.Properties ~= nil and node.Properties.Anchored == true,
			"held horror blockout Parts must be anchored"
		)
	end
	if node.ClassName == "Attachment" then
		attachments[node.Name] = true
	end
	for _, child in node.Children or {} do
		visit(child)
	end
end
visit(model)

check(partCount >= manifest.minimumPartCount)
for _, name in manifest.requiredParts do
	check(parts[name] == true, "Runner Razor missing defining part: " .. name)
end
for _, name in manifest.requiredAttachments do
	check(attachments[name] == true, "Runner Razor missing presentation attachment: " .. name)
end
for _, silhouetteClaim in manifest.silhouetteClaims do
	local found = false
	for _, tag in definition.horrorTags do
		if tag == silhouetteClaim then
			found = true
			break
		end
	end
	check(found, "source silhouette claim drifted from registry: " .. silhouetteClaim)
end
