--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "Dungeon Portal current-revision parity assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredDungeonPortalConfig.luau"), {
	debugName = "RecoveredDungeonPortalConfig",
	injectGlobals = true,
})()

local evidence = serde.decode("json", fs.readFile("games/living-kingdoms/imports/studio-2026-08-10/hub-civic-geometry-summary.json"))
check(evidence.source.sha256 == "7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b")
check(evidence.source.bytes == 1808699)
check(evidence.runtime_enabled == false)

local portal = nil
for _, unit in evidence.units do
	if unit.source_path == "Workspace/HubTown/DungeonPortal" then
		portal = unit
		break
	end
end
check(portal ~= nil, "current authored revision is missing DungeonPortal evidence")
check(portal.instance_count == 10)
check(portal.classes.Folder == 1)
check(portal.classes.Part == 3)
check(portal.classes.PointLight == 2)
check(portal.classes.Attachment == 1)
check(portal.classes.ParticleEmitter == 1)
check(portal.classes.SurfaceGui == 1)
check(portal.classes.TextLabel == 1)

local configParts = {}
for _, part in config.Parts do
	configParts[part.name] = part
end
for _, part in portal.parts do
	local held = configParts[part.path]
	check(held ~= nil, "missing held part: " .. part.path)
	check(held.position.x == part.position[1] and held.position.y == part.position[2] and held.position.z == part.position[3], part.path .. " position drift")
	check(held.size.x == part.size[1] and held.size.y == part.size[2] and held.size.z == part.size[3], part.path .. " size drift")
	check(held.colorBytes.r == part.color_bytes[1] and held.colorBytes.g == part.color_bytes[2] and held.colorBytes.b == part.color_bytes[3], part.path .. " color drift")
	check(held.materialEnumValue == part.material, part.path .. " material drift")
	check(held.shapeEnumValue == part.shape, part.path .. " shape drift")
	check(held.canCollide == part.can_collide, part.path .. " collision drift")
	check(held.transparency == part.transparency, part.path .. " transparency drift")
	check(held.reflectance == part.reflectance, part.path .. " reflectance drift")
	check(held.rotationId == part.rotation_id, part.path .. " rotation drift")
end

local configLights = {}
for _, light in config.PointLights do
	configLights[light.parent .. "/" .. light.name] = light
end
for _, light in portal.lights do
	local held = configLights[light.path]
	check(held ~= nil, "missing held light: " .. light.path)
	check(held.parent == light.parent, light.path .. " parent drift")
	check(held.brightness == light.brightness, light.path .. " brightness drift")
	check(held.color.r == light.color[1] and held.color.g == light.color[2] and held.color.b == light.color[3], light.path .. " color drift")
	check(held.enabled == light.enabled, light.path .. " enabled drift")
	check(held.range == light.range, light.path .. " range drift")
	check(held.shadows == light.shadows, light.path .. " shadow drift")
end

check(#portal.attachments == 1)
local attachment = portal.attachments[1]
check(attachment.path == "PortalEffect/PortalSwirlAttach")
check(config.Attachments[1].name == "PortalSwirlAttach")
check(config.Attachments[1].parent == "PortalEffect")
check(config.Attachments[1].position.x == attachment.position[1] and config.Attachments[1].position.y == attachment.position[2] and config.Attachments[1].position.z == attachment.position[3])
check(config.Attachments[1].rotationId == attachment.rotation_id)

local identity = {}
for _, row in portal.identity_only do
	identity[row.path] = row.class
end
check(identity["PortalEffect/PortalSwirlAttach/PortalSwirl"] == "ParticleEmitter")
check(identity["PortalSign/SurfaceGui"] == "SurfaceGui")
check(identity["PortalSign/SurfaceGui/TextLabel"] == "TextLabel")

-- The current revision's bounded evidence intentionally does not supersede the
-- richer historical presentation properties. It proves the supported geometry,
-- lights, attachment, and remaining identity graph stayed aligned while the
-- canonical expedition authority remains repository-owned and the recovered
-- portal remains dormant.
check(config.SourceHold == true)
check(config.RuntimeEnabled == false)
check(config.Interaction.CanonicalAuthority == "ExpeditionLobbyService")
check(config.Interaction.LegacyGameplayAuthority == false)
check(config.Interaction.RuntimeEnabled == false)
