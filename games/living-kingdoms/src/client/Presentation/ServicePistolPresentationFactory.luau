--!strict

--[[
	Project-original Vigil Service Pistol presentation. The moving slide, exposed
	barrel hood, squared duty frame, accessory light, magazine base, and clear
	iron sights make the compact fallback weapon readable without overscaling it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)
local Builder = require(script.Parent.WeaponVisualModelBuilder)

type WeaponVisualModelRig = Builder.WeaponVisualModelRig

local Factory = {}

local COLORS = table.freeze({
	black = Color3.fromRGB(24, 27, 28),
	gunmetal = Color3.fromRGB(58, 64, 66),
	steel = Color3.fromRGB(107, 112, 111),
	polymer = Color3.fromRGB(47, 51, 49),
	rubber = Color3.fromRGB(32, 33, 31),
	blue = Color3.fromRGB(44, 83, 106),
	glass = Color3.fromRGB(77, 119, 132),
	white = Color3.fromRGB(205, 215, 210),
	red = Color3.fromRGB(171, 50, 42),
})

function Factory.create(): WeaponVisualModelRig
	local weaponId = FirearmConfig.ServicePistol.WeaponId
	local context = Builder.newContext(
		weaponId,
		VisualAssetContracts.AssetKeys.WeaponServicePistolModel,
		"vigil-service-pistol.v2",
		"weapon.service-pistol"
	)

	Builder.box(context, "Frame", Vector3.new(0.92, 0.38, 0.44), CFrame.new(0.04, 0, -0.02), COLORS.polymer, Enum.Material.SmoothPlastic)
	Builder.box(context, "DustCover", Vector3.new(0.52, 0.40, 0.24), CFrame.new(0.50, 0, -0.22), COLORS.polymer, Enum.Material.SmoothPlastic)
	Builder.box(context, "AccessoryRail", Vector3.new(0.45, 0.42, 0.08), CFrame.new(0.48, 0, -0.39), COLORS.black)
	for index = 1, 3 do
		Builder.box(
			context,
			"RailSlot" .. tostring(index),
			Vector3.new(0.05, 0.44, 0.10),
			CFrame.new(0.29 + index * 0.12, 0, -0.39),
			COLORS.steel
		)
	end

	Builder.box(
		context,
		"GripCore",
		Vector3.new(0.46, 0.40, 0.92),
		CFrame.new(-0.30, 0, -0.67) * CFrame.Angles(0, math.rad(8), 0),
		COLORS.polymer,
		Enum.Material.SmoothPlastic
	)
	Builder.box(context, "Backstrap", Vector3.new(0.17, 0.42, 0.74), CFrame.new(-0.54, 0, -0.67) * CFrame.Angles(0, math.rad(8), 0), COLORS.rubber, Enum.Material.SmoothPlastic)
	Builder.box(context, "Frontstrap", Vector3.new(0.13, 0.42, 0.64), CFrame.new(-0.08, 0, -0.69) * CFrame.Angles(0, math.rad(8), 0), COLORS.rubber, Enum.Material.SmoothPlastic)
	for index = 1, 4 do
		Builder.box(
			context,
			"GripTexture" .. tostring(index),
			Vector3.new(0.29, 0.43, 0.035),
			CFrame.new(-0.31, 0, -0.39 - index * 0.14) * CFrame.Angles(0, math.rad(8), 0),
			COLORS.black,
			Enum.Material.SmoothPlastic
		)
	end

	Builder.cylinder(
		context,
		"TriggerGuard",
		Vector3.new(0.12, 0.42, 0.42),
		CFrame.new(0.08, 0, -0.36) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.polymer,
		Enum.Material.SmoothPlastic
	)
	Builder.box(context, "Trigger", Vector3.new(0.08, 0.07, 0.28), CFrame.new(0.10, 0, -0.35), COLORS.steel)
	Builder.box(context, "SlideStop", Vector3.new(0.20, 0.07, 0.10), CFrame.new(-0.12, -0.23, 0.08), COLORS.steel)
	Builder.box(context, "TakeDownLever", Vector3.new(0.15, 0.08, 0.10), CFrame.new(0.25, -0.23, -0.02), COLORS.steel)

	local slide, boltMotor = Builder.motorBox(
		context,
		"Bolt",
		Vector3.new(1.24, 0.42, 0.42),
		CFrame.new(0.12, 0, 0.32),
		COLORS.black
	)
	Builder.attachBox(context, slide, "SlideTop", Vector3.new(1.05, 0.34, 0.10), CFrame.new(0, 0, 0.25), COLORS.gunmetal)
	Builder.attachBox(context, slide, "BarrelHood", Vector3.new(0.34, 0.31, 0.12), CFrame.new(0.12, 0, 0.25), COLORS.steel)
	Builder.attachCylinder(context, slide, "Barrel", Vector3.new(0.92, 0.14, 0.14), CFrame.new(0.30, 0, -0.03), COLORS.steel)
	Builder.attachCylinder(context, slide, "MuzzleCrown", Vector3.new(0.11, 0.25, 0.25), CFrame.new(0.68, 0, -0.03), COLORS.gunmetal)
	for index = 1, 4 do
		Builder.attachBox(
			context,
			slide,
			"RearSerration" .. tostring(index),
			Vector3.new(0.045, 0.45, 0.25),
			CFrame.new(-0.50 + index * 0.07, 0, 0),
			COLORS.steel
		)
	end
	Builder.attachBox(context, slide, "RearSight", Vector3.new(0.18, 0.28, 0.22), CFrame.new(-0.45, 0, 0.35), COLORS.black)
	Builder.attachBox(context, slide, "FrontSight", Vector3.new(0.12, 0.19, 0.20), CFrame.new(0.50, 0, 0.35), COLORS.black)
	Builder.attachBox(context, slide, "RearSightDotLeft", Vector3.new(0.04, 0.04, 0.05), CFrame.new(-0.45, 0.08, 0.46), COLORS.white, Enum.Material.Neon)
	Builder.attachBox(context, slide, "RearSightDotRight", Vector3.new(0.04, 0.04, 0.05), CFrame.new(-0.45, -0.08, 0.46), COLORS.white, Enum.Material.Neon)
	Builder.attachBox(context, slide, "FrontSightDot", Vector3.new(0.04, 0.04, 0.05), CFrame.new(0.50, 0, 0.46), COLORS.red, Enum.Material.Neon)

	local magazine, magazineMotor = Builder.motorBox(
		context,
		"Magazine",
		Vector3.new(0.32, 0.30, 0.76),
		CFrame.new(-0.30, 0, -0.72) * CFrame.Angles(0, math.rad(8), 0),
		COLORS.gunmetal
	)
	Builder.attachBox(context, magazine, "MagazineBase", Vector3.new(0.48, 0.43, 0.13), CFrame.new(0, 0, -0.44), COLORS.blue, Enum.Material.SmoothPlastic)
	Builder.attachBox(context, magazine, "MagazineWitness", Vector3.new(0.12, 0.025, 0.35), CFrame.new(0.03, -0.165, 0), COLORS.steel)

	Builder.box(context, "WeaponLightBody", Vector3.new(0.46, 0.34, 0.26), CFrame.new(0.46, 0, -0.55), COLORS.black)
	Builder.cylinder(context, "WeaponLightLens", Vector3.new(0.09, 0.28, 0.28), CFrame.new(0.74, 0, -0.55), COLORS.glass, Enum.Material.Glass)
	Builder.box(context, "WeaponLightSwitch", Vector3.new(0.10, 0.38, 0.12), CFrame.new(0.20, 0, -0.48), COLORS.blue, Enum.Material.SmoothPlastic)

	return Builder.finish(context, {
		boltMotor = boltMotor,
		magazineMotor = magazineMotor,
		gripC0 = CFrame.new(0, -0.36, -0.09) * CFrame.Angles(math.rad(-4), math.rad(90), math.rad(-90)),
		muzzlePosition = Vector3.new(0.86, 0, 0.29),
		rightGripPosition = Vector3.new(-0.30, 0, -0.62),
		leftGripPosition = Vector3.new(0.18, 0, -0.12),
		ejectionPosition = Vector3.new(0.16, -0.28, 0.42),
		magazinePosition = Vector3.new(-0.30, 0, -0.72),
		muzzleFlashDiameter = 0.32,
	})
end

return table.freeze(Factory)
