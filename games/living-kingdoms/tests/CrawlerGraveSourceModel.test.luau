--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/enemy/crawler-grave-v1/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "CrawlerGraveSourceModel assertion failed", 2)
	end
end

local manifest = serde.decode("json", fs.readFile(ROOT .. "asset-manifest.json"))
local model = serde.decode("json", fs.readFile(ROOT .. "CrawlerGraveV1.model.json"))
local registry =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyHorrorPresentationRegistry.luau"), {
		debugName = "EnemyHorrorPresentationRegistry",
		injectGlobals = true,
	})()

local crawler = nil
for _, definition in registry.Definitions do
	if definition.presentationId == manifest.assetKey then
		crawler = definition
		break
	end
end
check(crawler ~= nil, "Crawler Grave manifest must bind the horror presentation registry")
check(crawler.modelPath == manifest.registryModelPath)
check(crawler.silhouetteClass == "LowPredator")
check(crawler.locomotionClass == "Crawl")
check(crawler.presentationOnly == true)
check(crawler.gameplayAuthorityOwnerId == nil)
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
	check(parts[name] == true, "Crawler Grave missing defining part: " .. name)
end
for _, name in manifest.requiredAttachments do
	check(attachments[name] == true, "Crawler Grave missing presentation attachment: " .. name)
end
for _, silhouetteClaim in manifest.silhouetteClaims do
	local found = false
	for _, tag in crawler.horrorTags do
		if tag == silhouetteClaim then
			found = true
			break
		end
	end
	check(found, "source silhouette claim drifted from registry: " .. silhouetteClaim)
end
