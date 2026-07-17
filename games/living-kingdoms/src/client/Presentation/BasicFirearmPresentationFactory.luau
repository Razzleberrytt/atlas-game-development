--!strict

--[[
	VIS-0102 client-only fallback presentation for the Blackwater Service Carbine.
	This factory creates visual geometry, named attachment locators, and two
	presentation motors. It owns no combat state, networking, targeting, damage,
	ammunition, reload acceptance, or authoritative timing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)

export type BasicFirearmPresentationRig = {
	model: Model,
	root: BasePart,
	boltMotor: Motor6D,
	magazineMotor: Motor6D,
	boltRestC0: CFrame,
	magazineRestC0: CFrame,
	muzzleAttachment: Attachment,
	rightGripAttachment: Attachment,
	leftGripAttachment: Attachment,
	ejectionAttachment: Attachment,
	muzzleFlash: BasePart,
	muzzleLight: PointLight,
}

local BasicFirearmPresentationFactory = {}

local COLORS = table.freeze({
	charcoal = Color3.fromRGB(44, 48, 49),
	dark = Color3.fromRGB(29, 32, 33),
	olive = Color3.fromRGB(85, 91, 65),
	oliveDark = Color3.fromRGB(62, 67, 49),
	rubber = Color3.fromRGB(34, 35, 32),
	steel = Color3.fromRGB(93, 98, 96),
	brass = Color3.fromRGB(154, 119, 50),
	warning = Color3.fromRGB(192, 85, 38),
})

local function configurePart(part: BasePart, name: string, color: Color3, material: Enum.Material)
	part.Name = name
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function weldStatic(root: BasePart, part: BasePart, localCFrame: CFrame)
	part.CFrame = root.CFrame * localCFrame
	local weld = Instance.new("WeldConstraint")
	weld.Name = part.Name .. "Weld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root
end

local function makeBox(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	configurePart(part, name, color, material)
	part.Size = size
	part.Parent = model
	weldStatic(root, part, localCFrame)
	return part
end

local function makeCylinder(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = makeBox(model, root, name, size, localCFrame, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function makeMotorPart(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material
): (Part, Motor6D)
	local part = Instance.new("Part")
	configurePart(part, name, color, material)
	part.Size = size
	part.CFrame = root.CFrame * localCFrame
	part.Parent = model

	local motor = Instance.new("Motor6D")
	motor.Name = name .. "Motor"
	motor.Part0 = root
	motor.Part1 = part
	motor.C0 = localCFrame
	motor.C1 = CFrame.identity
	motor.Parent = root
	return part, motor
end

local function makeAttachment(parent: BasePart, name: string, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = parent
	return attachment
end

function BasicFirearmPresentationFactory.create(): BasicFirearmPresentationRig
	local model = Instance.new("Model")
	model.Name = "BasicFirearmPresentation"
	model:SetAttribute("VisualAssetKey", VisualAssetContracts.AssetKeys.WeaponBasicFirearmModel)
	model:SetAttribute("VisualCandidateId", "blackwater-service-carbine.v1")
	model:SetAttribute("VisualStatus", "ProceduralFallback")
	model:SetAttribute("GameplayFootprintId", "weapon.basic-firearm")

	local root = Instance.new("Part")
	configurePart(root, "WeaponRoot", COLORS.charcoal, Enum.Material.SmoothPlastic)
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Transparency = 1
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	makeBox(
		model,
		root,
		"Receiver",
		Vector3.new(1.26, 0.48, 0.6),
		CFrame.new(0.15, 0, 0),
		COLORS.charcoal,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"Handguard",
		Vector3.new(1.14, 0.42, 0.48),
		CFrame.new(1.29, 0, 0.03),
		COLORS.oliveDark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"StockCore",
		Vector3.new(0.78, 0.36, 0.39),
		CFrame.new(-0.84, 0, 0.045),
		COLORS.olive,
		Enum.Material.SmoothPlastic
	)
	makeBox(
		model,
		root,
		"Buttstock",
		Vector3.new(0.66, 0.42, 0.66),
		CFrame.new(-1.41, 0, 0.015) * CFrame.Angles(0, math.rad(-4), 0),
		COLORS.olive,
		Enum.Material.SmoothPlastic
	)
	makeCylinder(
		model,
		root,
		"Barrel",
		Vector3.new(1.29, 0.228, 0.228),
		CFrame.new(2.28, 0, 0.09),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeCylinder(
		model,
		root,
		"MuzzleDevice",
		Vector3.new(0.3, 0.312, 0.312),
		CFrame.new(3.075, 0, 0.09),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"PistolGrip",
		Vector3.new(0.3, 0.27, 0.72),
		CFrame.new(-0.06, 0, -0.6) * CFrame.Angles(0, math.rad(8), 0),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	local _, magazineMotor = makeMotorPart(
		model,
		root,
		"Magazine",
		Vector3.new(0.51, 0.315, 0.78),
		CFrame.new(0.57, 0, -0.69) * CFrame.Angles(0, math.rad(-7), 0),
		COLORS.olive,
		Enum.Material.Metal
	)
	local _, boltMotor = makeMotorPart(
		model,
		root,
		"Bolt",
		Vector3.new(0.51, 0.075, 0.18),
		CFrame.new(0.21, -0.285, 0.06),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"TopRail",
		Vector3.new(0.93, 0.09, 0.075),
		CFrame.new(0.21, 0, 0.375),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"RearSight",
		Vector3.new(0.21, 0.21, 0.285),
		CFrame.new(0.63, 0, 0.57),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"FrontSight",
		Vector3.new(0.165, 0.195, 0.33),
		CFrame.new(2.16, 0, 0.48),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeCylinder(
		model,
		root,
		"TriggerGuardFront",
		Vector3.new(0.105, 0.315, 0.315),
		CFrame.new(0.06, 0, -0.39) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"Trigger",
		Vector3.new(0.075, 0.06, 0.24),
		CFrame.new(0.06, 0, -0.36),
		COLORS.brass,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"StockLatch",
		Vector3.new(0.15, 0.105, 0.105),
		CFrame.new(-1.11, 0, 0.3),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"HandStop",
		Vector3.new(0.18, 0.105, 0.105),
		CFrame.new(1.65, 0, -0.225),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	makeBox(
		model,
		root,
		"WarningStripe",
		Vector3.new(0.12, 0.066, 0.3),
		CFrame.new(1.2, 0.243, 0.045),
		COLORS.warning,
		Enum.Material.SmoothPlastic
	)
	makeCylinder(
		model,
		root,
		"RearSlingMount",
		Vector3.new(0.105, 0.144, 0.144),
		CFrame.new(-1.59, 0, -0.24) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeCylinder(
		model,
		root,
		"FrontSlingMount",
		Vector3.new(0.105, 0.132, 0.132),
		CFrame.new(1.77, 0, -0.18) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel,
		Enum.Material.Metal
	)

	local rightGripAttachment = makeAttachment(root, "RightGripAttachment", Vector3.new(-0.12, 0, -0.54))
	local leftGripAttachment = makeAttachment(root, "LeftGripAttachment", Vector3.new(1.29, 0, -0.06))
	local muzzleAttachment = makeAttachment(root, "Muzzle", Vector3.new(3.27, 0, 0.09))
	makeAttachment(root, "Magazine", Vector3.new(0.57, 0, -0.69))
	local ejectionAttachment = makeAttachment(root, "Ejection", Vector3.new(0.24, -0.345, 0.105))

	local muzzleFlash = makeBox(
		model,
		root,
		"MuzzleFlash",
		Vector3.new(0.42, 0.42, 0.42),
		CFrame.new(3.45, 0, 0.09),
		Color3.fromRGB(255, 205, 92),
		Enum.Material.Neon
	)
	muzzleFlash.Shape = Enum.PartType.Ball
	muzzleFlash.Transparency = 1
	muzzleFlash.CastShadow = false

	local muzzleLight = Instance.new("PointLight")
	muzzleLight.Name = "MuzzleLight"
	muzzleLight.Color = Color3.fromRGB(255, 190, 90)
	muzzleLight.Brightness = 2.2
	muzzleLight.Range = 7
	muzzleLight.Shadows = false
	muzzleLight.Enabled = false
	muzzleLight.Parent = muzzleAttachment

	return table.freeze({
		model = model,
		root = root,
		boltMotor = boltMotor,
		magazineMotor = magazineMotor,
		boltRestC0 = boltMotor.C0,
		magazineRestC0 = magazineMotor.C0,
		muzzleAttachment = muzzleAttachment,
		rightGripAttachment = rightGripAttachment,
		leftGripAttachment = leftGripAttachment,
		ejectionAttachment = ejectionAttachment,
		muzzleFlash = muzzleFlash,
		muzzleLight = muzzleLight,
	})
end

return table.freeze(BasicFirearmPresentationFactory)
