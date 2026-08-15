--!strict

--[[
	Canonical runtime owner for the operation's global Lighting presentation.
	The day/night controller supplies time and daylight weight; this module owns
	the actual Lighting, atmosphere, sky, clouds, and post-processing mutations.
	Local landmark lights remain owned by the environment builder/world props.
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
	"LivingKingdomsDepthBlur",
	"LivingKingdomsSunRays",
	"LivingKingdomsSky",
})

local started = false
local atmosphere: Atmosphere? = nil
local grade: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local blur: BlurEffect? = nil
local sunRays: SunRaysEffect? = nil
local sky: Sky? = nil
local clouds: Clouds? = nil

local function toColor3(spec: RgbSpec): Color3
	return Color3.fromRGB(spec.r, spec.g, spec.b)
end

local function lerpNumber(fromValue: number, toValue: number, alpha: number): number
	return fromValue + (toValue - fromValue) * alpha
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
	sky = nil
	clouds = nil
end

local function applyStaticLighting()
	local profile = Config.Lighting
	Lighting.GeographicLatitude = profile.GeographicLatitude
	Lighting.EnvironmentDiffuseScale = profile.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = profile.EnvironmentSpecularScale
	Lighting.GlobalShadows = profile.GlobalShadows
	Lighting.ShadowSoftness = profile.ShadowSoftness
end

local function buildOwnedEffects()
	local profile = Config.Lighting
	local day = profile.Day
	local skyProfile = profile.Sky

	local newAtmosphere = Instance.new("Atmosphere")
	newAtmosphere.Name = "LivingKingdomsAtmosphere"
	newAtmosphere.Color = toColor3(day.Atmosphere.Color)
	newAtmosphere.Decay = toColor3(day.Atmosphere.Decay)
	newAtmosphere.Density = day.Atmosphere.Density
	newAtmosphere.Offset = day.Atmosphere.Offset
	newAtmosphere.Glare = day.Atmosphere.Glare
	newAtmosphere.Haze = day.Atmosphere.Haze
	newAtmosphere.Parent = Lighting
	atmosphere = newAtmosphere

	local newGrade = Instance.new("ColorCorrectionEffect")
	newGrade.Name = "LivingKingdomsColorGrade"
	newGrade.Brightness = day.ColorGrade.Brightness
	newGrade.Contrast = day.ColorGrade.Contrast
	newGrade.Saturation = day.ColorGrade.Saturation
	newGrade.TintColor = toColor3(day.ColorGrade.TintColor)
	newGrade.Parent = Lighting
	grade = newGrade

	local newBloom = Instance.new("BloomEffect")
	newBloom.Name = "LivingKingdomsBloom"
	newBloom.Intensity = day.Bloom.Intensity
	newBloom.Size = day.Bloom.Size
	newBloom.Threshold = day.Bloom.Threshold
	newBloom.Parent = Lighting
	bloom = newBloom

	local newBlur = Instance.new("BlurEffect")
	newBlur.Name = "LivingKingdomsDepthBlur"
	newBlur.Size = day.BlurSize
	newBlur.Parent = Lighting
	blur = newBlur

	local newSunRays = Instance.new("SunRaysEffect")
	newSunRays.Name = "LivingKingdomsSunRays"
	newSunRays.Intensity = day.SunRaysIntensity
	newSunRays.Spread = profile.SunRaysSpread
	newSunRays.Parent = Lighting
	sunRays = newSunRays

	local newSky = Instance.new("Sky")
	newSky.Name = "LivingKingdomsSky"
	newSky.SkyboxBk = skyProfile.SkyboxBk
	newSky.SkyboxDn = skyProfile.SkyboxDn
	newSky.SkyboxFt = skyProfile.SkyboxFt
	newSky.SkyboxLf = skyProfile.SkyboxLf
	newSky.SkyboxRt = skyProfile.SkyboxRt
	newSky.SkyboxUp = skyProfile.SkyboxUp
	newSky.CelestialBodiesShown = skyProfile.CelestialBodiesShown
	newSky.StarCount = 0
	newSky.SunAngularSize = skyProfile.SunAngularSize
	newSky.MoonAngularSize = skyProfile.MoonAngularSize
	newSky.Parent = Lighting
	sky = newSky

	local newClouds = Instance.new("Clouds")
	newClouds.Name = "LivingKingdomsClouds"
	newClouds.Cover = day.Clouds.Cover
	newClouds.Density = day.Clouds.Density
	newClouds.Color = toColor3(day.Clouds.Color)
	newClouds.Parent = Workspace.Terrain
	clouds = newClouds
end

function EnvironmentProfileService.start()
	if started then
		return
	end
	started = true

	-- WorldFoundationService may have created the older named profile during
	-- synchronous world construction. Replace only owned presentation instances.
	destroyOwnedEffects()
	applyStaticLighting()
	buildOwnedEffects()
