--!strict

--[[
	Project-original Razor Compact SMG presentation. A short barrel shroud,
	folding wire stock, compact optic, vertical foregrip, curved magazine, and
	blue identification panels communicate speed and close-range horde control.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)
local Builder = require(script.Parent.WeaponVisualModelBuilder)

type WeaponVisualModelRig = Builder.WeaponVisualModelRig

local Factory = {}

local COLORS = table.freeze({
	black = Color3.fromRGB(24, 27, 28),
	gunmetal = Color3.fromRGB(55, 61, 62),
	steel = Color3.fromRGB(100, 106, 105),
	polymer = Color3.fromRGB(43, 47, 46),
	rubber = Color3.fromRGB(31, 33, 31),
	blue = Color3.fromRGB(42, 86, 116),
	blueBright = Color3.fromRGB(55, 123, 160),
	glass = Color3.fromRGB(71, 124, 139),
	orange = Color3.fromRGB(190, 83, 38),
})

function Factory.create(): WeaponVisualModelRig
	local weaponId = FirearmConfig.SubmachineGun.WeaponId
	local context = Builder.newContext(
		weaponId,
		VisualAssetContracts.AssetKeys.WeaponSubmachineGunModel,
		"razor-compact-smg.v2",
		"weapon.submachine-gun"
	)

	Builder.box(context, "Receiver", Vector3.new(1.12, 0.56, 0.58), CFrame.new(0.08, 0, 0.05), COLORS.gunmetal)
	Builder.box(context, "UpperReceiver", Vector3.new(1.00, 0.50, 0.16), CFrame.new(0.10, 0, 0.43), COLORS.black)
	Builder.box(context, "LowerReceiver", Vector3.new(0.78, 0.50, 0.24), CFrame.new(-0.02, 0, -0.33), COLORS.polymer, Enum.Material.SmoothPlastic)
	Builder.box(context, "Handguard", Vector3.new(0.82, 0.59, 0.54), CFrame.new(0.98, 0, 0.03), COLORS.polymer, Enum.Material.SmoothPlastic)
	for index = 1, 4 do
		Builder.box(
			context,
			"HandguardPort" .. tostring(index),
			Vector3.new(0.10, 0.62, 0.08),
			CFrame.new(0.67 + index * 0.15, 0, 0.32),
			COLORS.black
		)
	end

	Builder.cylinder(context, "Barrel", Vector3.new(0.84, 0.16, 0.16), CFrame.new(1.69, 0, 0.13), COLORS.black)
	Builder.cylinder(context, "BarrelShroud", Vector3.new(0.62, 0.34, 0.34), CFrame.new(1.52, 0, 0.13), COLORS.gunmetal)
	Builder.cylinder(context, "MuzzleDevice", Vector3.new(0.30, 0.31, 0.31), CFrame.new(2.23, 0, 0.13), COLORS.steel)
	Builder.box(context, "MuzzlePortTop", Vector3.new(0.18, 0.34, 0.08), CFrame.new(2.23, 0, 0.34), COLORS.black)
	Builder.box(context, "MuzzlePortBottom", Vector3.new(0.18, 0.34, 0.08), CFrame.new(2.23, 0, -0.08), COLORS.black)

	Builder.box(
		context,
		"PistolGrip",
		Vector3.new(0.36, 0.32, 0.78),
		CFrame.new(-0.29, 0, -0.68) * CFrame.Angles(0, math.rad(10), 0),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	Builder.box(context, "GripAccent", Vector3.new(0.22, 0.34, 0.36), CFrame.new(-0.31, 0, -0.76), COLORS.blue, Enum.Material.SmoothPlastic)
	Builder.cylinder(
		context,
		"TriggerGuard",
		Vector3.new(0.11, 0.38, 0.38),
		CFrame.new(0.02, 0, -0.42) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.black
	)
	Builder.box(context, "Trigger", Vector3.new(0.08, 0.06, 0.25), CFrame.new(0.03, 0, -0.39), COLORS.orange)

	Builder.box(context, "StockHinge", Vector3.new(0.26, 0.44, 0.42), CFrame.new(-0.66, 0, 0.03), COLORS.steel)
	Builder.box(context, "StockTopRail", Vector3.new(1.02, 0.10, 0.10), CFrame.new(-1.18, 0.18, 0.20), COLORS.black)
	Builder.box(context, "StockBottomRail", Vector3.new(1.02, 0.10, 0.10), CFrame.new(-1.18, -0.18, -0.14), COLORS.black)
	Builder.box(context, "StockBrace", Vector3.new(0.12, 0.42, 0.54), CFrame.new(-1.70, 0, 0.02), COLORS.gunmetal)
	Builder.box(context, "StockPad", Vector3.new(0.18, 0.48, 0.64), CFrame.new(-1.82, 0, 0.02), COLORS.rubber, Enum.Material.SmoothPlastic)

	local magazine, magazineMotor = Builder.motorBox(
		context,
		"Magazine",
		Vector3.new(0.38, 0.34, 0.72),
		CFrame.new(0.20, 0, -0.78) * CFrame.Angles(0, math.rad(-5), 0),
		COLORS.black
	)
	local lowerMagazine = Builder.attachBox(
		context,
		magazine,
		"MagazineLower",
		Vector3.new(0.34, 0.32, 0.58),
		CFrame.new(-0.10, 0, -0.56) * CFrame.Angles(0, math.rad(-10), 0),
		COLORS.gunmetal
	)
	Builder.attachBox(
		context,
		lowerMagazine,
		"MagazineFoot",
		Vector3.new(0.46, 0.38, 0.14),
		CFrame.new(-0.08, 0, -0.36) * CFrame.Angles(0, math.rad(-4), 0),
		COLORS.blue,
		Enum.Material.SmoothPlastic
	)
	Builder.attachBox(context, magazine, "MagazineRib", Vector3.new(0.09, 0.36, 0.52), CFrame.new(0.13, 0, 0.04), COLORS.steel)

	local bolt, boltMotor = Builder.motorBox(
		context,
		"Bolt",
		Vector3.new(0.52, 0.09, 0.20),
		CFrame.new(0.16, -0.34, 0.15),
		COLORS.steel
	)
	Builder.attachBox(context, bolt, "ChargingHandle", Vector3.new(0.16, 0.22, 0.12), CFrame.new(-0.06, -0.14, 0.10), COLORS.black)

	Builder.box(context, "TopRail", Vector3.new(1.28, 0.12, 0.09), CFrame.new(0.28, 0, 0.61), COLORS.black)
	Builder.box(context, "OpticMount", Vector3.new(0.38, 0.34, 0.18), CFrame.new(0.20, 0, 0.76), COLORS.black)
	Builder.box(context, "ReflexBody", Vector3.new(0.42, 0.38, 0.34), CFrame.new(0.20, 0, 0.94), COLORS.gunmetal)
	Builder.box(context, "ReflexWindow", Vector3.new(0.08, 0.30, 0.26), CFrame.new(0.43, 0, 0.96), COLORS.glass, Enum.Material.Glass)
	Builder.box(context, "RearSight", Vector3.new(0.17, 0.22, 0.27), CFrame.new(-0.34, 0, 0.74), COLORS.black)
	Builder.box(context, "FrontSight", Vector3.new(0.15, 0.19, 0.31), CFrame.new(1.38, 0, 0.52), COLORS.black)

	Builder.box(context, "VerticalForegrip", Vector3.new(0.28, 0.28, 0.66), CFrame.new(0.99, 0, -0.53), COLORS.rubber, Enum.Material.SmoothPlastic)
	Builder.box(context, "ForegripStop", Vector3.new(0.36, 0.34, 0.15), CFrame.new(0.99, 0, -0.88), COLORS.blue, Enum.Material.SmoothPlastic)
	Builder.box(context, "IdentityPanel", Vector3.new(0.45, 0.025, 0.28), CFrame.new(0.02, -0.292, 0.07), COLORS.blueBright, Enum.Material.SmoothPlastic)
	Builder.box(context, "FireSelector", Vector3.new(0.13, 0.08, 0.13), CFrame.new(-0.27, -0.30, -0.10), COLORS.orange, Enum.Material.SmoothPlastic)
	Builder.cylinder(
		context,
		"RearSlingMount",
		Vector3.new(0.10, 0.18, 0.18),
		CFrame.new(-0.74, 0, 0.32) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel
	)
	Builder.cylinder(
		context,
		"FrontSlingMount",
		Vector3.new(0.10, 0.17, 0.17),
		CFrame.new(1.19, 0, -0.31) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel
	)

	return Builder.finish(context, {
		boltMotor = boltMotor,
		magazineMotor = magazineMotor,
		gripC0 = CFrame.new(0, -0.53, -0.14) * CFrame.Angles(math.rad(-7), math.rad(90), math.rad(-90)),
		muzzlePosition = Vector3.new(2.44, 0, 0.13),
		rightGripPosition = Vector3.new(-0.29, 0, -0.64),
		leftGripPosition = Vector3.new(0.98, 0, -0.46),
		ejectionPosition = Vector3.new(0.18, -0.40, 0.16),
		magazinePosition = Vector3.new(0.20, 0, -0.78),
		muzzleFlashDiameter = 0.38,
	})
end

return table.freeze(Factory)
