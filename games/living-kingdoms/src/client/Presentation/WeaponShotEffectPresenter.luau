--!strict

--[[
	VIS-0102 client-only firearm effects. The caller supplies an already accepted,
	server-disclosed shot and an optional authoritative damage-impact position.
	This module cannot request fire, spend ammunition, select a target, resolve a
	hit, apply damage, or complete a reload.
]]

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local BasicFirearmPresentationFactory = require(script.Parent.BasicFirearmPresentationFactory)

type BasicFirearmPresentationRig = BasicFirearmPresentationFactory.BasicFirearmPresentationRig

type WeaponShotEffectPresenter = {
	present: (
		rig: BasicFirearmPresentationRig,
		shotId: string,
		didApplyDamage: boolean,
		impactWorldPosition: Vector3?
	) -> (),
}

local EFFECTS_FOLDER_NAME = "LivingKingdomsPresentationEffects"
local MUZZLE_FLASH_SECONDS = 0.045
local CASING_LIFETIME_SECONDS = 1.25
local TRACER_LIFETIME_SECONDS = 0.055
local IMPACT_LIFETIME_SECONDS = 0.12
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

local function presentMuzzleFlash(rig: BasicFirearmPresentationRig)
	local currentGeneration = rig.model:GetAttribute("MuzzleFlashGeneration")
	local generation = if type(currentGeneration) == "number" then currentGeneration + 1 else 1
	rig.model:SetAttribute("MuzzleFlashGeneration", generation)
	rig.muzzleFlash.Transparency = 0.05
	rig.muzzleLight.Enabled = true
	task.delay(MUZZLE_FLASH_SECONDS, function()
		if rig.model.Parent == nil or rig.model:GetAttribute("MuzzleFlashGeneration") ~= generation then
			return
		end
		rig.muzzleFlash.Transparency = 1
		rig.muzzleLight.Enabled = false
	end)
end

local function spawnCasing(rig: BasicFirearmPresentationRig, shotId: string)
	local ejectionFrame = rig.ejectionAttachment.WorldCFrame
	local casing = Instance.new("Part")
	casing.Name = "CarbineCasing"
	casing:SetAttribute("SourceShotId", shotId)
	casing:SetAttribute("PresentationOnly", true)
	casing.Shape = Enum.PartType.Cylinder
	casing.Size = Vector3.new(0.14, 0.07, 0.07)
	casing.Color = Color3.fromRGB(176, 132, 48)
	casing.Material = Enum.Material.Metal
	casing.Anchored = false
	casing.CanCollide = false
	casing.CanTouch = false
	casing.CanQuery = false
	casing.CastShadow = false
	casing.CFrame = ejectionFrame * CFrame.Angles(0, 0, math.rad(90))
	casing.AssemblyLinearVelocity = ejectionFrame.RightVector * 11
		+ ejectionFrame.UpVector * 6
		+ ejectionFrame.LookVector * 1.5
	casing.AssemblyAngularVelocity = Vector3.new(12, 20, 16)
	casing.Parent = effectsFolder()
	Debris:AddItem(casing, CASING_LIFETIME_SECONDS)
end

local function spawnDamageTracer(rig: BasicFirearmPresentationRig, shotId: string, impactWorldPosition: Vector3)
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
	tracer.Size = Vector3.new(0.055, 0.055, distance)
	tracer.Color = Color3.fromRGB(255, 214, 120)
	tracer.Material = Enum.Material.Neon
	tracer.Transparency = 0.22
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.CFrame = CFrame.lookAt(muzzleWorldPosition:Lerp(impactWorldPosition, 0.5), impactWorldPosition)
	tracer.Parent = effectsFolder()
	Debris:AddItem(tracer, TRACER_LIFETIME_SECONDS)
end

local function spawnDamageImpact(impactWorldPosition: Vector3)
	local impact = Instance.new("Part")
	impact.Name = "AuthoritativeDamageImpact"
	impact:SetAttribute("PresentationOnly", true)
	impact.Shape = Enum.PartType.Ball
	impact.Size = Vector3.new(0.42, 0.42, 0.42)
	impact.Color = Color3.fromRGB(255, 205, 92)
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
	light.Color = Color3.fromRGB(255, 190, 90)
	light.Brightness = 1.8
	light.Range = 5
	light.Shadows = false
	light.Parent = impact
	Debris:AddItem(impact, IMPACT_LIFETIME_SECONDS)
end

function WeaponShotEffectPresenter.present(
	rig: BasicFirearmPresentationRig,
	shotId: string,
	didApplyDamage: boolean,
	impactWorldPosition: Vector3?
)
	presentMuzzleFlash(rig)
	spawnCasing(rig, shotId)
	if didApplyDamage and impactWorldPosition ~= nil then
		spawnDamageTracer(rig, shotId, impactWorldPosition)
		spawnDamageImpact(impactWorldPosition)
	end
end

return table.freeze(WeaponShotEffectPresenter)
