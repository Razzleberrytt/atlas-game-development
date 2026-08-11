--!strict

--[[
	Project-original Blackwater Support LMG presentation. A heavy receiver,
	vented barrel jacket, box magazine, carry handle, bipod, reinforced stock,
	and amber support-weapon identity panels give the LMG a distinct silhouette.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)
local Builder = require(script.Parent.WeaponVisualModelBuilder)

type WeaponVisualModelRig = Builder.WeaponVisualModelRig

local Factory = {}

local COLORS = table.freeze({
	black = Color3.fromRGB(24, 25, 24),
	gunmetal = Color3.fromRGB(58, 61, 58),
	steel = Color3.fromRGB(112, 113, 106),
	polymer = Color3.fromRGB(45, 46, 42),
	rubber = Color3.fromRGB(31, 31, 29),
	amber = Color3.fromRGB(176, 112, 38),
	amberBright = Color3.fromRGB(222, 151, 57),
})

function Factory.create(): WeaponVisualModelRig
	local weaponId = FirearmConfig.LightMachineGun.WeaponId
	local context = Builder.newContext(
		weaponId,
		VisualAssetContracts.AssetKeys.WeaponLightMachineGunModel,
		"blackwater-support-lmg.v2",
		"weapon.light-machine-gun"
	)

	Builder.box(context, "Receiver", Vector3.new(1.62, 0.72, 0.72), CFrame.new(0.05, 0, 0.02), COLORS.gunmetal)
	Builder.box(context, "ReceiverTop", Vector3.new(1.48, 0.58, 0.18), CFrame.new(0.08, 0, 0.50), COLORS.black)
	Builder.box(context, "FeedCover", Vector3.new(0.92, 0.64, 0.18), CFrame.new(0.16, 0, 0.63), COLORS.steel)
	Builder.box(context, "RearTrunnion", Vector3.new(0.42, 0.76, 0.74), CFrame.new(-0.92, 0, 0.02), COLORS.black)
	Builder.box(context, "Handguard", Vector3.new(1.18, 0.78, 0.68), CFrame.new(1.34, 0, 0.02), COLORS.polymer)
	for index = 1, 5 do
		Builder.box(
			context,
			"Vent" .. tostring(index),
			Vector3.new(0.10, 0.82, 0.12),
			CFrame.new(0.90 + index * 0.18, 0, 0.38),
			COLORS.black
		)
	end

	Builder.cylinder(context, "HeavyBarrel", Vector3.new(1.65, 0.20, 0.20), CFrame.new(2.45, 0, 0.08), COLORS.black)
	Builder.cylinder(context, "BarrelJacket", Vector3.new(1.15, 0.42, 0.42), CFrame.new(2.10, 0, 0.08), COLORS.gunmetal)
	Builder.cylinder(context, "GasBlock", Vector3.new(0.28, 0.50, 0.50), CFrame.new(2.63, 0, 0.08), COLORS.steel)
	Builder.cylinder(context, "MuzzleBrake", Vector3.new(0.40, 0.36, 0.36), CFrame.new(3.40, 0, 0.08), COLORS.steel)
	Builder.box(context, "MuzzlePortA", Vector3.new(0.18, 0.40, 0.10), CFrame.new(3.38, 0, 0.30), COLORS.black)
	Builder.box(context, "MuzzlePortB", Vector3.new(0.18, 0.40, 0.10), CFrame.new(3.38, 0, -0.14), COLORS.black)

	Builder.box(
		context,
		"PistolGrip",
		Vector3.new(0.42, 0.36, 0.92),
		CFrame.new(-0.50, 0, -0.72) * CFrame.Angles(0, math.rad(8), 0),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	Builder.box(context, "TriggerGuard", Vector3.new(0.30, 0.40, 0.28), CFrame.new(-0.10, 0, -0.48), COLORS.black)
	Builder.box(context, "Trigger", Vector3.new(0.08, 0.08, 0.26), CFrame.new(-0.08, 0, -0.45), COLORS.amber)

	Builder.box(context, "StockCore", Vector3.new(1.42, 0.72, 0.72), CFrame.new(-1.62, 0, 0.00), COLORS.polymer)
	Builder.box(context, "StockComb", Vector3.new(1.04, 0.58, 0.20), CFrame.new(-1.58, 0, 0.49), COLORS.black)
	Builder.box(context, "StockBrace", Vector3.new(0.78, 0.52, 0.30), CFrame.new(-1.70, 0, -0.38), COLORS.gunmetal)
	Builder.box(
		context,
		"StockPad",
		Vector3.new(0.24, 0.82, 0.88),
		CFrame.new(-2.38, 0, 0.00),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)

	local magazine, magazineMotor = Builder.motorBox(
		context,
		"Magazine",
		Vector3.new(0.92, 0.66, 0.92),
		CFrame.new(0.18, 0, -0.92),
		COLORS.black
	)
	Builder.attachBox(context, magazine, "MagazineBody", Vector3.new(0.84, 0.62, 0.72), CFrame.new(0, 0, -0.46), COLORS.gunmetal)
	Builder.attachBox(context, magazine, "MagazineRibA", Vector3.new(0.10, 0.68, 0.66), CFrame.new(-0.26, 0, -0.42), COLORS.steel)
	Builder.attachBox(context, magazine, "MagazineRibB", Vector3.new(0.10, 0.68, 0.66), CFrame.new(0.26, 0, -0.42), COLORS.steel)
	Builder.attachBox(context, magazine, "MagazineFoot", Vector3.new(0.98, 0.72, 0.14), CFrame.new(0, 0, -0.84), COLORS.amber)

	local bolt, boltMotor = Builder.motorBox(
		context,
		"Bolt",
		Vector3.new(0.62, 0.11, 0.22),
		CFrame.new(0.12, -0.44, 0.18),
		COLORS.steel
	)
	Builder.attachBox(context, bolt, "ChargingHandle", Vector3.new(0.18, 0.28, 0.14), CFrame.new(0.10, -0.18, 0.08), COLORS.black)

	Builder.box(context, "TopRail", Vector3.new(1.54, 0.12, 0.10), CFrame.new(0.35, 0, 0.78), COLORS.black)
	Builder.box(context, "RearSight", Vector3.new(0.24, 0.30, 0.30), CFrame.new(-0.45, 0, 0.82), COLORS.black)
	Builder.box(context, "FrontSight", Vector3.new(0.22, 0.28, 0.34), CFrame.new(2.64, 0, 0.55), COLORS.black)
	Builder.box(context, "CarryHandleBase", Vector3.new(0.62, 0.18, 0.16), CFrame.new(0.30, 0, 0.94), COLORS.steel)
	Builder.box(context, "CarryHandle", Vector3.new(0.72, 0.18, 0.18), CFrame.new(0.30, 0, 1.16), COLORS.black)

	Builder.box(context, "BipodMount", Vector3.new(0.34, 0.48, 0.20), CFrame.new(2.18, 0, -0.36), COLORS.steel)
	Builder.box(
		context,
		"BipodLeftLeg",
		Vector3.new(0.18, 0.18, 1.10),
		CFrame.new(2.22, -0.24, -0.90) * CFrame.Angles(math.rad(12), 0, math.rad(-12)),
		COLORS.black
	)
	Builder.box(
		context,
		"BipodRightLeg",
		Vector3.new(0.18, 0.18, 1.10),
		CFrame.new(2.22, 0.24, -0.90) * CFrame.Angles(math.rad(12), 0, math.rad(12)),
		COLORS.black
	)

	Builder.box(context, "IdentityPanel", Vector3.new(0.52, 0.03, 0.30), CFrame.new(0.22, -0.37, 0.08), COLORS.amberBright)
	Builder.box(context, "HeatStripe", Vector3.new(0.68, 0.04, 0.12), CFrame.new(1.44, -0.40, 0.28), COLORS.amber)
	Builder.cylinder(context, "RearSlingMount", Vector3.new(0.12, 0.20, 0.20), CFrame.new(-1.08, 0, 0.38), COLORS.steel)
	Builder.cylinder(context, "FrontSlingMount", Vector3.new(0.12, 0.20, 0.20), CFrame.new(1.74, 0, -0.32), COLORS.steel)

	return Builder.finish(context, {
		boltMotor = boltMotor,
		magazineMotor = magazineMotor,
		gripC0 = CFrame.new(0, -0.58, -0.12) * CFrame.Angles(math.rad(-8), math.rad(90), math.rad(-90)),
		muzzlePosition = Vector3.new(3.62, 0, 0.08),
		rightGripPosition = Vector3.new(-0.50, 0, -0.66),
		leftGripPosition = Vector3.new(1.35, 0, -0.42),
		ejectionPosition = Vector3.new(0.20, -0.48, 0.18),
		magazinePosition = Vector3.new(0.18, 0, -0.92),
		muzzleFlashDiameter = 0.52,
	})
end

return table.freeze(Factory)
