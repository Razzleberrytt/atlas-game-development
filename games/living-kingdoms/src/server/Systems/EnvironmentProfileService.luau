--!strict

--[[
	Canonical runtime owner for the operation's global Lighting presentation.

	WorldFoundationService still constructs the world before this service starts,
	but once the day/night owner is active all runtime Lighting mutations flow
	through this module. Local landmark lights remain owned by their world props.
	No Sky texture is created here: asset-backed skyboxes must use a real,
	permission-verified asset instead of an invented placeholder ID.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)

local EnvironmentProfileService = {}

type RgbSpec = { r: number, g: number, b: number }

local EFFECT_NAMES = table.freeze({
	"LivingKingdomsAtmosphere",
	"LivingKingdomsColorGrade",
	"LivingKingdomsBloom",
	"LivingKingdomsSunRays",
})

local started = false

local function toColor3(spec: RgbSpec): Color3
	return Color3.fromRGB(spec.r, spec.g, spec.b)
end

local function destroyOwnedEffects()
	for _, childName in EFFECT_NAMES do
		local existing = Lighting:FindFirstChild(childName)
		if existing ~= nil then
			existing:Destroy()
		end
	end

	local existingClouds = Workspace.Terrain:FindFirstChild("LivingKingdomsClouds")
	if existingClouds ~= nil then
		existingClouds:Destroy()
	end
end

local function applyStaticLighting()
	local profile = Config.Lighting
	Lighting.GeographicLatitude = profile.GeographicLatitude
	Lighting.OutdoorAmbient = toColor3(profile.OutdoorAmbient)
	Lighting.EnvironmentDiffuseScale = profile.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = profile.EnvironmentSpecularScale
	Lighting.GlobalShadows = profile.GlobalShadows
	Lighting.ShadowSoftness = profile.ShadowSoftness
	Lighting.FogColor = toColor3(profile.FogColor)
	Lighting.FogStart = profile.FogStart
end

local function buildOwnedEffects()
	local profile = Config.Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "LivingKingdomsAtmosphere"
	atmosphere.Color = toColor3(profile.Atmosphere.Color)
	atmosphere.Decay = toColor3(profile.Atmosphere.Decay)
	atmosphere.Density = profile.Atmosphere.Density
	atmosphere.Offset = profile.Atmosphere.Offset
	atmosphere.Glare = profile.Atmosphere.Glare
	atmosphere.Haze = profile.Atmosphere.Haze
	atmosphere.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LivingKingdomsColorGrade"
	grade.Brightness = profile.ColorGrade.Brightness
	grade.Contrast = profile.ColorGrade.Contrast
	grade.Saturation = profile.ColorGrade.Saturation
	grade.TintColor = toColor3(profile.ColorGrade.TintColor)
	grade.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "LivingKingdomsBloom"
	bloom.Intensity = profile.Bloom.Intensity
	bloom.Size = profile.Bloom.Size
	bloom.Threshold = profile.Bloom.Threshold
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "LivingKingdomsSunRays"
	sunRays.Intensity = profile.SunRays.Intensity
	sunRays.Spread = profile.SunRays.Spread
	sunRays.Parent = Lighting

	local clouds = Instance.new("Clouds")
	clouds.Name = "LivingKingdomsClouds"
	clouds.Cover = profile.Clouds.Cover
	clouds.Density = profile.Clouds.Density
	clouds.Color = toColor3(profile.Clouds.Color)
	clouds.Parent = Workspace.Terrain
end

function EnvironmentProfileService.start()
	if started then
		return
	end
	started = true

	-- WorldFoundationService may have created the legacy profile during world
	-- construction. Replace only our named instances so unrelated effects survive.
	destroyOwnedEffects()
	applyStaticLighting()
	buildOwnedEffects()
end

function EnvironmentProfileService.applyDaylight(clockTime: number)
	local profile = Config.Lighting
	Lighting.ClockTime = clockTime
	Lighting.Brightness = profile.Brightness
	Lighting.ExposureCompensation = profile.ExposureCompensation
	Lighting.Ambient = toColor3(profile.Ambient)
	Lighting.FogEnd = profile.FogEnd
end

function EnvironmentProfileService.applyCorruption(clockTime: number, intensity: number, minimumFogEnd: number)
	local profile = Config.Lighting
	local night = profile.Night
	local alpha = math.clamp(intensity, 0, 1)

	Lighting.ClockTime = clockTime
	Lighting.Brightness = night.BrightnessStart + (night.BrightnessEnd - night.BrightnessStart) * alpha
	Lighting.ExposureCompensation = night.ExposureStart + (night.ExposureEnd - night.ExposureStart) * alpha
	Lighting.FogEnd = night.FogEndStart + (minimumFogEnd - night.FogEndStart) * alpha
	Lighting.Ambient = toColor3(night.AmbientStart):Lerp(toColor3(night.AmbientEnd), alpha)
end

function EnvironmentProfileService.stop()
	if not started then
		return
	end
	started = false
	destroyOwnedEffects()
end

return table.freeze(EnvironmentProfileService)
