--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "RecoveredDungeonPortalConfig assertion failed", 2)
	end
end

local function checkVector(actual: any, expected: { number }, label: string)
	check(actual ~= nil, label .. " is missing")
	for index, value in expected do
		local key = if index == 1 then "x" elseif index == 2 then "y" else "z"
		check(math.abs(actual[key] - value) <= 1e-8, string.format("%s.%s mismatch", label, key))
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredDungeonPortalConfig.luau"), {
	debugName = "RecoveredDungeonPortalConfig",
	injectGlobals = true,
})()

check(config.Version == "BA-005-DUNGEON-PORTAL-v1")
check(config.SourcePath == "Workspace/HubTown/DungeonPortal")
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.Interaction.CanonicalContentId == "portal.expedition.primary")
check(config.Interaction.CanonicalAuthority == "ExpeditionLobbyService")
check(config.Interaction.LegacyGameplayAuthority == false)
check(config.Interaction.RuntimeEnabled == false)

check(config.Evidence.IdentityRows == 10)
check(config.Evidence.PropertyBackedRows == 6)
check(config.Evidence.PendingPropertyRows == 3)
check(config.Evidence.GeneratedContainerRows == 1)
check(
	config.Evidence.PropertyBackedRows + config.Evidence.PendingPropertyRows + config.Evidence.GeneratedContainerRows
		== config.Evidence.IdentityRows
)

check(#config.Parts == 3)
check(#config.PointLights == 2)
check(#config.Attachments == 1)
check(#config.PendingPropertyNodes == 3)

local partsByName = {}
for _, definition in config.Parts do
	partsByName[definition.name] = definition
	check(definition.flags.Anchored == true)
	check(definition.flags.CanQuery == true)
	check(definition.flags.CanTouch == true)
	check(definition.flags.CastShadow == true)
	check(definition.rotationId == 2)
end

local frame = partsByName.PortalFrame
check(frame ~= nil)
check(frame.sourceId == 202)
checkVector(frame.position, { 0.0, 8.0, 22.0 }, "PortalFrame.position")
checkVector(frame.size, { 10.0, 16.0, 4.0 }, "PortalFrame.size")
check(frame.materialEnumValue == 800)
check(frame.transparency == 0.0)
check(frame.canCollide == true)
check(frame.colorBytes.r == 70 and frame.colorBytes.g == 65 and frame.colorBytes.b == 60)

local effect = partsByName.PortalEffect
check(effect ~= nil)
check(effect.sourceId == 204)
checkVector(effect.position, { 0.0, 8.0, 22.0 }, "PortalEffect.position")
checkVector(effect.size, { 8.0, 14.0, 2.0 }, "PortalEffect.size")
check(effect.materialEnumValue == 288)
check(math.abs(effect.transparency - 0.4000000059604645) <= 1e-8)
check(effect.canCollide == false)
check(effect.colorBytes.r == 100 and effect.colorBytes.g == 200 and effect.colorBytes.b == 255)

local sign = partsByName.PortalSign
check(sign ~= nil)
check(sign.sourceId == 208)
checkVector(sign.position, { 0.0, 17.0, 22.0 }, "PortalSign.position")
checkVector(sign.size, { 8.0, 2.0, 0.5 }, "PortalSign.size")
check(sign.materialEnumValue == 528)
check(sign.transparency == 0.0)
check(sign.canCollide == true)
check(sign.colorBytes.r == 80 and sign.colorBytes.g == 55 and sign.colorBytes.b == 25)

local lightsByName = {}
for _, definition in config.PointLights do
	lightsByName[definition.name] = definition
	check(definition.brightness == 3.0)
	check(definition.enabled == true)
	check(definition.shadows == false)
end

check(lightsByName.PortalGlow.sourceId == 203)
check(lightsByName.PortalGlow.parent == "PortalFrame")
check(lightsByName.PortalGlow.range == 25.0)
check(math.abs(lightsByName.PortalGlow.color.r - 0.5882353186607361) <= 1e-8)
check(math.abs(lightsByName.PortalGlow.color.g - 0.19607843458652496) <= 1e-8)
check(lightsByName.PortalGlow.color.b == 1.0)

check(lightsByName.PointLight.sourceId == 205)
check(lightsByName.PointLight.parent == "PortalEffect")
check(lightsByName.PointLight.range == 20.0)
check(math.abs(lightsByName.PointLight.color.r - 0.3921568691730499) <= 1e-8)
check(math.abs(lightsByName.PointLight.color.g - 0.7843137383460999) <= 1e-8)
check(lightsByName.PointLight.color.b == 1.0)

local attachment = config.Attachments[1]
check(attachment.name == "PortalSwirlAttach")
check(attachment.sourceId == 206)
check(attachment.parent == "PortalEffect")
check(attachment.rotationId == 2)
checkVector(attachment.position, { 0.0, 0.0, 0.0 }, "PortalSwirlAttach.position")

local pendingClasses = {}
for _, node in config.PendingPropertyNodes do
	pendingClasses[node.className] = true
	check(type(node.reason) == "string" and node.reason ~= "")
end
check(pendingClasses.ParticleEmitter == true)
check(pendingClasses.SurfaceGui == true)
check(pendingClasses.TextLabel == true)
check(pendingClasses.ProximityPrompt ~= true)
