--!strict

--[[
	VIS-0102 client-only fallback presentation for the Blackwater Support LMG.
	The silhouette is an original belt-fed squad support weapon inspired by the
	readability of classic light machine guns, not a replica of a branded firearm.
	This factory owns visual geometry, named attachment locators, and two
	presentation motors only. It owns no combat state, networking, targeting,
	damage, ammunition, reload acceptance, or authoritative timing.
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
	link = Color3.fromRGB(79, 75, 63),
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

local function weldParts(part0: BasePart, part1: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Name = part1.Name .. "Weld"
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
end

local function weldStatic(root: BasePart, part: BasePart, localCFrame: CFrame)
	part.CFrame = root.CFrame * localCFrame
	weldParts(root, part)
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

local function makeAttachedBox(
	model: Model,
	parent: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	configurePart(part, name, color, material)
	part.Size = size
	part.CFrame = parent.CFrame * localCFrame
	part.Parent = model
	weldParts(parent, part)
	return part
end

local function makeAttachedCylinder(
	model: Model,
	parent: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = makeAttachedBox(model, parent, name, size, localCFrame, color, material)
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
	model:SetAttribute("VisualCandidateId", "blackwater-support-lmg.v1")
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
		Vector3.new(1.56, 0.56, 0.68),
		CFrame.new(0.15, 0, 0.02),
		COLORS.charcoal,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"FeedCover",
		Vector3.new(1.08, 0.50, 0.14),
		CFrame.new(0.10, 0, 0.42),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"Handguard",
		Vector3.new(1.22, 0.48, 0.52),
		CFrame.new(1.49, 0, 0.03),
		COLORS.oliveDark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"HeatShield",
		Vector3.new(1.02, 0.52, 0.11),
		CFrame.new(1.48, 0, 0.36),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"StockCore",
		Vector3.new(0.70, 0.38, 0.42),
		CFrame.new(-0.94, 0, 0.03),
		COLORS.olive,
		Enum.Material.SmoothPlastic
	)
	makeBox(
		model,
		root,
		"Buttstock",
		Vector3.new(0.82, 0.46, 0.70),
		CFrame.new(-1.55, 0, -0.01) * CFrame.Angles(0, math.rad(-4), 0),
		COLORS.olive,
		Enum.Material.SmoothPlastic
	)
	makeCylinder(
		model,
		root,
		"Barrel",
		Vector3.new(1.50, 0.19, 0.19),
		CFrame.new(2.72, 0, 0.12),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeCylinder(
		model,
		root,
		"GasTube",
		Vector3.new(1.15, 0.13, 0.13),
		CFrame.new(2.08, 0, -0.10),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeCylinder(
		model,
		root,
		"MuzzleDevice",
		Vector3.new(0.38, 0.30, 0.30),
		CFrame.new(3.66, 0, 0.12),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"PistolGrip",
		Vector3.new(0.31, 0.29, 0.78),
		CFrame.new(-0.10, 0, -0.67) * CFrame.Angles(0, math.rad(8), 0),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)

	local magazine, magazineMotor = makeMotorPart(
		model,
		root,
		"Magazine",
		Vector3.new(0.76, 0.48, 0.88),
		CFrame.new(0.42, 0, -0.82) * CFrame.Angles(0, math.rad(-2), 0),
		COLORS.olive,
		Enum.Material.Metal
	)
	makeAttachedBox(
		model,
		magazine,
		"AmmoBoxLid",
		Vector3.new(0.80, 0.50, 0.12),
		CFrame.new(0, 0, 0.49),
		COLORS.oliveDark,
		Enum.Material.Metal
	)
	makeAttachedBox(
		model,
		magazine,
		"AmmoBoxPanel",
		Vector3.new(0.50, 0.025, 0.42),
		CFrame.new(0.02, -0.252, 0.02),
		COLORS.oliveDark,
		Enum.Material.Metal
	)
	makeAttachedBox(
		model,
		magazine,
		"AmmoBoxLatch",
		Vector3.new(0.13, 0.07, 0.18),
		CFrame.new(0.24, -0.27, 0.23),
		COLORS.steel,
		Enum.Material.Metal
	)

	local _, boltMotor = makeMotorPart(
		model,
		root,
		"Bolt",
		Vector3.new(0.56, 0.08, 0.20),
		CFrame.new(0.27, -0.33, 0.08),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"TopRail",
		Vector3.new(1.22, 0.10, 0.08),
		CFrame.new(0.12, 0, 0.54),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"RearSight",
		Vector3.new(0.22, 0.22, 0.30),
		CFrame.new(0.57, 0, 0.72),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"FrontSight",
		Vector3.new(0.18, 0.20, 0.38),
		CFrame.new(2.38, 0, 0.60),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"CarryHandleStem",
		Vector3.new(0.12, 0.14, 0.48),
		CFrame.new(0.75, 0, 0.86) * CFrame.Angles(0, math.rad(-18), 0),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeCylinder(
		model,
		root,
		"CarryHandle",
		Vector3.new(0.54, 0.14, 0.14),
		CFrame.new(0.98, 0, 1.05),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	makeCylinder(
		model,
		root,
		"TriggerGuardFront",
		Vector3.new(0.11, 0.32, 0.32),
		CFrame.new(0.02, 0, -0.42) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"Trigger",
		Vector3.new(0.08, 0.06, 0.25),
		CFrame.new(0.02, 0, -0.39),
		COLORS.brass,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"StockLatch",
		Vector3.new(0.16, 0.11, 0.11),
		CFrame.new(-1.18, 0, 0.32),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"HandStop",
		Vector3.new(0.19, 0.12, 0.16),
		CFrame.new(1.77, 0, -0.27),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	makeBox(
		model,
		root,
		"WarningStripe",
		Vector3.new(0.14, 0.07, 0.34),
		CFrame.new(1.18, 0.275, 0.03),
		COLORS.warning,
		Enum.Material.SmoothPlastic
	)
	makeCylinder(
		model,
		root,
		"RearSlingMount",
		Vector3.new(0.11, 0.15, 0.15),
		CFrame.new(-1.78, 0, -0.25) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeCylinder(
		model,
		root,
		"FrontSlingMount",
		Vector3.new(0.11, 0.14, 0.14),
		CFrame.new(1.92, 0, -0.19) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel,
		Enum.Material.Metal
	)

	makeBox(
		model,
		root,
		"BipodHinge",
		Vector3.new(0.24, 0.34, 0.18),
		CFrame.new(2.22, 0, -0.21),
		COLORS.steel,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"BipodLeftLeg",
		Vector3.new(0.70, 0.10, 0.10),
		CFrame.new(2.34, 0.25, -0.56) * CFrame.Angles(0, math.rad(-62), math.rad(4)),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"BipodRightLeg",
		Vector3.new(0.70, 0.10, 0.10),
		CFrame.new(2.34, -0.25, -0.56) * CFrame.Angles(0, math.rad(-62), math.rad(-4)),
		COLORS.dark,
		Enum.Material.Metal
	)
	makeBox(
		model,
		root,
		"BipodLeftFoot",
		Vector3.new(0.20, 0.16, 0.08),
		CFrame.new(2.04, 0.28, -0.84),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	makeBox(
		model,
		root,
		"BipodRightFoot",
		Vector3.new(0.20, 0.16, 0.08),
		CFrame.new(2.04, -0.28, -0.84),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)

	makeBox(
		model,
		root,
		"FeedTray",
		Vector3.new(0.56, 0.09, 0.13),
		CFrame.new(0.30, -0.32, -0.14),
		COLORS.steel,
		Enum.Material.Metal
	)
	for index = 1, 6 do
		local x = -0.34 + (index - 1) * 0.11
		local z = 0.59 - (index - 1) * 0.05
		makeAttachedCylinder(
			model,
			magazine,
			string.format("BeltRound%02d", index),
			Vector3.new(0.15, 0.072, 0.072),
			CFrame.new(x, -0.36, z),
			COLORS.brass,
			Enum.Material.Metal
		)
		makeAttachedBox(
			model,
			magazine,
			string.format("BeltLink%02d", index),
			Vector3.new(0.055, 0.085, 0.105),
			CFrame.new(x, -0.36, z),
			COLORS.link,
			Enum.Material.Metal
		)
	end

	local rightGripAttachment = makeAttachment(root, "RightGripAttachment", Vector3.new(-0.14, 0, -0.60))
	local leftGripAttachment = makeAttachment(root, "LeftGripAttachment", Vector3.new(1.43, 0, -0.08))
	local muzzleAttachment = makeAttachment(root, "Muzzle", Vector3.new(3.88, 0, 0.12))
	makeAttachment(root, "Magazine", Vector3.new(0.42, 0, -0.82))
	local ejectionAttachment = makeAttachment(root, "Ejection", Vector3.new(0.29, -0.39, 0.12))

	local muzzleFlash = makeBox(
		model,
		root,
		"MuzzleFlash",
		Vector3.new(0.46, 0.46, 0.46),
		CFrame.new(4.10, 0, 0.12),
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
