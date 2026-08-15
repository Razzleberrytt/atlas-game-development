--!strict

local fs = require("@lune/fs")

local function check(value: unknown, message: string)
	if not value then
		error(message, 2)
	end
end

local config = fs.readFile("games/living-kingdoms/src/shared/Config/EnvironmentVisualConfig.luau")
local controller = fs.readFile("games/living-kingdoms/src/server/LightingController.server.luau")
local profile = fs.readFile("games/living-kingdoms/src/server/Systems/EnvironmentProfileService.luau")
local builder = fs.readFile("games/living-kingdoms/src/server/EnvironmentBuilder.server.luau")

check(string.find(config, "Seconds = 1800", 1, true), "visual cycle must stay slow")
check(string.find(config, "SkyboxBk", 1, true), "visual config must define a real sky cubemap")
check(string.find(config, "Water = table.freeze", 1, true), "visual config must define themed water")
check(string.find(config, "BoundaryRidges", 1, true), "visual config must define terrain silhouette")
check(string.find(controller, "task.wait", 1, true), "lighting cadence must yield")
check(string.find(controller, "EnvironmentProfileService.applyClock", 1, true), "controller must delegate rendering")
check(string.find(profile, 'Instance.new("Sky")', 1, true), "profile must create Sky")
check(string.find(profile, 'Instance.new("Atmosphere")', 1, true), "profile must create Atmosphere")
check(string.find(profile, 'Instance.new("BlurEffect")', 1, true), "profile must create BlurEffect")
check(string.find(profile, 'Instance.new("ColorCorrectionEffect")', 1, true), "profile must create color grade")
check(string.find(profile, 'Instance.new("BloomEffect")', 1, true), "profile must create BloomEffect")
check(string.find(profile, "Lighting.Ambient", 1, true), "profile must own Ambient")
check(string.find(profile, "Lighting.OutdoorAmbient", 1, true), "profile must own OutdoorAmbient")
check(string.find(profile, "Lighting.ColorShift_Top", 1, true), "profile must own top color shift")
check(string.find(profile, "Lighting.ColorShift_Bottom", 1, true), "profile must own bottom color shift")
check(string.find(profile, "Lighting.FogColor", 1, true), "profile must own fog color")
check(string.find(profile, "Lighting.FogEnd", 1, true), "profile must own fog depth")
check(string.find(builder, "Terrain:SetMaterialColor", 1, true), "builder must assign terrain materials")
check(string.find(builder, "Enum.Material.Water", 1, true), "builder must create Terrain water")
check(string.find(builder, 'Instance.new("ParticleEmitter")', 1, true), "builder must add ambience particles")
check(string.find(builder, 'Instance.new("PointLight")', 1, true), "builder must add PointLight accents")
check(string.find(builder, 'Instance.new("SpotLight")', 1, true), "builder must add SpotLight accents")
check(string.find(builder, "WorldFoundationService.start()", 1, true), "builder must preserve authored landmarks")

print("EnvironmentVisualSourceAudit: sky, atmosphere, post, terrain, water, ambience, accents, and cycle passed")
