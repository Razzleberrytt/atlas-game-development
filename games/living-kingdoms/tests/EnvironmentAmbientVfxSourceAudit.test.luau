--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local configPath = "games/living-kingdoms/src/shared/Config/EnvironmentAmbientVfxConfig.luau"
local worldConfigPath = "games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau"
local builderPath = "games/living-kingdoms/src/server/EnvironmentBuilder.server.luau"

local function loadPureConfig(path)
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = {},
		injectGlobals = true,
	})()
end

local config = loadPureConfig(configPath)
local world = loadPureConfig(worldConfigPath)

assert(config.Version == "biome-vfx-v1", "ambient VFX version changed")
assert(config.Texture == "rbxasset://textures/particles/smoke_main.dds", "ambient VFX must use an engine-shipped texture")
assert(#config.Zones == 8, "ambient VFX anchor budget changed")

local allowedKinds = {
	CreekVapor = true,
	RoadDust = true,
	ForestMotes = true,
	CorruptionAsh = true,
}
local kindCounts = {
	CreekVapor = 0,
	RoadDust = 0,
	ForestMotes = 0,
	CorruptionAsh = 0,
}
local seenIds = {}
local maximumExpectedLiveParticles = 0

for _, zone in config.Zones do
	assert(type(zone.id) == "string" and zone.id ~= "", "ambient VFX zone id is required")
	assert(not seenIds[zone.id], "ambient VFX zone ids must be unique: " .. zone.id)
	seenIds[zone.id] = true
	assert(allowedKinds[zone.kind], "unsupported ambient VFX kind: " .. tostring(zone.kind))
	kindCounts[zone.kind] += 1
	assert(math.abs(zone.x) <= world.PlayableHalfExtentStuds, "ambient VFX escaped authored x extent")
	assert(math.abs(zone.z) <= world.PlayableHalfExtentStuds, "ambient VFX escaped authored z extent")
	assert(zone.rate > 0 and zone.rate <= 0.75, "ambient VFX rate exceeded bounded budget")
	assert(zone.lifetimeMin > 0 and zone.lifetimeMax <= 8, "ambient VFX lifetime exceeded bounded budget")
	assert(zone.lifetimeMin <= zone.lifetimeMax, "ambient VFX lifetime bounds are reversed")
	assert(zone.speedMin >= 0 and zone.speedMax <= 0.8, "ambient VFX speed exceeded subtle-motion budget")
	assert(zone.speedMin <= zone.speedMax, "ambient VFX speed bounds are reversed")
	assert(zone.sizeStart > 0 and zone.sizeEnd <= 5, "ambient VFX size exceeded readability budget")
	assert(zone.lightEmission >= 0 and zone.lightEmission <= 0.05, "ambient VFX may not fake strong light")
	assert(zone.lightInfluence >= 0.75 and zone.lightInfluence <= 1, "ambient VFX must remain environment-lit")
	maximumExpectedLiveParticles += zone.rate * zone.lifetimeMax
end

for kind, count in kindCounts do
	assert(count == 2, "ambient VFX kind must keep two bounded anchors: " .. kind)
end
assert(maximumExpectedLiveParticles <= 32, "ambient VFX expected live-particle budget is too high")

local loadedBuilder = luau.load(fs.readFile(builderPath), {
	debugName = builderPath,
	environment = {},
	injectGlobals = true,
})
assert(type(loadedBuilder) == "function", "EnvironmentBuilder source must compile")

local builderSource = fs.readFile(builderPath)
assert(string.find(builderSource, "EnvironmentAmbientVfxConfig", 1, true), "environment builder must load ambient VFX config")
assert(string.find(builderSource, 'AMBIENT_VFX_FOLDER_NAME = "BiomeAmbientVfx"', 1, true), "ambient VFX folder identity is missing")
assert(string.find(builderSource, 'Instance.new("ParticleEmitter")', 1, true), "ambient VFX emitters are missing")
assert(string.find(builderSource, 'anchor:SetAttribute("EnvironmentVfxZone"', 1, true), "ambient VFX zones need Studio-inspectable identity")
assert(string.find(builderSource, "anchor.CanCollide = false", 1, true), "ambient VFX anchors must not affect collision")
assert(string.find(builderSource, "anchor.CanTouch = false", 1, true), "ambient VFX anchors must not affect touch authority")
assert(string.find(builderSource, "anchor.CanQuery = false", 1, true), "ambient VFX anchors must not affect gameplay queries")
assert(not string.find(builderSource, 'Instance.new("PointLight")', 1, true), "ambient VFX must add zero dynamic lights")
assert(not string.find(builderSource, 'Instance.new("SpotLight")', 1, true), "ambient VFX must add zero dynamic lights")
assert(not string.find(builderSource, "RunService", 1, true), "ambient VFX must not add a recurring update loop")
assert(not string.find(builderSource, "RemoteEvent", 1, true), "ambient VFX must not add a network authority surface")

print("EnvironmentAmbientVfxSourceAudit: biome identity, particle budgets, and presentation authority passed")
