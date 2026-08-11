--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/crafting/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "CraftingPresentationSourceModels assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local manifest = serde.decode("json", fs.readFile(ROOT .. "asset-manifest.json"))
local registry = loadModule(
	"games/living-kingdoms/src/shared/Config/CraftingPresentationRegistry.luau",
	"CraftingPresentationRegistry"
)
local craftingContracts = loadModule(
	"games/living-kingdoms/src/shared/Crafting/CraftingContracts.luau",
	"CraftingContracts"
)

check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(#manifest.assets == 5)
check(registry.Version == "CRAFTING-PRESENTATION-v2")
check(craftingContracts.RuntimeConsumptionActive == false)
check(craftingContracts.MutationIntentAllowed == false)

local byId = {}
for _, definition in registry.Definitions do
	check(byId[definition.presentationId] == nil, "duplicate crafting presentation id: " .. definition.presentationId)
	byId[definition.presentationId] = definition
end

local requiredAttachments = {
	["crafting.presentation.station.field_bench_v1"] = {
		IngredientLeft = true,
		IngredientRight = true,
		OutputCenter = true,
		ToolMain = true,
		WorkVfx = true,
		WorkAudio = true,
	},
	["crafting.presentation.tool.hand_tools_v1"] = { WorkbenchSnap = true },
	["crafting.presentation.container.parts_crate_v1"] = { FloorSnap = true },
}

for _, asset in manifest.assets do
	local definition = byId[asset.presentationId]
	check(definition ~= nil, "registry missing crafting presentation " .. asset.presentationId)
	check(definition.modelPath == asset.registryModelPath)
	check(definition.status == "HeldSourceModel")
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)

	if asset.presentationId == "crafting.presentation.station.field_bench_v1" then
		check(definition.canonicalRefId == "station.hub.crafting")
	else
		check(definition.canonicalRefId == nil, asset.presentationId .. " must remain gameplay-unbound")
	end

	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	check(model.ClassName == "Model")
	local partCount = 0
	local foundAttachments = {}
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true, "crafting source Parts must be anchored")
		elseif node.ClassName == "Attachment" then
			foundAttachments[node.Name] = true
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.presentationId .. " has too few source Parts")

	for attachmentName in requiredAttachments[asset.presentationId] or {} do
		check(foundAttachments[attachmentName] == true, asset.presentationId .. " missing " .. attachmentName)
	end
end
