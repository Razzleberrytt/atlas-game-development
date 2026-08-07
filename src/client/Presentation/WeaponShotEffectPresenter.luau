--!strict

--[[
	Client-only firearm effects. The caller supplies an already accepted,
	server-disclosed shot and an optional authoritative damage-impact position.
	Per-weapon profiles change only presentation scale, timing, and motion. This
	module cannot request fire, spend ammunition, select a target, resolve a hit,
	apply damage, or complete a reload.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponFeelConfig = require(ReplicatedStorage.Shared.Config.WeaponFeelConfig)
local WeaponPresentationFactory = require(script.Parent.WeaponPresentationFactory)

type WeaponFeelProfile = WeaponFeelConfig.WeaponFeelProfile
type WeaponPresentationRig = WeaponPresentationFactory.WeaponPresentationRig

type WeaponShotEffectPresenter = {
	present: (
		rig: WeaponPresentationRig,
		shotId: string,
		didApplyDamage: boolean,
		impactWorldPosition: Vector3?,
		secondaryImpactWorldPositions: { Vector3 }
	) -> (),
}

local EFFECTS_FOLDER_NAME = "LivingKingdomsPresentationEffects"
local MINIMUM_TRACER_DISTANCE_STUDS = 0.5

local WeaponShotEffectPresenter: WeaponShotEffectPresenter = {} :: WeaponShotEffectPresenter

local function effectsFolder(): Folder
	local existing = Workspace:FindFirstChild(EFFECTS_FOLDER_NAME)
	if existing ~= nil then
		assert(existing:IsA("Folder"), EFFECTS_FOLDER_NAME .. " must be a Folder")
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = EFFECTS_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function profileForRig(rig: WeaponPresentationRig): WeaponFeelProfile
	return WeaponFeelConfig.get(rig.model:GetAttribute("GameplayWeaponId")) or WeaponFeelConfig.Default
end

local function casingColor(kindId: string): Color3
	if kindId == "ShotgunShell" then
		return Color3.fromRGB(154, 42, 35)
	elseif kindId == "HeavyRifle" then
		return Color3.fromRGB(188, 147, 61)
	elseif kindId == "Pistol" then
		return Color3.fromRGB(190, 148, 58)
	end
	return Color3.fromRGB(176, 132, 48)
end

local function presentMuzzleFlash(rig: WeaponPresentationRig, profile: WeaponFeelProfile)
	local currentGeneration = rig.model:GetAttribute("MuzzleFlashGeneration")
	local generation = if type(currentGeneration) == "number" then currentGeneration + 1 else 1
	rig.model:SetAttribute("MuzzleFlashGeneration", generation)
	local diameter = profile.MuzzleFlashDiameter
	rig.muzzleFlash.Size = Vector3.new(diameter, diameter, diameter)
	rig.muzzleFlash.Transparency = 0.05
	rig.muzzleLight.Brightness = profile.MuzzleLightBrightness
	rig.muzzleLight.Range = profile.MuzzleLightRange
	rig.muzzleLight.Enabled = true
	task.delay(profile.MuzzleFlashSeconds, function()
		if rig.model.Parent == nil or rig.model:GetAttribute("MuzzleFlashGeneration") ~= generation then
			return
		end
		rig.muzzleFlash.Transparency = 1
		rig.muzzleLight.Enabled = false
	end)
end

local function spawnCasing(rig: WeaponPresentationRig, shotId: string, profile: WeaponFeelProfile)
	local ejectionFrame = rig.ejectionAttachment.WorldCFrame
	local casing = Instance.new("Part")
	casing.Name = profile.CasingKindId .. "Casing"
	casing:SetAttribute("SourceShotId", shotId)
	casing:SetAttribute("PresentationOnly", true)
	casing.Shape = Enum.PartType.Cylinder
	casing.Size = Vector3.new(profile.CasingLength, profile.CasingDiameter, profile.CasingDiameter)
	casing.Color = casingColor(profile.CasingKindId)
	casing.Material = Enum.Material.Metal
	casing.Anchored = false
	casing.CanCollide = false
	casing.CanTouch = false
	casing.CanQuery = false
	casing.CastShadow = false
	casing.CFrame = ejectionFrame * CFrame.Angles(0, 0, math.rad(90))
	casing.AssemblyLinearVelocity = ejectionFrame.RightVector * profile.EjectionRightSpeed
		+ ejectionFrame.UpVector * profile.EjectionUpSpeed
		+ ejectionFrame.LookVector * profile.EjectionForwardSpeed
	local spin = profile.EjectionSpin
	casing.AssemblyAngularVelocity = Vector3.new(spin * 0.65, spin, spin * 0.8)
	casing.Parent = effectsFolder()
	Debris:AddItem(casing, 1.25)
end

local function tracerColor(profile: WeaponFeelProfile): Color3
	if profile.CasingKindId == "HeavyRifle" then
		return Color3.fromRGB(255, 235, 174)
	elseif profile.CasingKindId == "ShotgunShell" then
		return Color3.fromRGB(255, 194, 96)
	elseif profile.CasingKindId == "Pistol" then
		return Color3.fromRGB(255, 221, 142)
	end
	return Color3.fromRGB(255, 214, 120)
end

local function spawnDamageTracer(
	rig: WeaponPresentationRig,
	shotId: string,
	impactWorldPosition: Vector3,
	profile: WeaponFeelProfile
)
	local muzzleWorldPosition = rig.muzzleAttachment.WorldPosition
	local displacement = impactWorldPosition - muzzleWorldPosition
	local distance = displacement.Magnitude
	if distance < MINIMUM_TRACER_DISTANCE_STUDS then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "AuthoritativeDamageTracer"
	tracer:SetAttribute("SourceShotId", shotId)
	tracer:SetAttribute("PresentationOnly", true)
	tracer.Size = Vector3.new(profile.TracerWidth, profile.TracerWidth, distance)
	tracer.Color = tracerColor(profile)
	tracer.Material = Enum.Material.Neon
	tracer.Transparency = profile.TracerTransparency
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.CFrame = CFrame.lookAt(muzzleWorldPosition:Lerp(impactWorldPosition, 0.5), impactWorldPosition)
	tracer.Parent = effectsFolder()
	Debris:AddItem(tracer, profile.TracerLifetimeSeconds)
end

local function spawnDamageImpact(impactWorldPosition: Vector3, profile: WeaponFeelProfile)
	local impact = Instance.new("Part")
	impact.Name = "AuthoritativeDamageImpact"
	impact:SetAttribute("PresentationOnly", true)
	impact.Shape = Enum.PartType.Ball
	local diameter = profile.ImpactDiameter
	impact.Size = Vector3.new(diameter, diameter, diameter)
	impact.Color = tracerColor(profile)
	impact.Material = Enum.Material.Neon
	impact.Transparency = 0.08
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanTouch = false
	impact.CanQuery = false
	impact.CastShadow = false
	impact.Position = impactWorldPosition
	impact.Parent = effectsFolder()

	local light = Instance.new("PointLight")
	light.Name = "ImpactLight"
	light.Color = impact.Color
	light.Brightness = profile.ImpactLightBrightness
	light.Range = math.max(4, diameter * 7)
	light.Shadows = false
	light.Parent = impact
	Debris:AddItem(impact, profile.ImpactLifetimeSeconds)
end

function WeaponShotEffectPresenter.present(
	rig: WeaponPresentationRig,
	shotId: string,
	didApplyDamage: boolean,
	impactWorldPosition: Vector3?,
	secondaryImpactWorldPositions: { Vector3 }
)
	local profile = profileForRig(rig)
	presentMuzzleFlash(rig, profile)
	spawnCasing(rig, shotId, profile)
	if didApplyDamage and impactWorldPosition ~= nil then
		spawnDamageTracer(rig, shotId, impactWorldPosition, profile)
		spawnDamageImpact(impactWorldPosition, profile)
	end
	for index, secondaryPosition in secondaryImpactWorldPositions do
		if index > 3 then
			break
		end
		spawnDamageTracer(rig, shotId .. ":pattern:" .. tostring(index), secondaryPosition, profile)
		spawnDamageImpact(secondaryPosition, profile)
	end
end

return table.freeze(WeaponShotEffectPresenter)
