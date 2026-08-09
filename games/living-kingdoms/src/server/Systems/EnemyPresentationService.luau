--!strict

--[[
	Presentation-only Exclusion Stalker shell for the standard hostile. It keeps
	the existing server-owned footprint and five-motor animation contract while
	replacing the repeated wolf crowd with a tall, hunched corrupted scavenger.
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
	bone = Color3.fromRGB(207, 198, 159),
	armor = Color3.fromRGB(45, 61, 52),
	armorDark = Color3.fromRGB(17, 24, 21),
	flesh = Color3.fromRGB(137, 42, 53),
	claw = Color3.fromRGB(211, 189, 129),
	radiation = Color3.fromRGB(154, 255, 55),
	necrosis = Color3.fromRGB(66, 91, 56),
	cloth = Color3.fromRGB(67, 73, 60),
	clothDark = Color3.fromRGB(29, 36, 31),
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
	presentation:SetAttribute("VisualCandidateId", "exclusion-stalker.procedural-v1")
	presentation:SetAttribute("VisualStatus", "ProceduralFallback")
	presentation:SetAttribute("GameplayFootprintId", "enemy.exclusion_walker")
	presentation:SetAttribute("PresentationMotorCount", 5)

	local body = makeMotorPart(
		presentation,
		root,
		root,
		"TorsoCore",
		"TorsoMotor",
		Vector3.new(2.35, 2.85, 1.35),
		CFrame.new(0, 0.45, 0.15) * CFrame.Angles(math.rad(-12), 0, 0),
		COLORS.flesh,
		Enum.Material.Slate
	)
	body.Shape = Enum.PartType.Ball
	local ribCage = makeRigidPart(
		presentation,
		root,
		body,
		"RibCage",
		Vector3.new(2.15, 1.85, 1.52),
		CFrame.new(0, 0.72, -0.08) * CFrame.Angles(math.rad(-10), 0, 0),
		COLORS.bone,
		Enum.Material.Slate,
		nil
	)
	ribCage.Shape = Enum.PartType.Ball
	makeRigidPart(
		presentation,
		root,
		body,
		"ChestPlate",
		Vector3.new(2.42, 1.25, 0.24),
		CFrame.new(0, 0.72, -0.82) * CFrame.Angles(math.rad(-10), 0, 0),
		COLORS.armor,
		Enum.Material.CorrodedMetal,
		nil
	)
	local head = makeRigidPart(
		presentation,
		root,
		body,
		"Head",
		Vector3.new(1.35, 1.55, 1.2),
		CFrame.new(0, 2.05, -0.52) * CFrame.Angles(math.rad(-17), 0, 0),
		COLORS.bone,
		Enum.Material.Slate,
		nil
	)
	head.Shape = Enum.PartType.Ball
	local sensor = makeRigidPart(
		presentation,
		root,
		body,
		"Sensor",
		Vector3.new(0.78, 0.28, 0.16),
		CFrame.new(0, 2.15, -1.14) * CFrame.Angles(math.rad(-17), 0, 0),
		COLORS.radiation,
		Enum.Material.Neon,
		nil
	)
	local eyeGlow = Instance.new("PointLight")
	eyeGlow.Name = "EyeGlow"
	eyeGlow.Color = COLORS.radiation
	eyeGlow.Brightness = 2.2
	eyeGlow.Range = 8
	eyeGlow.Shadows = false
	eyeGlow.Parent = sensor
	makeRigidPart(
		presentation,
		root,
		body,
		"OpenChestWound",
		Vector3.new(0.72, 0.95, 0.16),
		CFrame.new(0.32, 0.34, -0.92) * CFrame.Angles(math.rad(-10), 0, math.rad(11)),
		COLORS.flesh,
		Enum.Material.Neon,
		nil
	)
	for spineIndex = 1, 3 do
		makeRigidPart(
			presentation,
			root,
			body,
			"DorsalSpine" .. tostring(spineIndex),
			Vector3.new(0.2, 0.6 + spineIndex * 0.08, 0.3),
			CFrame.new(0, 1.45 - spineIndex * 0.7, 0.86) * CFrame.Angles(math.rad(-22), 0, 0),
			COLORS.bone,
			Enum.Material.Slate,
			nil
		)
	end
	for side = -1, 1, 2 do
		makeRigidPart(
			presentation,
			root,
			body,
			if side < 0 then "ShoulderLeft" else "ShoulderRight",
			Vector3.new(0.88, 0.9, 0.92),
			CFrame.new(side * 1.18, 1.18, -0.02) * CFrame.Angles(0, 0, math.rad(side * 12)),
			COLORS.armor,
			Enum.Material.CorrodedMetal,
			nil
		)
	end
	local forearmLeft = makeMotorPart(
		presentation,
		root,
		body,
		"ForearmLeft",
		"ForearmLeftMotor",
		Vector3.new(0.62, 2.75, 0.68),
		CFrame.new(-1.48, -0.25, -0.15) * CFrame.Angles(math.rad(-10), 0, math.rad(-8)),
		COLORS.clothDark,
		Enum.Material.Slate
	)
	local forearmRight = makeMotorPart(
		presentation,
		root,
		body,
		"ForearmRight",
		"ForearmRightMotor",
		Vector3.new(0.62, 2.75, 0.68),
		CFrame.new(1.48, -0.25, -0.15) * CFrame.Angles(math.rad(-10), 0, math.rad(8)),
		COLORS.clothDark,
		Enum.Material.Slate
	)
	forearmLeft.Shape = Enum.PartType.Ball
	forearmRight.Shape = Enum.PartType.Ball
	makeRigidPart(
		presentation,
		root,
		forearmLeft,
		"ClawLeft",
		Vector3.new(0.82, 0.42, 0.92),
		CFrame.new(-1.68, -1.7, -0.42),
		COLORS.claw,
		Enum.Material.SmoothPlastic,
		nil
	)
	makeRigidPart(
		presentation,
		root,
		forearmRight,
		"ClawRight",
		Vector3.new(0.82, 0.42, 0.92),
		CFrame.new(1.68, -1.7, -0.42),
		COLORS.claw,
		Enum.Material.SmoothPlastic,
		nil
	)
	makeRigidPart(
		presentation,
		root,
		body,
		"HipGuard",
		Vector3.new(2.05, 0.72, 1.16),
		CFrame.new(0, -1.12, 0.32),
		COLORS.armorDark,
		Enum.Material.CorrodedMetal,
		nil
	)
	local legLeft = makeMotorPart(
		presentation,
		root,
		root,
		"LegLeft",
		"LegLeftMotor",
		Vector3.new(0.72, 2.25, 0.82),
		CFrame.new(-0.68, -1.55, 0.28) * CFrame.Angles(math.rad(5), 0, 0),
		COLORS.cloth,
		Enum.Material.Slate
	)
	local legRight = makeMotorPart(
		presentation,
		root,
		root,
		"LegRight",
		"LegRightMotor",
		Vector3.new(0.72, 2.25, 0.82),
		CFrame.new(0.68, -1.55, 0.28) * CFrame.Angles(math.rad(5), 0, 0),
		COLORS.cloth,
		Enum.Material.Slate
	)
	legLeft.Shape = Enum.PartType.Ball
	legRight.Shape = Enum.PartType.Ball
	makeRigidPart(
		presentation,
		root,
		legLeft,
		"FootLeft",
		Vector3.new(0.88, 0.46, 1.35),
		CFrame.new(-0.68, -2.72, -0.08),
		COLORS.armor,
		Enum.Material.CorrodedMetal,
		nil
	)
	makeRigidPart(
		presentation,
		root,
		legRight,
		"FootRight",
		Vector3.new(0.88, 0.46, 1.35),
		CFrame.new(0.68, -2.72, -0.08),
		COLORS.armor,
		Enum.Material.CorrodedMetal,
		nil
	)
	makeRigidPart(
		presentation,
		root,
		body,
		"BackCanister",
		Vector3.new(1.05, 1.75, 0.72),
		CFrame.new(0, 0.45, 0.98) * CFrame.Angles(math.rad(-10), 0, 0),
		COLORS.necrosis,
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
