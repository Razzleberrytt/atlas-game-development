--!strict

--[[
	Project-original Morrow Breach Shotgun presentation. The broad receiver,
	vented heat shield, box magazine, shell rack, and aggressive pump silhouette
	make its close-range role readable from the elevated isometric camera.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)
local Builder = require(script.Parent.WeaponVisualModelBuilder)

type WeaponVisualModelRig = Builder.WeaponVisualModelRig

local Factory = {}

local COLORS = table.freeze({
	black = Color3.fromRGB(28, 31, 32),
	steel = Color3.fromRGB(91, 98, 98),
	gunmetal = Color3.fromRGB(55, 61, 62),
	wood = Color3.fromRGB(105, 66, 40),
	woodDark = Color3.fromRGB(72, 43, 29),
	rubber = Color3.fromRGB(36, 35, 31),
	red = Color3.fromRGB(145, 47, 37),
	brass = Color3.fromRGB(172, 124, 48),
	shell = Color3.fromRGB(138, 38, 31),
})

function Factory.create(): WeaponVisualModelRig
	local weaponId = FirearmConfig.BreachShotgun.WeaponId
	local context = Builder.newContext(
		weaponId,
		VisualAssetContracts.AssetKeys.WeaponBreachShotgunModel,
		"morrow-breach-shotgun.v2",
		"weapon.breach-shotgun"
	)

	Builder.box(context, "Receiver", Vector3.new(1.42, 0.62, 0.66), CFrame.new(0.05, 0, 0.04), COLORS.gunmetal)
	Builder.box(context, "ReceiverTop", Vector3.new(1.15, 0.54, 0.16), CFrame.new(0.12, 0, 0.46), COLORS.black)
	Builder.box(context, "EjectionHousing", Vector3.new(0.56, 0.10, 0.30), CFrame.new(0.18, -0.36, 0.17), COLORS.steel)
	Builder.box(context, "Handguard", Vector3.new(1.18, 0.55, 0.54), CFrame.new(1.33, 0, 0.01), COLORS.black)
	Builder.box(context, "HeatShield", Vector3.new(1.52, 0.58, 0.12), CFrame.new(1.62, 0, 0.47), COLORS.gunmetal)
	for index = 1, 5 do
		Builder.box(
			context,
			"HeatVent" .. tostring(index),
			Vector3.new(0.16, 0.61, 0.045),
			CFrame.new(1.08 + index * 0.23, 0, 0.545),
			COLORS.black
		)
	end

	Builder.cylinder(context, "Barrel", Vector3.new(2.18, 0.22, 0.22), CFrame.new(2.42, 0, 0.19), COLORS.black)
	Builder.cylinder(context, "MagazineTube", Vector3.new(1.76, 0.20, 0.20), CFrame.new(2.17, 0, -0.16), COLORS.steel)
	Builder.cylinder(context, "MuzzleCollar", Vector3.new(0.34, 0.34, 0.34), CFrame.new(3.66, 0, 0.19), COLORS.steel)
	Builder.cylinder(context, "TubeCap", Vector3.new(0.24, 0.28, 0.28), CFrame.new(3.30, 0, -0.16), COLORS.red)

	Builder.box(context, "StockNeck", Vector3.new(0.64, 0.40, 0.40), CFrame.new(-0.89, 0, 0.02), COLORS.woodDark, Enum.Material.Wood)
	Builder.wedge(
		context,
		"StockBody",
		Vector3.new(1.12, 0.58, 0.76),
		CFrame.new(-1.55, 0, 0.01) * CFrame.Angles(0, math.rad(180), 0),
		COLORS.wood,
		Enum.Material.Wood
	)
	Builder.box(context, "ButtPad", Vector3.new(0.18, 0.64, 0.78), CFrame.new(-2.14, 0, -0.01), COLORS.rubber, Enum.Material.SmoothPlastic)
	Builder.box(
		context,
		"PistolGrip",
		Vector3.new(0.34, 0.31, 0.78),
		CFrame.new(-0.30, 0, -0.69) * CFrame.Angles(0, math.rad(10), 0),
		COLORS.rubber,
		Enum.Material.SmoothPlastic
	)
	Builder.cylinder(
		context,
		"TriggerGuard",
		Vector3.new(0.12, 0.38, 0.38),
		CFrame.new(-0.02, 0, -0.43) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.black
	)
	Builder.box(context, "Trigger", Vector3.new(0.08, 0.07, 0.25), CFrame.new(0, 0, -0.40), COLORS.brass)

	local magazine, magazineMotor = Builder.motorBox(
		context,
		"Magazine",
		Vector3.new(0.54, 0.46, 0.92),
		CFrame.new(0.40, 0, -0.88) * CFrame.Angles(0, math.rad(-4), 0),
		COLORS.black
	)
	Builder.attachBox(context, magazine, "MagazineFrontRib", Vector3.new(0.10, 0.49, 0.72), CFrame.new(0.27, 0, 0), COLORS.red)
	Builder.attachBox(context, magazine, "MagazineBase", Vector3.new(0.64, 0.50, 0.14), CFrame.new(0, 0, -0.52), COLORS.rubber, Enum.Material.SmoothPlastic)
	Builder.attachBox(context, magazine, "MagazineWitness", Vector3.new(0.28, 0.025, 0.42), CFrame.new(0.06, -0.242, 0.05), COLORS.steel)

	local bolt, boltMotor = Builder.motorBox(
		context,
		"Bolt",
		Vector3.new(0.58, 0.09, 0.24),
		CFrame.new(0.18, -0.37, 0.17),
		COLORS.steel
	)
	Builder.attachBox(context, bolt, "ChargingHandle", Vector3.new(0.18, 0.25, 0.12), CFrame.new(0.10, -0.15, 0), COLORS.black)

	Builder.box(context, "Pump", Vector3.new(0.78, 0.61, 0.52), CFrame.new(1.50, 0, -0.02), COLORS.woodDark, Enum.Material.Wood)
	for index = 1, 4 do
		Builder.box(
			context,
			"PumpRib" .. tostring(index),
			Vector3.new(0.055, 0.64, 0.55),
			CFrame.new(1.20 + index * 0.13, 0, -0.02),
			COLORS.rubber,
			Enum.Material.SmoothPlastic
		)
	end

	Builder.box(context, "TopRail", Vector3.new(1.18, 0.12, 0.09), CFrame.new(0.22, 0, 0.61), COLORS.black)
	Builder.box(context, "RearSight", Vector3.new(0.20, 0.25, 0.27), CFrame.new(-0.20, 0, 0.76), COLORS.black)
	Builder.box(context, "FrontSight", Vector3.new(0.16, 0.20, 0.34), CFrame.new(2.95, 0, 0.48), COLORS.black)
	Builder.cylinder(context, "SideLight", Vector3.new(0.62, 0.23, 0.23), CFrame.new(1.74, 0.38, -0.08), COLORS.gunmetal)
	Builder.cylinder(context, "SideLightLens", Vector3.new(0.08, 0.25, 0.25), CFrame.new(2.09, 0.38, -0.08), COLORS.red, Enum.Material.Neon)

	Builder.box(context, "ShellRack", Vector3.new(0.78, 0.10, 0.35), CFrame.new(-0.05, 0.38, 0.06), COLORS.black)
	for index = 1, 4 do
		local x = -0.31 + index * 0.16
		Builder.cylinder(
			context,
			"RackShell" .. tostring(index),
			Vector3.new(0.30, 0.12, 0.12),
			CFrame.new(x, 0.44, 0.08),
			COLORS.shell
		)
		Builder.cylinder(
			context,
			"RackBrass" .. tostring(index),
			Vector3.new(0.06, 0.13, 0.13),
			CFrame.new(x + 0.15, 0.44, 0.08),
			COLORS.brass
		)
	end

	Builder.cylinder(
		context,
		"RearSlingMount",
		Vector3.new(0.10, 0.18, 0.18),
		CFrame.new(-1.91, 0, -0.30) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel
	)
	Builder.cylinder(
		context,
		"FrontSlingMount",
		Vector3.new(0.10, 0.17, 0.17),
		CFrame.new(2.37, 0, -0.31) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.steel
	)

	return Builder.finish(context, {
		boltMotor = boltMotor,
		magazineMotor = magazineMotor,
		gripC0 = CFrame.new(0, -0.57, -0.16) * CFrame.Angles(math.rad(-8), math.rad(90), math.rad(-90)),
		muzzlePosition = Vector3.new(3.92, 0, 0.19),
		rightGripPosition = Vector3.new(-0.30, 0, -0.65),
		leftGripPosition = Vector3.new(1.52, 0, -0.12),
		ejectionPosition = Vector3.new(0.22, -0.42, 0.18),
		magazinePosition = Vector3.new(0.40, 0, -0.88),
		muzzleFlashDiameter = 0.52,
	})
end

return table.freeze(Factory)
