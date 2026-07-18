--!strict

--[[
	Project-original Longwatch Sniper Rifle presentation. A long free-floated
	barrel, large optic, raised cheek rest, detachable magazine, bolt handle,
	and folded bipod communicate precision and extreme range at isometric scale.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)
local Builder = require(script.Parent.WeaponVisualModelBuilder)

type WeaponVisualModelRig = Builder.WeaponVisualModelRig

local Factory = {}

local COLORS = table.freeze({
	black = Color3.fromRGB(25, 28, 29),
	gunmetal = Color3.fromRGB(59, 65, 66),
	steel = Color3.fromRGB(99, 105, 104),
	sand = Color3.fromRGB(125, 113, 78),
	sandDark = Color3.fromRGB(86, 79, 56),
	rubber = Color3.fromRGB(34, 35, 33),
	glass = Color3.fromRGB(48, 96, 115),
	amber = Color3.fromRGB(181, 104, 35),
})

function Factory.create(): WeaponVisualModelRig
	local weaponId = FirearmConfig.SniperRifle.WeaponId
	local context = Builder.newContext(
		weaponId,
		VisualAssetContracts.AssetKeys.WeaponSniperRifleModel,
		"longwatch-sniper-rifle.v2",
		"weapon.sniper-rifle"
	)

	Builder.box(context, "Receiver", Vector3.new(1.44, 0.54, 0.60), CFrame.new(0.08, 0, 0.05), COLORS.gunmetal)
	Builder.box(context, "ReceiverCrown", Vector3.new(1.12, 0.47, 0.14), CFrame.new(0.10, 0, 0.43), COLORS.black)
	Builder.box(context, "FreeFloatHandguard", Vector3.new(1.72, 0.48, 0.48), CFrame.new(1.58, 0, 0.05), COLORS.sandDark)
	for index = 1, 6 do
		Builder.box(
			context,
			"HandguardSlot" .. tostring(index),
			Vector3.new(0.15, 0.51, 0.06),
			CFrame.new(0.94 + index * 0.23, 0, 0.31),
			COLORS.black
		)
	end

	Builder.cylinder(context, "HeavyBarrel", Vector3.new(3.05, 0.18, 0.18), CFrame.new(3.62, 0, 0.14), COLORS.black)
	Builder.cylinder(context, "BarrelCollar", Vector3.new(0.34, 0.31, 0.31), CFrame.new(2.12, 0, 0.14), COLORS.steel)
	Builder.cylinder(context, "MuzzleBrakeCore", Vector3.new(0.52, 0.34, 0.34), CFrame.new(5.40, 0, 0.14), COLORS.steel)
	Builder.box(context, "MuzzleBrakeTop", Vector3.new(0.32, 0.38, 0.09), CFrame.new(5.38, 0, 0.38), COLORS.black)
	Builder.box(context, "MuzzleBrakeBottom", Vector3.new(0.32, 0.38, 0.09), CFrame.new(5.38, 0, -0.10), COLORS.black)

	Builder.box(context, "StockSpine", Vector3.new(1.12, 0.38, 0.36), CFrame.new(-1.02, 0, 0.09), COLORS.sandDark)
	Builder.wedge(
		context,
		"PrecisionStock",
		Vector3.new(1.18, 0.58, 0.82),
		CFrame.new(-1.70, 0, -0.02) * CFrame.Angles(0, math.rad(180), 0),
		COLORS.sand,
		Enum.Material.SmoothPlastic
	)
	Builder.box(context, "ButtPad", Vector3.new(0.18, 0.62, 0.84), CFrame.new(-2.34, 0, -0.03), COLORS.rubber, Enum.Material.SmoothPlastic)
	Builder.box(context, "CheekRest", Vector3.new(0.82, 0.46, 0.18), CFrame.new(-1.49, 0, 0.52), COLORS.rubber, Enum.Material.SmoothPlastic)
	Builder.box(context, "LengthAdjuster", Vector3.new(0.52, 0.18, 0.18), CFrame.new(-2.04, 0, 0.24), COLORS.steel)
	Builder.box(
		context,
		"PistolGrip",
		Vector3.new(0.34, 0.31, 0.80),
		CFrame.new(-0.36, 0, -0.68) * CFrame.Angles(0, math.rad(9), 0),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	Builder.cylinder(
		context,
		"TriggerGuard",
		Vector3.new(0.11, 0.38, 0.38),
		CFrame.new(-0.02, 0, -0.43) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.black
	)
	Builder.box(context, "Trigger", Vector3.new(0.08, 0.06, 0.25), CFrame.new(-0.02, 0, -0.40), COLORS.amber)

	local magazine, magazineMotor = Builder.motorBox(
		context,
		"Magazine",
		Vector3.new(0.48, 0.38, 0.80),
		CFrame.new(0.35, 0, -0.76) * CFrame.Angles(0, math.rad(-3), 0),
		COLORS.black
	)
	Builder.attachBox(context, magazine, "MagazineBase", Vector3.new(0.58, 0.42, 0.14), CFrame.new(0, 0, -0.46), COLORS.sandDark)
	Builder.attachBox(context, magazine, "MagazineRib", Vector3.new(0.11, 0.40, 0.56), CFrame.new(0.18, 0, 0.04), COLORS.steel)

	local bolt, boltMotor = Builder.motorBox(
		context,
		"Bolt",
		Vector3.new(0.66, 0.10, 0.22),
		CFrame.new(0.15, -0.35, 0.15),
		COLORS.steel
	)
	Builder.attachBox(context, bolt, "BoltHandleStem", Vector3.new(0.13, 0.40, 0.13), CFrame.new(0.14, -0.22, -0.02), COLORS.steel)
	Builder.attachCylinder(
		context,
		bolt,
		"BoltHandleKnob",
		Vector3.new(0.16, 0.24, 0.24),
		CFrame.new(0.14, -0.47, -0.02),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)

	Builder.box(context, "TopRail", Vector3.new(1.76, 0.12, 0.09), CFrame.new(0.32, 0, 0.62), COLORS.black)
	Builder.box(context, "ScopeRearMount", Vector3.new(0.18, 0.45, 0.32), CFrame.new(-0.28, 0, 0.83), COLORS.black)
	Builder.box(context, "ScopeFrontMount", Vector3.new(0.18, 0.45, 0.32), CFrame.new(0.82, 0, 0.83), COLORS.black)
	Builder.cylinder(context, "ScopeTube", Vector3.new(1.72, 0.28, 0.28), CFrame.new(0.28, 0, 0.97), COLORS.black)
	Builder.cylinder(context, "ScopeObjective", Vector3.new(0.38, 0.48, 0.48), CFrame.new(1.28, 0, 0.97), COLORS.gunmetal)
	Builder.cylinder(context, "ScopeEyepiece", Vector3.new(0.34, 0.39, 0.39), CFrame.new(-0.70, 0, 0.97), COLORS.gunmetal)
	Builder.cylinder(context, "ObjectiveLens", Vector3.new(0.06, 0.42, 0.42), CFrame.new(1.50, 0, 0.97), COLORS.glass, Enum.Material.Glass)
	Builder.cylinder(context, "EyepieceLens", Vector3.new(0.06, 0.33, 0.33), CFrame.new(-0.90, 0, 0.97), COLORS.glass, Enum.Material.Glass)
	Builder.cylinder(context, "ElevationTurret", Vector3.new(0.18, 0.22, 0.22), CFrame.new(0.25, 0, 1.20) * CFrame.Angles(0, 0, math.rad(90)), COLORS.steel)
	Builder.cylinder(context, "WindageTurret", Vector3.new(0.18, 0.20, 0.20), CFrame.new(0.25, -0.24, 0.97), COLORS.steel)

	Builder.box(context, "BipodHinge", Vector3.new(0.26, 0.34, 0.20), CFrame.new(2.02, 0, -0.24), COLORS.steel)
	Builder.box(
		context,
		"BipodLeftLeg",
		Vector3.new(0.90, 0.10, 0.10),
		CFrame.new(2.13, 0.30, -0.62) * CFrame.Angles(0, math.rad(-61), math.rad(5)),
		COLORS.black
	)
	Builder.box(
		context,
		"BipodRightLeg",
		Vector3.new(0.90, 0.10, 0.10),
		CFrame.new(2.13, -0.30, -0.62) * CFrame.Angles(0, math.rad(-61), math.rad(-5)),
		COLORS.black
	)
	Builder.box(context, "BipodLeftFoot", Vector3.new(0.22, 0.17, 0.09), CFrame.new(1.75, 0.34, -0.98), COLORS.rubber)
	Builder.box(context, "BipodRightFoot", Vector3.new(0.22, 0.17, 0.09), CFrame.new(1.75, -0.34, -0.98), COLORS.rubber)

	Builder.box(context, "RangeAccent", Vector3.new(0.20, 0.07, 0.34), CFrame.new(1.02, 0.275, 0.02), COLORS.amber, Enum.Material.SmoothPlastic)
	Builder.cylinder(
		context,
		"RearSlingMount",
		Vector3.new(0.10, 0.18, 0.18),
		CFrame.new(-2.08, 0, -0.31) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel
	)
	Builder.cylinder(
		context,
		"FrontSlingMount",
		Vector3.new(0.10, 0.17, 0.17),
		CFrame.new(1.82, 0, -0.30) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel
	)

	return Builder.finish(context, {
		boltMotor = boltMotor,
		magazineMotor = magazineMotor,
		gripC0 = CFrame.new(0, -0.59, -0.18) * CFrame.Angles(math.rad(-7), math.rad(90), math.rad(-90)),
		muzzlePosition = Vector3.new(5.72, 0, 0.14),
		rightGripPosition = Vector3.new(-0.36, 0, -0.65),
		leftGripPosition = Vector3.new(1.42, 0, -0.09),
		ejectionPosition = Vector3.new(0.20, -0.43, 0.16),
		magazinePosition = Vector3.new(0.35, 0, -0.76),
		muzzleFlashDiameter = 0.46,
	})
end

return table.freeze(Factory)
