--!strict

--[[
	Presentation-only procedural model coverage for authoritative enemy archetypes
	that do not use the standard Exclusion Walker shell. The service never changes
	enemy identity, root size, collision, health, movement, targeting, attacks,
	rewards, or spawn rules. Every added part is massless, non-colliding, and
	welded to the existing server-owned HumanoidRootPart.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SpecialEnemyContracts = require(ReplicatedStorage.Shared.Combat.SpecialEnemyContracts)
local BossContracts = require(ReplicatedStorage.Shared.Combat.BossContracts)

local EnemyArchetypePresentationService = {}

local ENEMY_FOLDER_NAME = "EnemyEntities"
local SPITTER_PRESENTATION_NAME = "BlightSpitterPresentation"
local PROGENITOR_PRESENTATION_NAME = "ProgenitorPresentation"

local BLIGHT_SPITTER_ARCHETYPE_ID = SpecialEnemyContracts.SpecialEnemyArchetypeIds.BlightSpitter
local PROGENITOR_ARCHETYPE_ID = BossContracts.BossArchetypeIds.Progenitor

local COLORS = table.freeze({
	spitterFlesh = Color3.fromRGB(72, 91, 46),
	spitterRot = Color3.fromRGB(42, 57, 34),
	spitterArmor = Color3.fromRGB(36, 43, 30),
	spitterBone = Color3.fromRGB(164, 169, 119),
	spitterAcid = Color3.fromRGB(145, 255, 48),
	spitterAcidDark = Color3.fromRGB(73, 151, 28),
	bossFlesh = Color3.fromRGB(92, 34, 39),
	bossFleshDark = Color3.fromRGB(52, 22, 27),
	bossArmor = Color3.fromRGB(40, 34, 35),
	bossArmorDark = Color3.fromRGB(18, 16, 18),
	bossBone = Color3.fromRGB(184, 158, 130),
	bossCore = Color3.fromRGB(255, 83, 40),
	bossBrood = Color3.fromRGB(151, 62, 126),
})

local started = false
local childAddedConnection: RBXScriptConnection? = nil

local function configurePresentationPart(part: Part, name: string, color: Color3, material: Enum.Material)
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
	root: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	configurePresentationPart(part, name, color, material)
	part.Size = size
	if shape ~= nil then
		part.Shape = shape
	end
	part.CFrame = root.CFrame * localCFrame
	part.Parent = presentation

	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addLight(parent: BasePart, name: string, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Name = name
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
end

local function markPresentation(presentation: Model, candidateId: string, footprintId: string, silhouetteId: string)
	presentation:SetAttribute("VisualCandidateId", candidateId)
	presentation:SetAttribute("VisualStatus", "ProceduralFallback")
	presentation:SetAttribute("GameplayFootprintId", footprintId)
	presentation:SetAttribute("SilhouetteId", silhouetteId)
	presentation:SetAttribute("PresentationVersion", 1)
end

local function createBlightSpitter(root: BasePart): Model
	local presentation = Instance.new("Model")
	presentation.Name = SPITTER_PRESENTATION_NAME
	markPresentation(presentation, "blight-spitter.procedural-v1", BLIGHT_SPITTER_ARCHETYPE_ID, "acid-sac-ranged")

	local torso = createPart(
		presentation,
		root,
		"TorsoCore",
		Vector3.new(2.55, 2.7, 1.65),
		CFrame.new(0, 0.35, 0.18) * CFrame.Angles(math.rad(-17), 0, 0),
		COLORS.spitterFlesh,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	createPart(
		presentation,
		root,
		"Abdomen",
		Vector3.new(2.7, 2.1, 1.95),
		CFrame.new(0, -0.72, 0.42) * CFrame.Angles(math.rad(8), 0, 0),
		COLORS.spitterRot,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	createPart(
		presentation,
		root,
		"ChestCarapace",
		Vector3.new(2.35, 1.35, 0.28),
		CFrame.new(0, 0.72, -0.72) * CFrame.Angles(math.rad(-17), 0, 0),
		COLORS.spitterArmor,
		Enum.Material.CorrodedMetal,
		nil
	)
	createPart(
		presentation,
		root,
		"Head",
		Vector3.new(1.45, 1.35, 1.35),
		CFrame.new(0, 1.73, -0.68) * CFrame.Angles(math.rad(-24), 0, 0),
		COLORS.spitterBone,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	local mouth = createPart(
		presentation,
		root,
		"AcidMaw",
		Vector3.new(0.72, 0.28, 0.22),
		CFrame.new(0, 1.52, -1.39) * CFrame.Angles(math.rad(-24), 0, 0),
		COLORS.spitterAcid,
		Enum.Material.Neon,
		nil
	)
	addLight(mouth, "AcidMawGlow", COLORS.spitterAcid, 2.4, 7)

	for side = -1, 1, 2 do
		local sideName = if side < 0 then "Left" else "Right"
		createPart(
			presentation,
			root,
			"Mandible" .. sideName,
			Vector3.new(0.18, 0.28, 0.82),
			CFrame.new(side * 0.46, 1.48, -1.18) * CFrame.Angles(math.rad(18), math.rad(side * 14), 0),
			COLORS.spitterBone,
			Enum.Material.Slate,
			nil
		)
		createPart(
			presentation,
			root,
			"Shoulder" .. sideName,
			Vector3.new(0.82, 0.86, 0.86),
			CFrame.new(side * 1.18, 0.88, -0.02) * CFrame.Angles(0, 0, math.rad(side * 12)),
			COLORS.spitterArmor,
			Enum.Material.CorrodedMetal,
			Enum.PartType.Ball
		)
		createPart(
			presentation,
			root,
			"Forearm" .. sideName,
			Vector3.new(0.48, 2.35, 0.56),
			CFrame.new(side * 1.42, -0.24, -0.12) * CFrame.Angles(math.rad(-10), 0, math.rad(side * 7)),
			COLORS.spitterRot,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		createPart(
			presentation,
			root,
			"Claw" .. sideName,
			Vector3.new(0.7, 0.38, 0.78),
			CFrame.new(side * 1.55, -1.52, -0.38),
			COLORS.spitterBone,
			Enum.Material.SmoothPlastic,
			nil
		)
		createPart(
			presentation,
			root,
			"Leg" .. sideName,
			Vector3.new(0.62, 2.0, 0.68),
			CFrame.new(side * 0.62, -1.72, 0.3) * CFrame.Angles(math.rad(8), 0, 0),
			COLORS.spitterRot,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		createPart(
			presentation,
			root,
			"Foot" .. sideName,
			Vector3.new(0.78, 0.4, 1.08),
			CFrame.new(side * 0.62, -2.76, -0.04),
			COLORS.spitterArmor,
			Enum.Material.CorrodedMetal,
			nil
		)
		local sac = createPart(
			presentation,
			root,
			"AcidSac" .. sideName,
			Vector3.new(0.78, 1.35, 0.72),
			CFrame.new(side * 0.7, 0.25, 1.08) * CFrame.Angles(math.rad(-12), 0, math.rad(side * 7)),
			COLORS.spitterAcidDark,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		addLight(sac, "AcidSacGlow", COLORS.spitterAcid, 1.15, 4.5)
	end

	local pressureSac = createPart(
		presentation,
		root,
		"PressureSac",
		Vector3.new(1.1, 1.55, 0.72),
		CFrame.new(0, 0.35, 1.22) * CFrame.Angles(math.rad(-12), 0, 0),
		COLORS.spitterAcid,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	addLight(pressureSac, "PressureGlow", COLORS.spitterAcid, 1.45, 5.5)

	for spineIndex = 1, 4 do
		createPart(
			presentation,
			root,
			"DorsalSpine" .. tostring(spineIndex),
			Vector3.new(0.18, 0.42 + spineIndex * 0.08, 0.24),
			CFrame.new(0, 1.35 - spineIndex * 0.58, 1.0) * CFrame.Angles(math.rad(-24), 0, math.rad(45)),
			COLORS.spitterBone,
			Enum.Material.Slate,
			nil
		)
	end

	presentation.PrimaryPart = torso
	return presentation
end

local function createProgenitor(root: BasePart): Model
	local presentation = Instance.new("Model")
	presentation.Name = PROGENITOR_PRESENTATION_NAME
	markPresentation(presentation, "progenitor.procedural-v1", PROGENITOR_ARCHETYPE_ID, "crowned-heavy-core")

	local torso = createPart(
		presentation,
		root,
		"TorsoCore",
		Vector3.new(3.35, 3.15, 2.05),
		CFrame.new(0, 0.35, 0.12) * CFrame.Angles(math.rad(-8), 0, 0),
		COLORS.bossFlesh,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	createPart(
		presentation,
		root,
		"AbdomenCarapace",
		Vector3.new(3.0, 1.95, 2.05),
		CFrame.new(0, -0.95, 0.28),
		COLORS.bossArmor,
		Enum.Material.CorrodedMetal,
		Enum.PartType.Ball
	)
	createPart(
		presentation,
		root,
		"Breastplate",
		Vector3.new(3.3, 1.45, 0.34),
		CFrame.new(0, 0.72, -0.96) * CFrame.Angles(math.rad(-8), 0, 0),
		COLORS.bossArmorDark,
		Enum.Material.CorrodedMetal,
		nil
	)
	createPart(
		presentation,
		root,
		"Head",
		Vector3.new(1.7, 1.65, 1.55),
		CFrame.new(0, 2.03, -0.48) * CFrame.Angles(math.rad(-12), 0, 0),
		COLORS.bossBone,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	local core = createPart(
		presentation,
		root,
		"ExposedCore",
		Vector3.new(1.05, 1.15, 0.22),
		CFrame.new(0, 0.48, -1.2) * CFrame.Angles(math.rad(-8), 0, 0),
		COLORS.bossCore,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	addLight(core, "CoreGlow", COLORS.bossCore, 3.6, 11)

	for side = -1, 1, 2 do
		local sideName = if side < 0 then "Left" else "Right"
		createPart(
			presentation,
			root,
			"ShoulderMass" .. sideName,
			Vector3.new(1.35, 1.25, 1.4),
			CFrame.new(side * 1.65, 0.95, 0.05) * CFrame.Angles(0, 0, math.rad(side * 10)),
			COLORS.bossArmor,
			Enum.Material.CorrodedMetal,
			Enum.PartType.Ball
		)
		createPart(
			presentation,
			root,
			"UpperArm" .. sideName,
			Vector3.new(0.85, 1.65, 0.9),
			CFrame.new(side * 1.88, -0.02, -0.02) * CFrame.Angles(math.rad(-6), 0, math.rad(side * 8)),
			COLORS.bossFleshDark,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		createPart(
			presentation,
			root,
			"ForearmPlate" .. sideName,
			Vector3.new(1.02, 1.35, 1.04),
			CFrame.new(side * 2.0, -1.16, -0.16) * CFrame.Angles(math.rad(-4), 0, math.rad(side * 5)),
			COLORS.bossArmorDark,
			Enum.Material.CorrodedMetal,
			Enum.PartType.Ball
		)
		createPart(
			presentation,
			root,
			"CrusherClaw" .. sideName,
			Vector3.new(1.12, 0.72, 1.18),
			CFrame.new(side * 2.05, -2.03, -0.35),
			COLORS.bossBone,
			Enum.Material.Slate,
			nil
		)
		createPart(
			presentation,
			root,
			"Leg" .. sideName,
			Vector3.new(0.92, 2.0, 0.98),
			CFrame.new(side * 0.78, -1.73, 0.36) * CFrame.Angles(math.rad(3), 0, 0),
			COLORS.bossFleshDark,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		createPart(
			presentation,
			root,
			"ArmoredFoot" .. sideName,
			Vector3.new(1.1, 0.56, 1.45),
			CFrame.new(side * 0.78, -2.82, -0.02),
			COLORS.bossArmor,
			Enum.Material.CorrodedMetal,
			nil
		)
		local broodSac = createPart(
			presentation,
			root,
			"BroodSac" .. sideName,
			Vector3.new(0.92, 1.42, 0.82),
			CFrame.new(side * 0.82, 0.14, 1.24) * CFrame.Angles(math.rad(-8), 0, math.rad(side * 8)),
			COLORS.bossBrood,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		addLight(broodSac, "BroodGlow", COLORS.bossBrood, 1.25, 5)
	end

	for crownIndex = -2, 2 do
		local height = 0.72 + (2 - math.abs(crownIndex)) * 0.16
		createPart(
			presentation,
			root,
			"CrownSpine" .. tostring(crownIndex + 3),
			Vector3.new(0.2, height, 0.24),
			CFrame.new(crownIndex * 0.33, 2.9 - math.abs(crownIndex) * 0.08, -0.22)
				* CFrame.Angles(math.rad(-12), 0, math.rad(-crownIndex * 8)),
			COLORS.bossBone,
			Enum.Material.Slate,
			nil
		)
	end

	for spineIndex = 1, 4 do
		createPart(
			presentation,
			root,
			"BackSpine" .. tostring(spineIndex),
			Vector3.new(0.24, 0.72 + spineIndex * 0.08, 0.32),
			CFrame.new(0, 1.55 - spineIndex * 0.65, 1.28) * CFrame.Angles(math.rad(-28), 0, math.rad(45)),
			COLORS.bossBone,
			Enum.Material.Slate,
			nil
		)
	end

	createPart(
		presentation,
		root,
		"PelvisGuard",
		Vector3.new(2.75, 0.78, 1.45),
		CFrame.new(0, -1.28, 0.25),
		COLORS.bossArmorDark,
		Enum.Material.CorrodedMetal,
		nil
	)

	presentation.PrimaryPart = torso
	return presentation
end

local function attachPresentation(enemyModel: Model)
	local archetypeId = enemyModel:GetAttribute("EnemyArchetypeId")
	local presentationName: string?
	local createPresentation: ((BasePart) -> Model)?

	if archetypeId == BLIGHT_SPITTER_ARCHETYPE_ID then
		presentationName = SPITTER_PRESENTATION_NAME
		createPresentation = createBlightSpitter
	elseif archetypeId == PROGENITOR_ARCHETYPE_ID then
		presentationName = PROGENITOR_PRESENTATION_NAME
		createPresentation = createProgenitor
	else
		return
	end

	if presentationName == nil or createPresentation == nil or enemyModel:FindFirstChild(presentationName) ~= nil then
		return
	end

	local root = enemyModel:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	-- Appearance only. The authoritative root retains its exact physics and
	-- dimensions while becoming a faint inner core behind the cosmetic shell.
	root.Transparency = math.max(root.Transparency, 0.9)
	root.CastShadow = false

	local presentation = createPresentation(root)
	presentation.Parent = enemyModel
end

function EnemyArchetypePresentationService.start()
	if started then
		return
	end
	started = true

	local folderInstance = Workspace:WaitForChild(ENEMY_FOLDER_NAME)
	assert(folderInstance:IsA("Folder"), "EnemyEntities must be a Folder")
	local folder = folderInstance :: Folder

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

function EnemyArchetypePresentationService.stop()
	if not started then
		return
	end
	started = false
	if childAddedConnection ~= nil then
		childAddedConnection:Disconnect()
		childAddedConnection = nil
	end
end

return table.freeze(EnemyArchetypePresentationService)
