--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(value: unknown, message: string)
	if not value then
		error(message, 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau"), {
	debugName = "WorldFoundationConfig",
	injectGlobals = true,
})()
local controller = fs.readFile("games/living-kingdoms/src/server/LightingController.server.luau")
local builder = fs.readFile("games/living-kingdoms/src/server/EnvironmentBuilder.server.luau")
local profile = fs.readFile("games/living-kingdoms/src/server/Systems/EnvironmentProfileService.luau")

check(config.Lighting.Cycle.DurationSeconds >= 900, "day/night cycle must remain deliberately slow")
check(config.Lighting.Cycle.UpdateIntervalSeconds >= 0.25, "lighting updates must stay bounded")
check(#config.Environment.Mist.Anchors == 3, "ambient mist must stay intentionally sparse")
check(#config.Environment.AccentLights == 2, "environment pass must keep a tiny added dynamic-light budget")

check(
	string.find(controller, "EnvironmentProfileService.applyCycle", 1, true),
	"controller must drive canonical profile"
)
check(string.find(controller, "task.wait", 1, true), "controller must use scheduled task waits")

check(string.find(profile, 'Instance.new("Sky")', 1, true), "profile must create a custom Sky")
check(string.find(profile, 'Instance.new("Atmosphere")', 1, true), "profile must create Atmosphere")
check(string.find(profile, 'Instance.new("BlurEffect")', 1, true), "profile must create BlurEffect")
check(string.find(profile, 'Instance.new("ColorCorrectionEffect")', 1, true), "profile must create color grade")
check(string.find(profile, 'Instance.new("BloomEffect")', 1, true), "profile must create bloom")
check(string.find(profile, "Lighting.ColorShift_Top", 1, true), "cycle must tune upper color shift")
check(string.find(profile, "Lighting.ColorShift_Bottom", 1, true), "cycle must tune lower color shift")
check(string.find(profile, "Lighting.FogColor", 1, true), "cycle must tune fog color")
check(string.find(profile, "Lighting.FogEnd", 1, true), "cycle must tune fog depth")

check(
	string.find(builder, "WorldFoundationService.start()", 1, true),
	"builder must compose deterministic world generation"
)
check(string.find(builder, "terrain.WaterColor", 1, true), "builder must tune Terrain water")
check(string.find(builder, 'Instance.new("ParticleEmitter")', 1, true), "builder must create bounded ambient particles")
check(string.find(builder, 'Instance.new("PointLight")', 1, true), "builder must create a landmark point light")
check(string.find(builder, 'Instance.new("SpotLight")', 1, true), "builder must create a landmark spot light")
check(string.find(builder, "Enum.Material.Metal", 1, true), "builder must use real metal material")
check(string.find(builder, "Enum.Material.Glass", 1, true), "builder must use real water-surface material")

print("EnvironmentVisualOverhaulSourceAudit: sky, depth, post, water, particles, materials, accents, and cycle passed")
