--!strict

--[[
	Shared client-only construction kit for project-original weapon silhouettes.
	It owns presentation geometry, attachment locators, and the two presentation
	motors consumed by WeaponPresentationController. It owns no combat authority.
]]

export type WeaponVisualModelRig = {
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
	gripC0: CFrame,
}

export type BuildContext = {
	model: Model,
	root: Part,
}

export type FinishConfig = {
	boltMotor: Motor6D,
	magazineMotor: Motor6D,
	gripC0: CFrame,
	muzzlePosition: Vector3,
	rightGripPosition: Vector3,
	leftGripPosition: Vector3,
	ejectionPosition: Vector3,
	magazinePosition: Vector3,
	muzzleFlashDiameter: number?,
}

local Builder = {}

local function configurePart(part: BasePart, name: string, size: Vector3, color: Color3, material: Enum.Material)
	part.Name = name
	part.Size = size
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
	local constraint = Instance.new("WeldConstraint")
	constraint.Name = part1.Name .. "Weld"
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part0
end

function Builder.newContext(
	weaponId: string,
	visualAssetKey: string,
	visualCandidateId: string,
	gameplayFootprintId: string
): BuildContext
	local model = Instance.new("Model")
	model.Name = "WeaponPresentation"
	model:SetAttribute("GameplayWeaponId", weaponId)
	model:SetAttribute("VisualAssetKey", visualAssetKey)
	model:SetAttribute("VisualCandidateId", visualCandidateId)
	model:SetAttribute("VisualStatus", "ProceduralFallback")
	model:SetAttribute("GameplayFootprintId", gameplayFootprintId)
	model:SetAttribute("PresentationOnly", true)

	local root = Instance.new("Part")
	configurePart(root, "WeaponRoot", Vector3.new(0.1, 0.1, 0.1), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	return {
		model = model,
		root = root,
	}
end

function Builder.box(
	context: BuildContext,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	configurePart(part, name, size, color, material or Enum.Material.Metal)
	part.CFrame = context.root.CFrame * offset
	part.Parent = context.model
	weldParts(context.root, part)
	return part
end

function Builder.cylinder(
	context: BuildContext,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Builder.box(context, name, size, offset, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

function Builder.wedge(
	context: BuildContext,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local part = Instance.new("WedgePart")
	configurePart(part, name, size, color, material or Enum.Material.Metal)
	part.CFrame = context.root.CFrame * offset
	part.Parent = context.model
	weldParts(context.root, part)
	return part
end

function Builder.motorBox(
	context: BuildContext,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): (Part, Motor6D)
	local part = Instance.new("Part")
	configurePart(part, name, size, color, material or Enum.Material.Metal)
	part.CFrame = context.root.CFrame * offset
	part.Parent = context.model

	local motor = Instance.new("Motor6D")
	motor.Name = name .. "Motor"
	motor.Part0 = context.root
	motor.Part1 = part
	motor.C0 = offset
	motor.C1 = CFrame.identity
	motor.Parent = context.root
	return part, motor
end

function Builder.attachBox(
	context: BuildContext,
	parent: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	configurePart(part, name, size, color, material or Enum.Material.Metal)
	part.CFrame = parent.CFrame * offset
	part.Parent = context.model
	weldParts(parent, part)
	return part
end

function Builder.attachCylinder(
	context: BuildContext,
	parent: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Builder.attachBox(context, parent, name, size, offset, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

function Builder.attachment(parent: BasePart, name: string, position: Vector3): Attachment
	local created = Instance.new("Attachment")
	created.Name = name
	created.Position = position
	created.Parent = parent
	return created
end

function Builder.finish(context: BuildContext, config: FinishConfig): WeaponVisualModelRig
	local rightGripAttachment = Builder.attachment(context.root, "RightGripAttachment", config.rightGripPosition)
	local leftGripAttachment = Builder.attachment(context.root, "LeftGripAttachment", config.leftGripPosition)
	local muzzleAttachment = Builder.attachment(context.root, "Muzzle", config.muzzlePosition)
	Builder.attachment(context.root, "Magazine", config.magazinePosition)
	local ejectionAttachment = Builder.attachment(context.root, "Ejection", config.ejectionPosition)

	local diameter = config.muzzleFlashDiameter or 0.4
	local muzzleFlash = Builder.box(
		context,
		"MuzzleFlash",
		Vector3.new(diameter, diameter, diameter),
		CFrame.new(config.muzzlePosition + Vector3.new(diameter * 0.45, 0, 0)),
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
		model = context.model,
		root = context.root,
		boltMotor = config.boltMotor,
		magazineMotor = config.magazineMotor,
		boltRestC0 = config.boltMotor.C0,
		magazineRestC0 = config.magazineMotor.C0,
		muzzleAttachment = muzzleAttachment,
		rightGripAttachment = rightGripAttachment,
		leftGripAttachment = leftGripAttachment,
		ejectionAttachment = ejectionAttachment,
		muzzleFlash = muzzleFlash,
		muzzleLight = muzzleLight,
		gripC0 = config.gripC0,
	})
end

return table.freeze(Builder)
