--!strict

-- Canonical runtime owner for the operation's global visual presentation.
-- LightingController owns cadence; this ModuleScript owns every global Lighting,
-- sky, atmosphere, cloud, post-processing, and landmark-accent mutation.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.EnvironmentVisualConfig)

local EnvironmentProfileService = {}

type VisualInstances = {
	sky: Sky,
	atmosphere: Atmosphere,
	grade: ColorCorrectionEffect,
	bloom: BloomEffect,
	blur: BlurEffect,
	sunRays: SunRaysEffect,
	clouds: Clouds,
}

local OWNED_LIGHTING_INSTANCES = table.freeze({
	"LivingKingdomsSky",
	"LivingKingdomsAtmosphere",
	"LivingKingdomsColorGrade",
	"LivingKingdomsBloom",
	"LivingKingdomsBlur",
	"LivingKingdomsSunRays",
})

local started = false
local visualInstances: VisualInstances? = nil

local function lerpNumber(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function destroyWrongClass(parent: Instance, name: string, className: string)
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and not existing:IsA(className) then
		existing:Destroy()
	end
end

local function ensureSky(): Sky
	destroyWrongClass(Lighting, "LivingKingdomsSky", "Sky")
	local existing = Lighting:FindFirstChild("LivingKingdomsSky")
	local sky: Sky
	if existing ~= nil and existing:IsA("Sky") then
		sky = existing
	else
		sky = Instance.new("Sky")
		sky.Name = "LivingKingdomsSky"
		sky.Parent = Lighting
	end

	sky.SkyboxBk = Config.Sky.SkyboxBk
	sky.SkyboxDn = Config.Sky.SkyboxDn
	sky.SkyboxFt = Config.Sky.SkyboxFt
	sky.SkyboxLf = Config.Sky.SkyboxLf
	sky.SkyboxRt = Config.Sky.SkyboxRt
	sky.SkyboxUp = Config.Sky.SkyboxUp
	sky.CelestialBodiesShown = Config.Sky.CelestialBodiesShown
	sky.StarCount = Config.Sky.StarCount
	sky.SunAngularSize = Config.Sky.SunAngularSize
	sky.MoonAngularSize = Config.Sky.MoonAngularSize
	return sky
end

local function ensureAtmosphere(): Atmosphere
	destroyWrongClass(Lighting, "LivingKingdomsAtmosphere", "Atmosphere")
	local existing = Lighting:FindFirstChild("LivingKingdomsAtmosphere")
	if existing ~= nil and existing:IsA("Atmosphere") then
		return existing
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "LivingKingdomsAtmosphere"
	atmosphere.Parent = Lighting
	return atmosphere
end

local function ensureGrade(): ColorCorrectionEffect
	destroyWrongClass(Lighting, "LivingKingdomsColorGrade", "ColorCorrectionEffect")
	local existing = Lighting:FindFirstChild("LivingKingdomsColorGrade")
	if existing ~= nil and existing:IsA("ColorCorrectionEffect") then
		return existing
	end

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LivingKingdomsColorGrade"
	grade.Parent = Lighting
	return grade
end

local function ensureBloom(): BloomEffect
	destroyWrongClass(Lighting, "LivingKingdomsBloom", "BloomEffect")
	local existing = Lighting:FindFirstChild("LivingKingdomsBloom")
	local bloom: BloomEffect
	if existing ~= nil and existing:IsA("BloomEffect") then
		bloom = existing
	else
		bloom = Instance.new("BloomEffect")
		bloom.Name = "LivingKingdomsBloom"
		bloom.Parent = Lighting
	end
	bloom.Size = 24
	return bloom
end

local function ensureBlur(): BlurEffect
	destroyWrongClass(Lighting, "LivingKingdomsBlur", "BlurEffect")
	local existing = Lighting:FindFirstChild("LivingKingdomsBlur")
	if existing ~= nil and existing:IsA("BlurEffect") then
		return existing
	end

	local blur = Instance.new("BlurEffect")
	blur.Name = "LivingKingdomsBlur"
	blur.Parent = Lighting
	return blur
end

local function ensureSunRays(): SunRaysEffect
	destroyWrongClass(Lighting, "LivingKingdomsSunRays", "SunRaysEffect")
	local existing = Lighting:FindFirstChild("LivingKingdomsSunRays")
	local sunRays: SunRaysEffect
	if existing ~= nil and existing:IsA("SunRaysEffect") then
		sunRays = existing
	else
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "LivingKingdomsSunRays"
		sunRays.Parent = Lighting
	end
	sunRays.Spread = 0.55
	return sunRays
end

local function ensureClouds(): Clouds
	local terrain = Workspace.Terrain
	destroyWrongClass(terrain, "LivingKingdomsClouds", "Clouds")
	local existing = terrain:FindFirstChild("LivingKingdomsClouds")
	if existing ~= nil and existing:IsA("Clouds") then
		return existing
	end

	local clouds = Instance.new("Clouds")
	clouds.Name = "LivingKingdomsClouds"
	clouds.Parent = terrain
	return clouds
end

local function ensureVisualInstances(): VisualInstances
	return {
		sky = ensureSky(),
		atmosphere = ensureAtmosphere(),
		grade = ensureGrade(),
		bloom = ensureBloom(),
		blur = ensureBlur(),
		sunRays = ensureSunRays(),
		clouds = ensureClouds(),
	}
end

local function bundleIsAlive(bundle: VisualInstances): boolean
	return bundle.sky.Parent == Lighting
		and bundle.atmosphere.Parent == Lighting
		and bundle.grade.Parent == Lighting
		and bundle.bloom.Parent == Lighting
		and bundle.blur.Parent == Lighting
		and bundle.sunRays.Parent == Lighting
		and bundle.clouds.Parent == Workspace.Terrain
end

local function getVisualInstances(): VisualInstances
	local bundle = visualInstances
	if bundle == nil or not bundleIsAlive(bundle) then
		bundle = ensureVisualInstances()
		visualInstances = bundle
	end
	return bundle
end

local function findPhasePair(clockTime: number): (any, any, number)
	local phases = Config.Phases
	for index = 1, #phases do
		local current = phases[index]
		local following = phases[(index % #phases) + 1]
		local startClock = current.clock
		local endClock = following.clock
		local sampleClock = clockTime
		if endClock <= startClock then
			endClock += 24
			if sampleClock < startClock then
				sampleClock += 24
			end
		end
		if sampleClock >= startClock and sampleClock <= endClock then
			local span = endClock - startClock
			local alpha = if span <= 0 then 0 else math.clamp((sampleClock - startClock) / span, 0, 1)
			return current, following, alpha
		end
	end
	return phases[1], phases[2], 0
end

local function updateAccentLights(dayFactor: number)
	local nightFactor = 1 - math.clamp(dayFactor, 0, 1)
	for _, instance in CollectionService:GetTagged(Config.AccentLightTag) do
		if not instance:IsA("Light") then
			continue
		end
		local baseBrightness = instance:GetAttribute("BaseBrightness")
		local nightMultiplier = instance:GetAttribute("NightMultiplier")
		local dayColor = instance:GetAttribute("DayColor")
		local nightColor = instance:GetAttribute("NightColor")
		if typeof(baseBrightness) ~= "number" or typeof(nightMultiplier) ~= "number" then
			continue
		end
		instance.Brightness = baseBrightness * lerpNumber(1, nightMultiplier, nightFactor)
		if typeof(dayColor) == "Color3" and typeof(nightColor) == "Color3" then
			instance.Color = dayColor:Lerp(nightColor, nightFactor)
		end
	end
end

function EnvironmentProfileService.start()
	if started then
		getVisualInstances()
		return
	end
	started = true
	Lighting:SetAttribute("EnvironmentVisualOwner", "LightingController")
	Lighting:SetAttribute("EnvironmentVisualVersion", Config.Version)
	getVisualInstances()
end

function EnvironmentProfileService.applyClock(clockTime: number)
	if not started then
		EnvironmentProfileService.start()
	end

	local bundle = getVisualInstances()
	local from, to, alpha = findPhasePair(clockTime)

	Lighting.ClockTime = clockTime
	Lighting.GeographicLatitude = Config.Cycle.GeographicLatitude
	Lighting.Brightness = lerpNumber(from.brightness, to.brightness, alpha)
	Lighting.ExposureCompensation = lerpNumber(from.exposure, to.exposure, alpha)
	Lighting.Ambient = from.ambient:Lerp(to.ambient, alpha)
	Lighting.OutdoorAmbient = from.outdoorAmbient:Lerp(to.outdoorAmbient, alpha)
	Lighting.ColorShift_Top = from.colorShiftTop:Lerp(to.colorShiftTop, alpha)
	Lighting.ColorShift_Bottom = from.colorShiftBottom:Lerp(to.colorShiftBottom, alpha)
	Lighting.EnvironmentDiffuseScale = Config.Lighting.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = Config.Lighting.EnvironmentSpecularScale
	Lighting.GlobalShadows = Config.Lighting.GlobalShadows
	Lighting.ShadowSoftness = Config.Lighting.ShadowSoftness
	Lighting.FogColor = from.fogColor:Lerp(to.fogColor, alpha)
	Lighting.FogStart = lerpNumber(from.fogStart, to.fogStart, alpha)
	Lighting.FogEnd = lerpNumber(from.fogEnd, to.fogEnd, alpha)

	bundle.atmosphere.Color = from.atmosphereColor:Lerp(to.atmosphereColor, alpha)
	bundle.atmosphere.Decay = from.atmosphereDecay:Lerp(to.atmosphereDecay, alpha)
	bundle.atmosphere.Density = lerpNumber(from.atmosphereDensity, to.atmosphereDensity, alpha)
	bundle.atmosphere.Offset = lerpNumber(from.atmosphereOffset, to.atmosphereOffset, alpha)
	bundle.atmosphere.Glare = lerpNumber(from.atmosphereGlare, to.atmosphereGlare, alpha)
	bundle.atmosphere.Haze = lerpNumber(from.atmosphereHaze, to.atmosphereHaze, alpha)

	bundle.grade.TintColor = from.gradeTint:Lerp(to.gradeTint, alpha)
	bundle.grade.Brightness = lerpNumber(from.gradeBrightness, to.gradeBrightness, alpha)
	bundle.grade.Contrast = lerpNumber(from.gradeContrast, to.gradeContrast, alpha)
	bundle.grade.Saturation = lerpNumber(from.gradeSaturation, to.gradeSaturation, alpha)

	bundle.bloom.Intensity = lerpNumber(from.bloomIntensity, to.bloomIntensity, alpha)
	bundle.bloom.Threshold = lerpNumber(from.bloomThreshold, to.bloomThreshold, alpha)
	bundle.blur.Size = lerpNumber(from.blurSize, to.blurSize, alpha)
	bundle.sunRays.Intensity = lerpNumber(from.sunRaysIntensity, to.sunRaysIntensity, alpha)

	bundle.clouds.Cover = lerpNumber(from.cloudCover, to.cloudCover, alpha)
	bundle.clouds.Density = lerpNumber(from.cloudDensity, to.cloudDensity, alpha)
	bundle.clouds.Color = from.cloudColor:Lerp(to.cloudColor, alpha)

	updateAccentLights(lerpNumber(from.accentDayFactor, to.accentDayFactor, alpha))
end

function EnvironmentProfileService.stop()
	if not started then
		return
	end
	started = false
	visualInstances = nil
	for _, childName in OWNED_LIGHTING_INSTANCES do
		local existing = Lighting:FindFirstChild(childName)
		if existing ~= nil then
			existing:Destroy()
		end
	end
	local clouds = Workspace.Terrain:FindFirstChild("LivingKingdomsClouds")
	if clouds ~= nil then
		clouds:Destroy()
	end
end

return table.freeze(EnvironmentProfileService)
