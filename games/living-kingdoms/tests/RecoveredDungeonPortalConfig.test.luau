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

check(config.Version == "BA-005-DUNGEON-PORTAL-v2")
check(config.SourcePath == "Workspace/HubTown/DungeonPortal")
check(config.CoordinateSpaceId == "authored-overworld")
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.Interaction.CanonicalContentId == "portal.expedition.primary")
check(config.Interaction.CanonicalAuthority == "ExpeditionLobbyService")
check(config.Interaction.LegacyGameplayAuthority == false)
check(config.Interaction.RecoveredTextIsPresentationOnly == true)
check(config.Interaction.RuntimeEnabled == false)

check(config.Evidence.IdentityRows == 10)
check(config.Evidence.PropertyBackedRows == 9)
check(config.Evidence.GeneratedContainerRows == 1)
check(config.Evidence.PendingNodeRows == 0)
check(config.Evidence.KnownVisualPropertyOmissions == 1)
check(config.Evidence.PropertyBackedRows + config.Evidence.GeneratedContainerRows == config.Evidence.IdentityRows)

check(#config.Parts == 3)
check(#config.PointLights == 2)
check(#config.Attachments == 1)
check(#config.SurfaceGuis == 1)
check(#config.TextLabels == 1)
check(#config.ParticleEmitters == 1)
check(#config.KnownVisualPropertyOmissions == 1)

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

local surface = config.SurfaceGuis[1]
check(surface.sourceId == 209)
check(surface.parent == "PortalSign")
check(surface.active == true)
check(surface.enabled == true)
check(surface.canvasSize.x == 800.0 and surface.canvasSize.y == 600.0)
check(surface.faceEnumValue == 5)
check(surface.pixelsPerStud == 50.0)
check(surface.alwaysOnTop == false)

local label = config.TextLabels[1]
check(label.sourceId == 210)
check(label.parent == "SurfaceGui")
check(label.text == "ENTER THE DEPTHS\n[G] to enter dungeon")
check(label.textScaled == true)
check(label.textWrapped == true)
check(label.visible == true)
check(label.backgroundTransparency == 1.0)
check(label.position.x.scale == 0.0 and label.position.x.offset == 0)
check(label.position.y.scale == 0.0 and label.position.y.offset == 0)
check(label.size.x.scale == 1.0 and label.size.x.offset == 0)
check(label.size.y.scale == 1.0 and label.size.y.offset == 0)
check(label.textXAlignmentEnumValue == 2)
check(label.textYAlignmentEnumValue == 1)

local emitter = config.ParticleEmitters[1]
check(emitter.sourceId == 207)
check(emitter.parent == "PortalSwirlAttach")
check(emitter.texture == "rbxassetid://241876674")
check(emitter.rate == 40.0)
check(emitter.enabled == true)
check(emitter.lifetime.min == 2.0 and emitter.lifetime.max == 3.0)
check(emitter.speed.min == 1.0 and emitter.speed.max == 3.0)
check(emitter.spreadAngle.x == 360.0 and emitter.spreadAngle.y == 360.0)
check(emitter.acceleration.x == 0.0 and emitter.acceleration.y == 2.0 and emitter.acceleration.z == 0.0)
check(#emitter.colorSequence == 2)
check(#emitter.sizeSequence == 3)
check(#emitter.transparencySequence == 3)
check(emitter.sizeSequence[2].time == 0.5 and emitter.sizeSequence[2].value == 2.0)
check(math.abs(emitter.transparencySequence[2].value - 0.20000000298023224) <= 1e-8)

local omission = config.KnownVisualPropertyOmissions[1]
check(omission.className == "TextLabel")
check(omission.propertyName == "FontFace")
check(omission.typeId == 0x20)
check(type(omission.reason) == "string" and omission.reason ~= "")