end

function EnvironmentProfileService.applyCycle(clockTime: number, daylightAlpha: number, threatIntensity: number)
	if not started then
		return
	end

	local currentAtmosphere = atmosphere
	local currentGrade = grade
	local currentBloom = bloom
	local currentBlur = blur
	local currentSunRays = sunRays
	local currentSky = sky
	local currentClouds = clouds
	if
		currentAtmosphere == nil
		or currentGrade == nil
		or currentBloom == nil
		or currentBlur == nil
		or currentSunRays == nil
		or currentSky == nil
		or currentClouds == nil
	then
		return
	end

	local profile = Config.Lighting
	local day = profile.Day
	local night = profile.Night
	local daylight = math.clamp(daylightAlpha, 0, 1)
	local threat = math.clamp(threatIntensity, 0, 1)
	local nightAlpha = math.clamp(1 - daylight + threat * 0.08, 0, 1)

	Lighting.ClockTime = clockTime
	Lighting.Brightness = lerpNumber(day.Brightness, night.Brightness, nightAlpha)
	Lighting.ExposureCompensation = lerpNumber(day.ExposureCompensation, night.ExposureCompensation, nightAlpha)
	Lighting.Ambient = toColor3(day.Ambient):Lerp(toColor3(night.Ambient), nightAlpha)
	Lighting.OutdoorAmbient = toColor3(day.OutdoorAmbient):Lerp(toColor3(night.OutdoorAmbient), nightAlpha)
	Lighting.ColorShift_Top = toColor3(day.ColorShiftTop):Lerp(toColor3(night.ColorShiftTop), nightAlpha)
	Lighting.ColorShift_Bottom = toColor3(day.ColorShiftBottom):Lerp(toColor3(night.ColorShiftBottom), nightAlpha)
	Lighting.FogColor = toColor3(day.FogColor):Lerp(toColor3(night.FogColor), nightAlpha)
	Lighting.FogStart = lerpNumber(day.FogStart, night.FogStart, nightAlpha)
	Lighting.FogEnd = lerpNumber(day.FogEnd, night.FogEnd, nightAlpha)

	currentAtmosphere.Color = toColor3(day.Atmosphere.Color):Lerp(toColor3(night.Atmosphere.Color), nightAlpha)
	currentAtmosphere.Decay = toColor3(day.Atmosphere.Decay):Lerp(toColor3(night.Atmosphere.Decay), nightAlpha)
	currentAtmosphere.Density = lerpNumber(day.Atmosphere.Density, night.Atmosphere.Density, nightAlpha)
	currentAtmosphere.Offset = lerpNumber(day.Atmosphere.Offset, night.Atmosphere.Offset, nightAlpha)
	currentAtmosphere.Glare = lerpNumber(day.Atmosphere.Glare, night.Atmosphere.Glare, nightAlpha)
	currentAtmosphere.Haze = lerpNumber(day.Atmosphere.Haze, night.Atmosphere.Haze, nightAlpha)

	currentGrade.Brightness = lerpNumber(day.ColorGrade.Brightness, night.ColorGrade.Brightness, nightAlpha)
	currentGrade.Contrast = lerpNumber(day.ColorGrade.Contrast, night.ColorGrade.Contrast, nightAlpha)
	currentGrade.Saturation = lerpNumber(day.ColorGrade.Saturation, night.ColorGrade.Saturation, nightAlpha)
	currentGrade.TintColor = toColor3(day.ColorGrade.TintColor):Lerp(toColor3(night.ColorGrade.TintColor), nightAlpha)

	currentBloom.Intensity = lerpNumber(day.Bloom.Intensity, night.Bloom.Intensity, nightAlpha)
	currentBloom.Size = lerpNumber(day.Bloom.Size, night.Bloom.Size, nightAlpha)
	currentBloom.Threshold = lerpNumber(day.Bloom.Threshold, night.Bloom.Threshold, nightAlpha)
	currentBlur.Size = lerpNumber(day.BlurSize, night.BlurSize, nightAlpha)
	currentSunRays.Intensity = lerpNumber(day.SunRaysIntensity, night.SunRaysIntensity, nightAlpha)

	currentClouds.Cover = lerpNumber(day.Clouds.Cover, night.Clouds.Cover, nightAlpha)
	currentClouds.Density = lerpNumber(day.Clouds.Density, night.Clouds.Density, nightAlpha)
	currentClouds.Color = toColor3(day.Clouds.Color):Lerp(toColor3(night.Clouds.Color), nightAlpha)
	currentSky.StarCount = math.floor(profile.Sky.StarCount * nightAlpha + 0.5)
end

function EnvironmentProfileService.stop()
	if not started then
		return
	end
	started = false
	destroyOwnedEffects()
end

return table.freeze(EnvironmentProfileService)
