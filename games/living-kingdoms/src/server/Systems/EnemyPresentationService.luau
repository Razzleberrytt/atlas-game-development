--!strict

--[[
	Presentation-only infected wolf shell for the standard hostile. It preserves
	the existing server-owned footprint and five-motor animation contract while
	replacing the tiny humanoid fallback with a large, readable quadruped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local HordeRolePresentationService = require(script.Parent.HordeRolePresentationService)
local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)

local EnemyPresentationService = {}

local ENEMY_FOLDER_NAME = "EnemyEntities"
local PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"

local COLORS = table.freeze({
	bone = Color3.fromRGB(169, 155, 126),
	armor = Color3.fromRGB(30, 34, 32),
	armorDark = Color3.fromRGB(14, 16, 15),
	flesh = Color3.fromRGB(76, 24, 28),
	claw = Color3.fromRGB(151, 132, 98),
	sensor = Color3.fromRGB(255, 28, 22),
	fur = Color3.fromRGB(47, 51, 45),
	furDark = Color3.fromRGB(25, 29, 27),
})

local started = false
local childAddedConnection: RBXScriptConnection? = nil

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

local function createPart(
	presentation: Model,
	authoritativeRoot: BasePart,
	name: string,
	size: Vector3,
	rootLocalCFrame: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	configurePart(part, name, color, material)
	part.Size = size
	part:SetAttribute("HordeRoleBaseSize", size)
	if shape ~= nil then
		part.Shape = shape
	end
	part.CFrame = authoritativeRoot.CFrame * rootLocalCFrame
	part.Parent = presentation
	return part
end

local function makeRigidPart(
	presentation: Model,
	authoritativeRoot: BasePart,
	weldParent: BasePart,
	name: string,
	size: Vector3,
	rootLocalCFrame: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = createPart(presentation, authoritativeRoot, name, size, rootLocalCFrame, color, material, shape)
	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = weldParent
	weld.Part1 = part
	weld.Parent = weldParent
	return part
end

local function makeMotorPart(
	presentation: Model,
	authoritativeRoot: BasePart,
	motorParent: BasePart,
	name: string,
	motorName: string,
	size: Vector3,
	rootLocalCFrame: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = createPart(presentation, authoritativeRoot, name, size, rootLocalCFrame, color, material, nil)
	local motor = Instance.new("Motor6D")
	motor.Name = motorName
	motor.Part0 = motorParent
	motor.Part1 = part
	motor.C0 = motorParent.CFrame:ToObjectSpace(part.CFrame)
	motor:SetAttribute("HordeRoleBaseC0", motor.C0)
	motor.C1 = CFrame.new()
	motor.Parent = motorParent
	return part
end

local function createPresentation(root: BasePart): Model
	local presentation = Instance.new("Model")
	presentation.Name = PRESENTATION_MODEL_NAME
	presentation:SetAttribute("VisualAssetKey", VisualAssetContracts.AssetKeys.EnemyStandardHostileModel)
	presentation:SetAttribute("VisualCandidateId", "blackwater-infected-wolf.v1")
	presentation:SetAttribute("VisualStatus", "ProceduralFallback")
	presentation:SetAttribute("GameplayFootprintId", "enemy.exclusion_walker")
	presentation:SetAttribute("PresentationMotorCount", 5)

	local body = makeMotorPart(
		presentation,
		root,
		root,
		"TorsoCore",
		"TorsoMotor",
		Vector3.new(2.25, 1.65, 4.15),
		CFrame.new(0, 0.15, 0.25),
		COLORS.fur,
		Enum.Material.Slate
	)
	body.Shape = Enum.PartType.Ball
	local chest = makeRigidPart(
		presentation,
		root,
		body,
		"ShoulderMass",
		Vector3.new(2.55, 1.85, 1.75),
		CFrame.new(0, 0.35, -1.15),
		COLORS.furDark,
		Enum.Material.Slate,
		nil
	)
	chest.Shape = Enum.PartType.Ball
	local neck = makeRigidPart(
		presentation,
		root,
		body,
		"Neck",
		Vector3.new(1.45, 1.45, 1.75),
		CFrame.new(0, 0.72, -2.0) * CFrame.Angles(math.rad(-18), 0, 0),
		COLORS.furDark,
		Enum.Material.Slate,
		nil
	)
	neck.Shape = Enum.PartType.Ball
	local head = makeRigidPart(
		presentation,
		root,
		body,
		"Head",
		Vector3.new(1.55, 1.25, 1.75),
		CFrame.new(0, 0.88, -2.72),
		COLORS.furDark,
		Enum.Material.Slate,
		nil
	)
	head.Shape = Enum.PartType.Ball
	local muzzle = makeRigidPart(
		presentation,
		root,
		body,
		"Muzzle",
		Vector3.new(0.92, 0.68, 1.25),
		CFrame.new(0, 0.58, -3.62),
		COLORS.armorDark,
		Enum.Material.Slate,
		nil
	)
	muzzle.Shape = Enum.PartType.Ball
	for side = -1, 1, 2 do
		makeRigidPart(
			presentation,
			root,
			body,
			if side < 0 then "EarLeft" else "EarRight",
			Vector3.new(0.38, 0.72, 0.32),
			CFrame.new(side * 0.52, 1.67, -2.72) * CFrame.Angles(math.rad(-12), 0, math.rad(side * -16)),
			COLORS.furDark,
			Enum.Material.Slate,
			nil
		)
		makeRigidPart(
			presentation,
			root,
			body,
			if side < 0 then "FangLeft" else "FangRight",
			Vector3.new(0.13, 0.34, 0.13),
			CFrame.new(side * 0.28, 0.20, -4.02) * CFrame.Angles(math.rad(10), 0, 0),
			COLORS.claw,
			Enum.Material.SmoothPlastic,
			nil
		)
	end
	local sensor = makeRigidPart(
		presentation,
		root,
		body,
		"Sensor",
		Vector3.new(0.92, 0.14, 0.22),
		CFrame.new(0, 1.08, -3.52),
		COLORS.sensor,
		Enum.Material.Neon,
		nil
	)
	local eyeGlow = Instance.new("PointLight")
	eyeGlow.Name = "EyeGlow"
	eyeGlow.Color = Color3.fromRGB(255, 34, 26)
	eyeGlow.Brightness = 2.6
	eyeGlow.Range = 8.5
	eyeGlow.Shadows = false
	eyeGlow.Parent = sensor
	for index = -1, 2 do
		makeRigidPart(
			presentation,
			root,
			body,
			"DorsalSpine" .. tostring(index + 2),
			Vector3.new(0.20, 0.65, 0.42),
			CFrame.new(0, 1.16, index * 0.78) * CFrame.Angles(math.rad(-18), 0, 0),
			COLORS.bone,
			Enum.Material.Slate,
			nil
		)
	end

	local forearmLeft = makeMotorPart(
		presentation,
		root,
		body,
		"FrontLegLeft",
		"ForearmLeftMotor",
		Vector3.new(0.58, 1.85, 0.68),
		CFrame.new(-0.86, -1.15, -1.25) * CFrame.Angles(math.rad(-5), 0, 0),
		COLORS.furDark,
		Enum.Material.Slate
	)
	local forearmRight = makeMotorPart(
		presentation,
		root,
		body,
		"FrontLegRight",
		"ForearmRightMotor",
		Vector3.new(0.58, 1.85, 0.68),
		CFrame.new(0.86, -1.15, -1.25) * CFrame.Angles(math.rad(-5), 0, 0),
		COLORS.furDark,
		Enum.Material.Slate
	)
	forearmLeft.Shape = Enum.PartType.Ball
	forearmRight.Shape = Enum.PartType.Ball
	makeRigidPart(
		presentation,
		root,
		forearmLeft,
		"FrontPawLeft",
		Vector3.new(0.72, 0.38, 1.05),
		CFrame.new(-0.86, -2.05, -1.58),
		COLORS.claw,
		Enum.Material.Slate,
		nil
	)
	makeRigidPart(
		presentation,
		root,
		forearmRight,
		"FrontPawRight",
		Vector3.new(0.72, 0.38, 1.05),
		CFrame.new(0.86, -2.05, -1.58),
		COLORS.claw,
		Enum.Material.Slate,
		nil
	)
	local legLeft = makeMotorPart(
		presentation,
		root,
		root,
		"LegLeft",
		"LegLeftMotor",
		Vector3.new(0.68, 1.75, 0.78),
		CFrame.new(-0.82, -1.08, 1.45) * CFrame.Angles(math.rad(8), 0, 0),
		COLORS.fur,
		Enum.Material.Slate
	)
	local legRight = makeMotorPart(
		presentation,
		root,
		root,
		"LegRight",
		"LegRightMotor",
		Vector3.new(0.68, 1.75, 0.78),
		CFrame.new(0.82, -1.08, 1.45) * CFrame.Angles(math.rad(8), 0, 0),
		COLORS.fur,
		Enum.Material.Slate
	)
	legLeft.Shape = Enum.PartType.Ball
	legRight.Shape = Enum.PartType.Ball
	makeRigidPart(
		presentation,
		root,
		legLeft,
		"RearPawLeft",
		Vector3.new(0.78, 0.42, 1.12),
		CFrame.new(-0.82, -1.98, 1.12),
		COLORS.armor,
		Enum.Material.CorrodedMetal,
		nil
	)
	makeRigidPart(
		presentation,
		root,
		legRight,
		"RearPawRight",
		Vector3.new(0.78, 0.42, 1.12),
		CFrame.new(0.82, -1.98, 1.12),
		COLORS.armor,
		Enum.Material.CorrodedMetal,
		nil
	)
	local tail = makeRigidPart(
		presentation,
		root,
		body,
		"Tail",
		Vector3.new(0.48, 0.48, 2.75),
		CFrame.new(0, 0.42, 3.05) * CFrame.Angles(math.rad(-16), 0, 0),
		COLORS.furDark,
		Enum.Material.Slate,
		nil
	)
	tail.Shape = Enum.PartType.Ball
	makeRigidPart(
		presentation,
		root,
		body,
		"ExposedRib",
		Vector3.new(2.35, 0.16, 1.5),
		CFrame.new(0, 0.58, 0.18) * CFrame.Angles(0, 0, math.rad(8)),
		COLORS.flesh,
		Enum.Material.CorrodedMetal,
		nil
	)

	presentation.PrimaryPart = body
	return presentation
end

local function attachPresentation(enemyModel: Model)
	if enemyModel:GetAttribute("EnemyArchetypeId") ~= EnemyConfig.Walker.ArchetypeId then
		return
	end
	if enemyModel:FindFirstChild(PRESENTATION_MODEL_NAME) ~= nil then
		return
	end
	local root = enemyModel:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	-- Preserve the authoritative root and its server-controlled alive/dead color
	-- as a faint inner core while the fixed visual shell supplies the silhouette.
	root.Transparency = 0.88
	root.Material = Enum.Material.Neon
	root.CastShadow = false

	local attackOrigin = root:FindFirstChild("AttackOrigin")
	if attackOrigin == nil then
		local attachment = Instance.new("Attachment")
		attachment.Name = "AttackOrigin"
		attachment.Position = Vector3.new(0, 0.8, -1.55)
		attachment.Parent = root
	end

	local presentation = createPresentation(root)
	presentation.Parent = enemyModel
	HordeRolePresentationService.applyRolePresentation(enemyModel)
end

function EnemyPresentationService.start()
	if started then
		return
	end
	started = true

	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	assert(folder ~= nil and folder:IsA("Folder"), "EnemyPresentationService must start after EnemyDirectorService")
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			attachPresentation(child)
		end
	end
	childAddedConnection = folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			attachPresentation(child)
		end
	end)
end

function EnemyPresentationService.stop()
	if not started then
		return
	end
	started = false
	if childAddedConnection ~= nil then
		childAddedConnection:Disconnect()
		childAddedConnection = nil
	end
end

return table.freeze(EnemyPresentationService)
