--!strict

--[[
	Canonical runtime owner for the operation's global Lighting presentation.

	WorldFoundationService owns static world geometry. This module owns the global
	image: Lighting, Sky, Atmosphere, post-processing, clouds, and the visual side
	of the corruption-driven day/night transition. Local landmark lights remain
	owned by their world props.

	Studio preview support is deliberately implemented here so visual acceptance
	can inspect the same production profile without enabling the live corruption
	cycle or introducing a second Lighting owner.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)

local EnvironmentProfileService = {}

type RgbSpec = { r: number, g: number, b: number }

local EFFECT_NAMES = table.freeze({
	"LivingKingdomsSky",
	"LivingKingdomsAtmosphere",
	"LivingKingdomsColorGrade",
	"LivingKingdomsBloom",
	"LivingKingdomsBlur",
	"LivingKingdomsSunRays",
})

local started = false
local studioPreviewActive = false
local atmosphere: Atmosphere? = nil
local grade: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local blur: BlurEffect? = nil
local sunRays: SunRaysEffect? = nil
local clouds: Clouds? = nil

local function toColor3(spec: RgbSpec): Color3
	return Color3.fromRGB(spec.r, spec.g, spec.b)
end

local function lerpNumber(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
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

	atmosphere = nil
	grade = nil
	bloom = nil
	blur = nil
	sunRays = nil
	clouds = nil
end

local function applyStaticLighting()
	local profile = Config.Lighting
	Lighting.GeographicLatitude = profile.GeographicLatitude
	Lighting.OutdoorAmbient = toColor3(profile.OutdoorAmbient)
	Lighting.ColorShift_Top = toColor3(profile.ColorShiftTop)
	Lighting.ColorShift_Bottom = toColor3(profile.ColorShiftBottom)
	Lighting.EnvironmentDiffuseScale = profile.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = profile.EnvironmentSpecularScale
	Lighting.GlobalShadows = profile.GlobalShadows
	Lighting.ShadowSoftness = profile.ShadowSoftness
	Lighting.FogColor = toColor3(profile.FogColor)
	Lighting.FogStart = profile.FogStart
end

local function buildOwnedEffects()
	local profile = Config.Lighting
	local skyProfile = profile.Sky

	local sky = Instance.new("Sky")
	sky.Name = "LivingKingdomsSky"
	sky.SkyboxBk = skyProfile.SkyboxBk
	sky.SkyboxDn = skyProfile.SkyboxDn
	sky.SkyboxFt = skyProfile.SkyboxFt
	sky.SkyboxLf = skyProfile.SkyboxLf
	sky.SkyboxRt = skyProfile.SkyboxRt
	sky.SkyboxUp = skyProfile.SkyboxUp
	sky.CelestialBodiesShown = skyProfile.CelestialBodiesShown
	sky.StarCount = skyProfile.StarCount
	sky.SunAngularSize = skyProfile.SunAngularSize
	sky.MoonAngularSize = skyProfile.MoonAngularSize
	sky.Parent = Lighting

	local atmosphereInstance = Instance.new("Atmosphere")
	atmosphereInstance.Name = "LivingKingdomsAtmosphere"
	atmosphereInstance.Parent = Lighting
	atmosphere = atmosphereInstance

	local gradeInstance = Instance.new("ColorCorrectionEffect")
	gradeInstance.Name = "LivingKingdomsColorGrade"
	gradeInstance.Parent = Lighting
	grade = gradeInstance

	local bloomInstance = Instance.new("BloomEffect")
	bloomInstance.Name = "LivingKingdomsBloom"
	bloomInstance.Size = profile.Bloom.Size
	bloomInstance.Parent = Lighting
	bloom = bloomInstance

	local blurInstance = Instance.new("BlurEffect")
	blurInstance.Name = "LivingKingdomsBlur"
	blurInstance.Parent = Lighting
	blur = blurInstance

	local sunRaysInstance = Instance.new("SunRaysEffect")
	sunRaysInstance.Name = "LivingKingdomsSunRays"
	sunRaysInstance.Spread = profile.SunRays.Spread
	sunRaysInstance.Parent = Lighting
	sunRays = sunRaysInstance

	local cloudsInstance = Instance.new("Clouds")
	cloudsInstance.Name = "LivingKingdomsClouds"
	cloudsInstance.Parent = Workspace.Terrain
	clouds = cloudsInstance
end

local function applyDayVisuals(clockTime: number)
	local profile = Config.Lighting
	Lighting.ClockTime = clockTime
	Lighting.Brightness = profile.Brightness
	Lighting.ExposureCompensation = profile.ExposureCompensation
	Lighting.Ambient = toColor3(profile.Ambient)
	Lighting.OutdoorAmbient = toColor3(profile.OutdoorAmbient)
	Lighting.ColorShift_Top = toColor3(profile.ColorShiftTop)
	Lighting.ColorShift_Bottom = toColor3(profile.ColorShiftBottom)
	Lighting.FogColor = toColor3(profile.FogColor)
	Lighting.FogEnd = profile.FogEnd

	local atmosphereInstance = atmosphere
	if atmosphereInstance ~= nil then
		atmosphereInstance.Color = toColor3(profile.Atmosphere.Color)
		atmosphereInstance.Decay = toColor3(profile.Atmosphere.Decay)
		atmosphereInstance.Density = profile.Atmosphere.Density
		atmosphereInstance.Offset = profile.Atmosphere.Offset
		atmosphereInstance.Glare = profile.Atmosphere.Glare
		atmosphereInstance.Haze = profile.Atmosphere.Haze
	end

	local gradeInstance = grade
	if gradeInstance ~= nil then
		gradeInstance.Brightness = profile.ColorGrade.Brightness
		gradeInstance.Contrast = profile.ColorGrade.Contrast
		gradeInstance.Saturation = profile.ColorGrade.Saturation
		gradeInstance.TintColor = toColor3(profile.ColorGrade.TintColor)
	end

	local bloomInstance = bloom
	if bloomInstance ~= nil then
		bloomInstance.Intensity = profile.Bloom.Intensity
		bloomInstance.Threshold = profile.Bloom.Threshold
	end

	local blurInstance = blur
	if blurInstance ~= nil then
		blurInstance.Size = profile.Blur.Size
	end

	local sunRaysInstance = sunRays
	if sunRaysInstance ~= nil then
		sunRaysInstance.Intensity = profile.SunRays.Intensity
	end

	local cloudsInstance = clouds
	if cloudsInstance ~= nil then
		cloudsInstance.Cover = profile.Clouds.Cover
		cloudsInstance.Density = profile.Clouds.Density
		cloudsInstance.Color = toColor3(profile.Clouds.Color)
	end
end

local function applyCorruptionVisuals(clockTime: number, intensity: number, minimumFogEnd: number)
	local profile = Config.Lighting
	local night = profile.Night
	local alpha = math.clamp(intensity, 0, 1)
	local eased = alpha * alpha * (3 - 2 * alpha)

	Lighting.ClockTime = clockTime
	Lighting.Brightness = lerpNumber(profile.Brightness, night.BrightnessEnd, eased)
	Lighting.ExposureCompensation = lerpNumber(profile.ExposureCompensation, night.ExposureEnd, eased)
	Lighting.FogEnd = lerpNumber(profile.FogEnd, minimumFogEnd, eased)
	Lighting.Ambient = toColor3(profile.Ambient):Lerp(toColor3(night.AmbientEnd), eased)
	Lighting.OutdoorAmbient = toColor3(profile.OutdoorAmbient):Lerp(toColor3(night.OutdoorAmbientEnd), eased)
	Lighting.ColorShift_Top = toColor3(profile.ColorShiftTop):Lerp(toColor3(night.ColorShiftTopEnd), eased)
	Lighting.ColorShift_Bottom = toColor3(profile.ColorShiftBottom):Lerp(toColor3(night.ColorShiftBottomEnd), eased)
	Lighting.FogColor = toColor3(profile.FogColor):Lerp(toColor3(night.FogColorEnd), eased)

	local atmosphereInstance = atmosphere
	if atmosphereInstance ~= nil then
		atmosphereInstance.Color = toColor3(profile.Atmosphere.Color):Lerp(toColor3(night.AtmosphereColorEnd), eased)
		atmosphereInstance.Decay = toColor3(profile.Atmosphere.Decay):Lerp(toColor3(night.AtmosphereDecayEnd), eased)
		atmosphereInstance.Density = lerpNumber(profile.Atmosphere.Density, night.AtmosphereDensityEnd, eased)
		atmosphereInstance.Offset = lerpNumber(profile.Atmosphere.Offset, night.AtmosphereOffsetEnd, eased)
		atmosphereInstance.Glare = lerpNumber(profile.Atmosphere.Glare, night.AtmosphereGlareEnd, eased)
		atmosphereInstance.Haze = lerpNumber(profile.Atmosphere.Haze, night.AtmosphereHazeEnd, eased)
	end

	local gradeInstance = grade
	if gradeInstance ~= nil then
		gradeInstance.Brightness = lerpNumber(profile.ColorGrade.Brightness, night.GradeBrightnessEnd, eased)
		gradeInstance.Contrast = lerpNumber(profile.ColorGrade.Contrast, night.GradeContrastEnd, eased)
		gradeInstance.Saturation = lerpNumber(profile.ColorGrade.Saturation, night.GradeSaturationEnd, eased)
		gradeInstance.TintColor = toColor3(profile.ColorGrade.TintColor):Lerp(toColor3(night.GradeTintEnd), eased)
	end

	local bloomInstance = bloom
	if bloomInstance ~= nil then
		bloomInstance.Intensity = lerpNumber(profile.Bloom.Intensity, night.BloomIntensityEnd, eased)
		bloomInstance.Threshold = lerpNumber(profile.Bloom.Threshold, night.BloomThresholdEnd, eased)
	end

	local blurInstance = blur
	if blurInstance ~= nil then
		blurInstance.Size = lerpNumber(profile.Blur.Size, night.BlurSizeEnd, eased)
	end

	local sunRaysInstance = sunRays
	if sunRaysInstance ~= nil then
		sunRaysInstance.Intensity = lerpNumber(profile.SunRays.Intensity, night.SunRaysIntensityEnd, eased)
	end

	local cloudsInstance = clouds
	if cloudsInstance ~= nil then
		cloudsInstance.Cover = lerpNumber(profile.Clouds.Cover, night.CloudCoverEnd, eased)
		cloudsInstance.Density = lerpNumber(profile.Clouds.Density, night.CloudDensityEnd, eased)
		cloudsInstance.Color = toColor3(profile.Clouds.Color):Lerp(toColor3(night.CloudColorEnd), eased)
	end
end

function EnvironmentProfileService.start()
	if started then
		return
	end
	started = true

	-- Replace only instances owned by this profile so unrelated place effects
	-- survive. Engine-shipped sky textures avoid unverified marketplace assets.
	destroyOwnedEffects()
	applyStaticLighting()
	buildOwnedEffects()
	applyDayVisuals(Config.Lighting.ClockTime)
end

function EnvironmentProfileService.applyDaylight(clockTime: number)
	if studioPreviewActive then
		return
	end
	applyDayVisuals(clockTime)
end

function EnvironmentProfileService.applyCorruption(clockTime: number, intensity: number, minimumFogEnd: number)
	if studioPreviewActive then
		return
	end
	applyCorruptionVisuals(clockTime, intensity, minimumFogEnd)
end

function EnvironmentProfileService.setStudioPreview(clockTime: number, intensity: number, minimumFogEnd: number): boolean
	if not RunService:IsStudio() then
		return false
	end
	if not started then
		EnvironmentProfileService.start()
	end
	studioPreviewActive = true
	applyCorruptionVisuals(clockTime, intensity, minimumFogEnd)
	return true
end

function EnvironmentProfileService.clearStudioPreview(): boolean
	if not RunService:IsStudio() then
		return false
	end
	studioPreviewActive = false
	if started then
		applyDayVisuals(Config.Lighting.ClockTime)
	end
	return true
end

function EnvironmentProfileService.stop()
	if not started then
		return
	end
	started = false
	studioPreviewActive = false
	destroyOwnedEffects()
end

return table.freeze(EnvironmentProfileService)
