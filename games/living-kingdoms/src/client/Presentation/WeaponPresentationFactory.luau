--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local BasicFirearmPresentationFactory = require(script.Parent.BasicFirearmPresentationFactory)

export type WeaponPresentationRig = BasicFirearmPresentationFactory.BasicFirearmPresentationRig & {
	gripC0: CFrame,
}

local Factory = {}
local COLORS = table.freeze({
	dark = Color3.fromRGB(27, 30, 32),
	steel = Color3.fromRGB(84, 92, 94),
	olive = Color3.fromRGB(75, 84, 61),
	wood = Color3.fromRGB(104, 67, 43),
	red = Color3.fromRGB(129, 45, 38),
	blue = Color3.fromRGB(46, 82, 105),
	sand = Color3.fromRGB(123, 111, 78),
})

local function configure(part: BasePart, name: string, size: Vector3, color: Color3)
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Metal
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function weld(root: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = root.CFrame * offset
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = root
end

local function box(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3
): Part
	local part = Instance.new("Part")
	configure(part, name, size, color)
	part.Parent = model
	weld(root, part, offset)
	return part
end

local function cylinder(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3
): Part
	local part = box(model, root, name, size, offset, color)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function motorPart(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3
): (Part, Motor6D)
	local part = Instance.new("Part")
	configure(part, name, size, color)
	part.CFrame = root.CFrame * offset
	part.Parent = model
	local motor = Instance.new("Motor6D")
	motor.Name = name .. "Motor"
	motor.Part0 = root
	motor.Part1 = part
	motor.C0 = offset
	motor.Parent = root
	return part, motor
end

local function attachment(parent: BasePart, name: string, position: Vector3): Attachment
	local created = Instance.new("Attachment")
	created.Name = name
	created.Position = position
	created.Parent = parent
	return created
end

local function compactRig(weaponId: string): WeaponPresentationRig
	local model = Instance.new("Model")
	model.Name = "WeaponPresentation"
	model:SetAttribute("GameplayWeaponId", weaponId)
	model:SetAttribute("PresentationOnly", true)

	local root = Instance.new("Part")
	configure(root, "WeaponRoot", Vector3.new(0.1, 0.1, 0.1), COLORS.dark)
	root.Transparency = 1
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	local receiverLength = 1.2
	local barrelLength = 1.2
	local stockLength = 0.7
	local color = COLORS.olive
	local gripC0 = CFrame.new(0, -0.55, -0.15) * CFrame.Angles(math.rad(-8), math.rad(90), math.rad(-90))
	if weaponId == FirearmConfig.BreachShotgun.WeaponId then
		receiverLength, barrelLength, stockLength, color = 1.35, 1.8, 1, COLORS.wood
	elseif weaponId == FirearmConfig.SniperRifle.WeaponId then
		receiverLength, barrelLength, stockLength, color = 1.45, 2.65, 1.2, COLORS.sand
	elseif weaponId == FirearmConfig.ServicePistol.WeaponId then
		receiverLength, barrelLength, stockLength, color = 0.75, 0.45, 0, COLORS.steel
		gripC0 = CFrame.new(0, -0.35, -0.08) * CFrame.Angles(math.rad(-4), math.rad(90), math.rad(-90))
	elseif weaponId == FirearmConfig.SubmachineGun.WeaponId then
		receiverLength, barrelLength, stockLength, color = 1, 0.7, 0.45, COLORS.blue
	end

	box(model, root, "Receiver", Vector3.new(receiverLength, 0.45, 0.52), CFrame.new(0.1, 0, 0), color)
	box(
		model,
		root,
		"Handguard",
		Vector3.new(math.max(0.45, barrelLength * 0.58), 0.36, 0.4),
		CFrame.new(0.7 + barrelLength * 0.25, 0, 0),
		COLORS.dark
	)
	cylinder(
		model,
		root,
		"Barrel",
		Vector3.new(barrelLength, 0.16, 0.16),
		CFrame.new(0.85 + barrelLength * 0.72, 0, 0.04),
		COLORS.steel
	)
	if stockLength > 0 then
		box(
			model,
			root,
			"Stock",
			Vector3.new(stockLength, 0.34, 0.48),
			CFrame.new(-0.65 - stockLength * 0.45, 0, -0.02),
			color
		)
	end
	box(
		model,
		root,
		"Grip",
		Vector3.new(0.27, 0.26, 0.68),
		CFrame.new(-0.12, 0, -0.55) * CFrame.Angles(0, math.rad(8), 0),
		COLORS.dark
	)

	if weaponId == FirearmConfig.SniperRifle.WeaponId then
		cylinder(model, root, "Scope", Vector3.new(0.9, 0.25, 0.25), CFrame.new(0.25, 0, 0.55), COLORS.dark)
		box(model, root, "Bipod", Vector3.new(0.8, 0.1, 0.1), CFrame.new(1.55, 0, -0.42), COLORS.steel)
	elseif weaponId == FirearmConfig.BreachShotgun.WeaponId then
		box(model, root, "Pump", Vector3.new(0.72, 0.43, 0.46), CFrame.new(1.05, 0, -0.02), COLORS.red)
	elseif weaponId == FirearmConfig.ServicePistol.WeaponId then
		box(model, root, "Slide", Vector3.new(0.95, 0.32, 0.3), CFrame.new(0.12, 0, 0.21), COLORS.dark)
	elseif weaponId == FirearmConfig.SubmachineGun.WeaponId then
		box(model, root, "Foregrip", Vector3.new(0.22, 0.22, 0.52), CFrame.new(0.72, 0, -0.46), COLORS.dark)
	end

	local magazineSize = if weaponId == FirearmConfig.ServicePistol.WeaponId
		then Vector3.new(0.28, 0.3, 0.62)
		else Vector3.new(0.42, 0.34, 0.72)
	local _, magazineMotor = motorPart(model, root, "Magazine", magazineSize, CFrame.new(0.08, 0, -0.68), color)
	local _, boltMotor = motorPart(
		model,
		root,
		"Bolt",
		Vector3.new(0.45, 0.08, 0.18),
		CFrame.new(0.18, -0.29, 0.08),
		COLORS.steel
	)

	local muzzleX = 0.85 + barrelLength * 1.22
	local rightGripAttachment = attachment(root, "RightGripAttachment", Vector3.new(-0.12, 0, -0.55))
	local leftGripAttachment = attachment(root, "LeftGripAttachment", Vector3.new(0.85, 0, -0.05))
	local muzzleAttachment = attachment(root, "Muzzle", Vector3.new(muzzleX, 0, 0.04))
	local ejectionAttachment = attachment(root, "Ejection", Vector3.new(0.2, -0.32, 0.08))

	local muzzleFlash = box(
		model,
		root,
		"MuzzleFlash",
		Vector3.new(0.38, 0.38, 0.38),
		CFrame.new(muzzleX + 0.2, 0, 0.04),
		Color3.fromRGB(255, 205, 92)
	)
	muzzleFlash.Shape = Enum.PartType.Ball
	muzzleFlash.Material = Enum.Material.Neon
	muzzleFlash.Transparency = 1
	muzzleFlash.CastShadow = false
	local muzzleLight = Instance.new("PointLight")
	muzzleLight.Color = Color3.fromRGB(255, 190, 90)
	muzzleLight.Brightness = 2.2
	muzzleLight.Range = 7
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
		gripC0 = gripC0,
	})
