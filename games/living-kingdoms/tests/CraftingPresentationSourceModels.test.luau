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
local contracts = loadModule(
	"games/living-kingdoms/src/shared/Crafting/CraftingContracts.luau",
	"CraftingContracts"
)

check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(#manifest.assets == 5)
check(registry.Version == "CRAFTING-PRESENTATION-v1")
check(contracts.RuntimeConsumptionActive == false, "crafting runtime consumption must remain dormant")
check(contracts.MutationIntentAllowed == false, "source models cannot authorize crafting mutation")

local byPresentationId = {}
for _, definition in registry.Definitions do
	check(byPresentationId[definition.presentationId] == nil, "duplicate crafting presentation id")
	byPresentationId[definition.presentationId] = definition
end

local requiredSockets = {
	["crafting.presentation.station.field_bench_v1"] = {
		["socket.ingredient.left"] = "IngredientDisplay",
		["socket.ingredient.right"] = "IngredientDisplay",
		["socket.output.center"] = "OutputDisplay",
		["socket.tool.main"] = "ToolRest",
		["socket.vfx.work"] = "VFX",
		["socket.audio.work"] = "Audio",
	},
	["crafting.presentation.tool.hand_tools_v1"] = {
		["socket.snap.workbench"] = "Snap",
	},
	["crafting.presentation.container.parts_crate_v1"] = {
		["socket.snap.floor"] = "Snap",
	},
}

for _, asset in manifest.assets do
	local definition = byPresentationId[asset.presentationId]
	check(definition ~= nil, "registry missing crafting asset " .. asset.presentationId)
	check(definition.modelPath == asset.registryModelPath, "model path mismatch for " .. asset.presentationId)
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)
	if asset.presentationId == "crafting.presentation.station.field_bench_v1" then
		check(definition.canonicalRefId == "station.hub.crafting")
		check(asset.canonicalRefId == "station.hub.crafting")
	else
		check(definition.canonicalRefId == nil, asset.presentationId .. " must not invent a gameplay ref")
	end

	local declaredSockets = {}
	for _, socket in definition.sockets do
		declaredSockets[socket.id] = socket.kind
	end
	local expectedSockets = requiredSockets[asset.presentationId] or {}
	for socketId, socketKind in expectedSockets do
		check(declaredSockets[socketId] == socketKind, "registry socket mismatch: " .. socketId)
	end

	local model = serde.decode("json", fs.readFile(ROOT .. asset.file))
	check(model.ClassName == "Model")
	local partCount = 0
	local foundSockets = {}
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		check(node.ClassName ~= "ProximityPrompt" and node.ClassName ~= "ClickDetector")
		if node.ClassName == "Part" then
			partCount += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true, "crafting Parts must be anchored")
		end
		if expectedSockets[node.Name] ~= nil then
			check(node.ClassName == "Attachment", "presentation socket must be an Attachment: " .. node.Name)
			foundSockets[node.Name] = true
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(partCount >= asset.minimumPartCount, asset.presentationId .. " has too few source Parts")
	for socketId in expectedSockets do
		check(foundSockets[socketId] == true, "source model missing registry socket " .. socketId)
	end
end
