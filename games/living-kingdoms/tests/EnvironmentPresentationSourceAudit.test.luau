local fs = require("@lune/fs")
local luau = require("@lune/luau")

local configSource = fs.readFile("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau")
local config = luau.load(configSource, {
	debugName = "WorldFoundationConfig",
	environment = {},
	injectGlobals = true,
})()

local profilePath = "games/living-kingdoms/src/server/Systems/EnvironmentProfileService.luau"
local builderPath = "games/living-kingdoms/src/server/EnvironmentBuilder.server.luau"
local profileSource = fs.readFile(profilePath)
local builderSource = fs.readFile(builderPath)

for _, path in { profilePath, builderPath } do
	local loaded = luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})
	assert(type(loaded) == "function", "environment source must compile: " .. path)
end

local lighting = config.Lighting
local sky = lighting.Sky
for _, face in {
	sky.SkyboxBk,
	sky.SkyboxDn,
	sky.SkyboxFt,
	sky.SkyboxLf,
	sky.SkyboxRt,
	sky.SkyboxUp,
} do
	assert(string.find(face, "rbxasset://textures/sky/", 1, true) == 1, "sky must use engine-shipped textures")
end
assert(sky.StarCount <= 2000, "sky star budget is too high")
assert(lighting.Blur.Size <= 1, "daylight blur must stay restrained")
assert(lighting.Night.BlurSizeEnd <= 2, "night blur must preserve combat readability")
assert(lighting.Night.AtmosphereDensityEnd < 0.4, "deep-night atmosphere must preserve silhouettes")
assert(lighting.Night.CloudCoverEnd < 0.7, "deep-night cloud cover must remain bounded")

local presentation = config.EnvironmentPresentation
assert(presentation.Version == "ambience-v2", "physical ambience version changed")
assert(#presentation.Mist.Locations == 4, "mist emitter budget changed")
assert(presentation.Mist.Rate <= 1.5, "mist particle rate exceeded the mobile-safe budget")
assert(presentation.Mist.LifetimeMax <= 12, "mist particle lifetime exceeded the bounded budget")
assert(#presentation.Water.CreekPoints == 7, "creek control-point contract changed")
assert(presentation.Water.CreekWidth <= 18, "creek water stamp is too broad")
assert(presentation.Water.CreekDepth <= 3, "creek water stamp is too deep")

assert(string.find(profileSource, 'Instance.new("Sky")', 1, true), "global sky owner is missing")
assert(string.find(profileSource, 'Instance.new("BlurEffect")', 1, true), "global blur owner is missing")
assert(string.find(profileSource, "Lighting.ColorShift_Top", 1, true), "top color shift is missing")
assert(string.find(profileSource, "Lighting.ColorShift_Bottom", 1, true), "bottom color shift is missing")
assert(string.find(profileSource, "AtmosphereColorEnd", 1, true), "night atmosphere interpolation is missing")
assert(string.find(profileSource, "CloudColorEnd", 1, true), "night cloud interpolation is missing")
assert(string.find(profileSource, "alpha * alpha * (3 - 2 * alpha)", 1, true), "night transition must remain eased")

assert(string.find(builderSource, "Terrain:FillBlock", 1, true), "real Terrain water stamp is missing")
assert(string.find(builderSource, "Enum.Material.Water", 1, true), "Terrain water material is missing")
assert(string.find(builderSource, 'Instance.new("ParticleEmitter")', 1, true), "ground mist emitter is missing")
assert(string.find(builderSource, "CanCollide = false", 1, true), "mist anchors must not affect collision")
assert(string.find(builderSource, "CanQuery = false", 1, true), "mist anchors must not affect gameplay queries")
assert(
	not string.find(builderSource, 'Instance.new("PointLight")', 1, true),
	"physical ambience layer must not add dynamic lights"
)
assert(not string.find(builderSource, "RunService", 1, true), "physical ambience must not add a recurring server loop")

print("EnvironmentPresentationSourceAudit: sky, night depth, creek water, and mist budgets passed")