end

function Factory.create(weaponId: string): WeaponPresentationRig
	if weaponId == FirearmConfig.BasicFirearm.WeaponId or weaponId == FirearmConfig.LightMachineGun.WeaponId then
		local basic = BasicFirearmPresentationFactory.create()
		basic.model.Name = "WeaponPresentation"
		basic.model:SetAttribute("GameplayWeaponId", weaponId)
		return table.freeze({
			model = basic.model,
			root = basic.root,
			boltMotor = basic.boltMotor,
			magazineMotor = basic.magazineMotor,
			boltRestC0 = basic.boltRestC0,
			magazineRestC0 = basic.magazineRestC0,
			muzzleAttachment = basic.muzzleAttachment,
			rightGripAttachment = basic.rightGripAttachment,
			leftGripAttachment = basic.leftGripAttachment,
			ejectionAttachment = basic.ejectionAttachment,
			muzzleFlash = basic.muzzleFlash,
			muzzleLight = basic.muzzleLight,
			gripC0 = CFrame.new(0, -0.55, -0.15)
				* CFrame.Angles(math.rad(-8), math.rad(90), math.rad(-90)),
		})
	end
	assert(FirearmConfig.get(weaponId) ~= nil, "weapon presentation requires a configured weapon")
	return compactRig(weaponId)
end

return table.freeze(Factory)
