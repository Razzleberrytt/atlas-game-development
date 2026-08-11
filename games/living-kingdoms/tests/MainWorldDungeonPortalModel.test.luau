--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldDungeonPortalModel assertion failed", 2)
	end
end

local function near(actual: number, expected: number, label: string)
	check(math.abs(actual - expected) <= 1e-8, label .. " mismatch")
end

local function loadConfig(name: string)
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/" .. name .. ".luau"), {
		debugName = name,
		injectGlobals = true,
	})()
end

local function flatten(node: any, path: string, output: { any })
	table.insert(output, { path = path, node = node })
	for _, child in node.Children or {} do
		local childPath = if path == "" then child.Name else path .. "/" .. child.Name
		flatten(child, childPath, output)
	end
end

local config = loadConfig("RecoveredDungeonPortalConfig")
local model = serde.decode(
	"json",
	fs.readFile("games/living-kingdoms/assets/recovered-world/models/DungeonPortal.model.json")
)
local rows = {}
flatten(model, "", rows)
local byPath = {}
for _, row in rows do
	byPath[row.path] = row.node
end

check(model.ClassName == "Folder")
check(#rows == config.Evidence.IdentityRows)
check(#rows == 10)
check(config.RuntimeEnabled == false)
check(config.Interaction.RuntimeEnabled == false)
check(config.Interaction.CanonicalAuthority == "ExpeditionLobbyService")
check(config.Interaction.LegacyGameplayAuthority == false)

for _, definition in config.Parts do
	local node = byPath[definition.name]
	check(node ~= nil and node.ClassName == "Part", definition.name .. " missing")
	local properties = node.Properties
	near(properties.CFrame[1], definition.position.x, definition.name .. ".x")
	near(properties.CFrame[2], definition.position.y, definition.name .. ".y")
	near(properties.CFrame[3], definition.position.z, definition.name .. ".z")
	near(properties.Size[1], definition.size.x, definition.name .. ".size.x")
	near(properties.Size[2], definition.size.y, definition.name .. ".size.y")
	near(properties.Size[3], definition.size.z, definition.name .. ".size.z")
	check(properties.Anchored == definition.flags.Anchored)
	check(properties.CanCollide == definition.canCollide)
	check(properties.CanQuery == definition.flags.CanQuery)
	check(properties.CanTouch == definition.flags.CanTouch)
	check(properties.CastShadow == definition.flags.CastShadow)
	check(properties.Material.Enum == definition.materialEnumValue)
	check(properties.Shape.Enum == definition.shapeEnumValue)
	near(properties.Color[1], definition.colorBytes.r / 255, definition.name .. ".Color.r")
	near(properties.Color[2], definition.colorBytes.g / 255, definition.name .. ".Color.g")
	near(properties.Color[3], definition.colorBytes.b / 255, definition.name .. ".Color.b")
	near(properties.Transparency, definition.transparency, definition.name .. ".Transparency")
	near(properties.Reflectance, definition.reflectance, definition.name .. ".Reflectance")
end

for _, definition in config.PointLights do
	local node = byPath[definition.parent .. "/" .. definition.name]
	check(node ~= nil and node.ClassName == "PointLight")
	near(node.Properties.Brightness, definition.brightness, definition.name .. ".Brightness")
	near(node.Properties.Color[1], definition.color.r, definition.name .. ".Color.r")
	near(node.Properties.Color[2], definition.color.g, definition.name .. ".Color.g")
	near(node.Properties.Color[3], definition.color.b, definition.name .. ".Color.b")
	near(node.Properties.Range, definition.range, definition.name .. ".Range")
	check(node.Properties.Enabled == definition.enabled)
	check(node.Properties.Shadows == definition.shadows)
end

local attachment = config.Attachments[1]
local attachmentNode = byPath[attachment.parent .. "/" .. attachment.name]
check(attachmentNode ~= nil and attachmentNode.ClassName == "Attachment")
near(attachmentNode.Properties.CFrame[1], attachment.position.x, "attachment.x")
near(attachmentNode.Properties.CFrame[2], attachment.position.y, "attachment.y")
near(attachmentNode.Properties.CFrame[3], attachment.position.z, "attachment.z")

local emitter = config.ParticleEmitters[1]
local emitterNode = byPath["PortalEffect/PortalSwirlAttach/" .. emitter.name]
check(emitterNode ~= nil and emitterNode.ClassName == "ParticleEmitter")
local ep = emitterNode.Properties
near(ep.Acceleration[2], emitter.acceleration.y, "emitter acceleration")
near(ep.Rate, emitter.rate, "emitter rate")
check(ep.Texture == emitter.texture)
near(ep.Speed.NumberRange[1], emitter.speed.min, "emitter speed min")
near(ep.Speed.NumberRange[2], emitter.speed.max, "emitter speed max")
near(ep.Lifetime.NumberRange[1], emitter.lifetime.min, "emitter lifetime min")
near(ep.Lifetime.NumberRange[2], emitter.lifetime.max, "emitter lifetime max")
check(#ep.Color.ColorSequence.keypoints == #emitter.colorSequence)
check(#ep.Size.NumberSequence.keypoints == #emitter.sizeSequence)
check(#ep.Transparency.NumberSequence.keypoints == #emitter.transparencySequence)

local gui = config.SurfaceGuis[1]
local guiNode = byPath[gui.parent .. "/" .. gui.name]
check(guiNode ~= nil and guiNode.ClassName == "SurfaceGui")
check(guiNode.Properties.Enabled == gui.enabled)
check(guiNode.Properties.Face.Enum == gui.faceEnumValue)
near(guiNode.Properties.CanvasSize[1], gui.canvasSize.x, "gui canvas x")
near(guiNode.Properties.CanvasSize[2], gui.canvasSize.y, "gui canvas y")

local label = config.TextLabels[1]
local labelNode = byPath["PortalSign/SurfaceGui/" .. label.name]
check(labelNode ~= nil and labelNode.ClassName == "TextLabel")
check(labelNode.Properties.Text == label.text)
check(labelNode.Properties.TextScaled == label.textScaled)
check(labelNode.Properties.TextWrapped == label.textWrapped)
check(labelNode.Properties.TextXAlignment.Enum == label.textXAlignmentEnumValue)
check(labelNode.Properties.TextYAlignment.Enum == label.textYAlignmentEnumValue)
check(labelNode.Properties.FontFace == nil)
check(config.Evidence.KnownVisualPropertyOmissions == 1)
check(config.KnownVisualPropertyOmissions[1].propertyName == "FontFace")

local project = serde.decode("json", fs.readFile("games/living-kingdoms/main-world.project.json"))
check(
	project.tree.Workspace.LivingKingdomsMainWorld.HubCore.ExpeditionGate.DungeonPortal["$path"]
		== "assets/recovered-world/models/DungeonPortal.model.json"
)
check(project.placeId == nil and project.gameId == nil and project.servePlaceIds == nil)
