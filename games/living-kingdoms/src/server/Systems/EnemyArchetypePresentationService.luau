--!strict

--[[
	Presentation-only procedural models for enemy archetypes that are not part of
	the standard Exclusion Walker / horde-role shell.

	The authoritative enemy Model, HumanoidRootPart, Humanoid, health, spawning,
	targeting, movement, attacks, rewards, and cleanup remain owned by
	EnemyDirectorService. Every part created here is massless, non-colliding,
	non-touching, and non-queryable; the geometry is welded to the existing root
	and therefore cannot become a second gameplay hitbox or physics owner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SpecialEnemyContracts = require(ReplicatedStorage.Shared.Combat.SpecialEnemyContracts)
local BossContracts = require(ReplicatedStorage.Shared.Combat.BossContracts)
local EnemyArchetypeVisualAssetKeys = require(ReplicatedStorage.Shared.Visual.EnemyArchetypeVisualAssetKeys)

local EnemyArchetypePresentationService = {}

local ENEMY_FOLDER_NAME = "EnemyEntities"
local SPITTER_PRESENTATION_NAME = "BlightSpitterPresentation"
local PROGENITOR_PRESENTATION_NAME = "ProgenitorPresentation"

local BLIGHT_SPITTER_ARCHETYPE_ID = SpecialEnemyContracts.SpecialEnemyArchetypeIds.BlightSpitter
local PROGENITOR_ARCHETYPE_ID = BossContracts.BossArchetypeIds.Progenitor

local COLORS = table.freeze({
	spitterFlesh = Color3.fromRGB(71, 83, 39),
	spitterBruise = Color3.fromRGB(79, 42, 67),
	spitterArmor = Color3.fromRGB(44, 49, 31),
	spitterBone = Color3.fromRGB(171, 176, 118),
	spitterAcid = Color3.fromRGB(153, 255, 42),
	spitterAcidDark = Color3.fromRGB(78, 150, 31),
	progenitorFlesh = Color3.fromRGB(83, 37, 44),
	progenitorCarapace = Color3.fromRGB(48, 35, 31),
	progenitorCarapaceLight = Color3.fromRGB(88, 66, 48),
	progenitorBone = Color3.fromRGB(184, 161, 126),
	progenitorCore = Color3.fromRGB(255, 102, 58),
	progenitorSpore = Color3.fromRGB(171, 112, 72),
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

local function makeRigidPart(
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
	configurePart(part, name, color, material)
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

local function addGlow(part: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Name = "PresentationGlow"
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

local function tagPresentation(
	presentation: Model,
	visualAssetKey: string,
	candidateId: string,
	gameplayFootprintId: string,
	partBudget: number
)
	presentation:SetAttribute("VisualAssetKey", visualAssetKey)
	presentation:SetAttribute("VisualCandidateId", candidateId)
	presentation:SetAttribute("VisualStatus", "ProceduralFallback")
	presentation:SetAttribute("GameplayFootprintId", gameplayFootprintId)
	presentation:SetAttribute("PresentationPartBudget", partBudget)
	presentation:SetAttribute("PresentationOnly", true)
end

local function createBlightSpitterPresentation(root: BasePart): Model
	local presentation = Instance.new("Model")
	presentation.Name = SPITTER_PRESENTATION_NAME
	tagPresentation(
		presentation,
		EnemyArchetypeVisualAssetKeys.BlightSpitterModel,
		"blight-spitter.procedural-v1",
		BLIGHT_SPITTER_ARCHETYPE_ID,
		24
	)

	local abdomen = makeRigidPart(
		presentation,
		root,
		"DistendedAbdomen",
		Vector3.new(2.5, 2.45, 2.0),
		CFrame.new(0, -0.2, 0.35) * CFrame.Angles(math.rad(-8), 0, 0),
		COLORS.spitterFlesh,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	local thorax = makeRigidPart(
		presentation,
		root,
		"Thorax",
		Vector3.new(2.05, 2.25, 1.35),
		CFrame.new(0, 1.15, -0.15) * CFrame.Angles(math.rad(18), 0, 0),
		COLORS.spitterBruise,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	makeRigidPart(
		presentation,
		root,
		"ChestCarapace",
		Vector3.new(2.28, 1.35, 0.32),
		CFrame.new(0, 1.25, -0.83) * CFrame.Angles(math.rad(18), 0, 0),
		COLORS.spitterArmor,
		Enum.Material.CorrodedMetal,
		nil
	)
	local head = makeRigidPart(
		presentation,
		root,
		"PinchedHead",
		Vector3.new(1.22, 1.16, 1.05),
		CFrame.new(0, 2.45, -0.76) * CFrame.Angles(math.rad(22), 0, 0),
		COLORS.spitterBone,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	makeRigidPart(
		presentation,
		root,
		"MouthPlate",
		Vector3.new(0.92, 0.34, 0.3),
		CFrame.new(0, 2.18, -1.25) * CFrame.Angles(math.rad(22), 0, 0),
		COLORS.spitterArmor,
		Enum.Material.CorrodedMetal,
		nil
	)
	for side = -1, 1, 2 do
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "MandibleLeft" else "MandibleRight",
			Vector3.new(0.18, 0.62, 0.2),
			CFrame.new(side * 0.37, 2.04, -1.32) * CFrame.Angles(math.rad(25), 0, math.rad(side * 24)),
			COLORS.spitterBone,
			Enum.Material.Slate,
			nil
		)
	end

	local throatSac = makeRigidPart(
		presentation,
		root,
		"ThroatSac",
		Vector3.new(1.15, 1.02, 0.72),
		CFrame.new(0, 1.53, -1.02),
		COLORS.spitterAcid,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	addGlow(throatSac, COLORS.spitterAcid, 2.6, 9)

	for side = -1, 1, 2 do
		local sac = makeRigidPart(
			presentation,
			root,
			if side < 0 then "AcidSacLeft" else "AcidSacRight",
			Vector3.new(0.92, 1.28, 0.82),
			CFrame.new(side * 0.91, -0.18, 0.93) * CFrame.Angles(math.rad(-12), 0, math.rad(side * 12)),
			COLORS.spitterAcidDark,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		addGlow(sac, COLORS.spitterAcid, 1.15, 5)
	end

	makeRigidPart(
		presentation,
		root,
		"AcidBladder",
		Vector3.new(1.25, 1.75, 0.92),
		CFrame.new(0, 0.15, 1.08),
		COLORS.spitterAcidDark,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)

	for spineIndex = 1, 3 do
		makeRigidPart(
			presentation,
			root,
			"BackSpine" .. tostring(spineIndex),
			Vector3.new(0.2, 0.9 + spineIndex * 0.12, 0.26),
			CFrame.new(0, 1.55 - spineIndex * 0.72, 1.06) * CFrame.Angles(math.rad(-31), 0, 0),
			COLORS.spitterBone,
			Enum.Material.Slate,
			nil
		)
	end

	for side = -1, 1, 2 do
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "ShoulderLeft" else "ShoulderRight",
			Vector3.new(0.72, 0.72, 0.76),
			CFrame.new(side * 1.03, 1.46, -0.02),
			COLORS.spitterArmor,
			Enum.Material.CorrodedMetal,
			Enum.PartType.Ball
		)
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "LongArmLeft" else "LongArmRight",
			Vector3.new(0.48, 2.65, 0.55),
			CFrame.new(side * 1.35, 0.18, -0.33) * CFrame.Angles(math.rad(-12), 0, math.rad(side * 9)),
			COLORS.spitterBruise,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "HookClawLeft" else "HookClawRight",
			Vector3.new(0.72, 0.38, 0.9),
			CFrame.new(side * 1.52, -1.23, -0.58) * CFrame.Angles(0, 0, math.rad(side * 18)),
			COLORS.spitterBone,
			Enum.Material.Slate,
			nil
		)
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "StiltLegLeft" else "StiltLegRight",
			Vector3.new(0.58, 2.1, 0.64),
			CFrame.new(side * 0.68, -1.45, 0.12) * CFrame.Angles(math.rad(6), 0, math.rad(side * 3)),
			COLORS.spitterFlesh,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "FootLeft" else "FootRight",
			Vector3.new(0.7, 0.38, 1.1),
			CFrame.new(side * 0.68, -2.55, -0.18),
			COLORS.spitterArmor,
			Enum.Material.CorrodedMetal,
			nil
		)
	end

	presentation.PrimaryPart = abdomen
	return presentation
end

local function createProgenitorPresentation(root: BasePart): Model
	local presentation = Instance.new("Model")
	presentation.Name = PROGENITOR_PRESENTATION_NAME
	tagPresentation(
		presentation,
		EnemyArchetypeVisualAssetKeys.ProgenitorBossModel,
		"progenitor.procedural-v1",
		PROGENITOR_ARCHETYPE_ID,
		30
	)

	local coreBody = makeRigidPart(
		presentation,
		root,
		"CoreBody",
		Vector3.new(3.7, 3.45, 2.55),
		CFrame.new(0, 0.45, 0.28) * CFrame.Angles(math.rad(-6), 0, 0),
		COLORS.progenitorFlesh,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	makeRigidPart(
		presentation,
		root,
		"UpperCarapace",
		Vector3.new(4.15, 1.38, 1.05),
		CFrame.new(0, 1.32, -0.76) * CFrame.Angles(math.rad(-8), 0, 0),
		COLORS.progenitorCarapace,
		Enum.Material.CorrodedMetal,
		nil
	)
	makeRigidPart(
		presentation,
		root,
		"LowerCarapace",
		Vector3.new(3.55, 1.0, 0.72),
		CFrame.new(0, -0.22, -1.02) * CFrame.Angles(math.rad(4), 0, 0),
		COLORS.progenitorCarapaceLight,
		Enum.Material.CorrodedMetal,
		nil
	)

	local coreGlow = makeRigidPart(
		presentation,
		root,
		"ExposedCore",
		Vector3.new(1.25, 1.3, 0.3),
		CFrame.new(0, 0.48, -1.42),
		COLORS.progenitorCore,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	addGlow(coreGlow, COLORS.progenitorCore, 3.7, 12)

	local head = makeRigidPart(
		presentation,
		root,
		"CrownedHead",
		Vector3.new(1.7, 1.5, 1.42),
		CFrame.new(0, 2.5, -0.42) * CFrame.Angles(math.rad(-12), 0, 0),
		COLORS.progenitorBone,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	makeRigidPart(
		presentation,
		root,
		"FaceShield",
		Vector3.new(1.8, 0.88, 0.28),
		CFrame.new(0, 2.48, -1.12) * CFrame.Angles(math.rad(-12), 0, 0),
		COLORS.progenitorCarapace,
		Enum.Material.CorrodedMetal,
		nil
	)

	for crownIndex = -2, 2 do
		local height = 0.72 + (2 - math.abs(crownIndex)) * 0.22
		makeRigidPart(
			presentation,
			root,
			"CrownSpine" .. tostring(crownIndex + 3),
			Vector3.new(0.2, height, 0.24),
			CFrame.new(crownIndex * 0.34, 3.36 + height * 0.18, -0.12)
				* CFrame.Angles(math.rad(-16), 0, math.rad(crownIndex * -8)),
			COLORS.progenitorBone,
			Enum.Material.Slate,
			nil
		)
	end

	for side = -1, 1, 2 do
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "ShoulderMassLeft" else "ShoulderMassRight",
			Vector3.new(1.65, 1.75, 1.72),
			CFrame.new(side * 2.05, 1.42, 0.02) * CFrame.Angles(0, 0, math.rad(side * 10)),
			COLORS.progenitorCarapaceLight,
			Enum.Material.CorrodedMetal,
			Enum.PartType.Ball
		)
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "SlamArmLeft" else "SlamArmRight",
			Vector3.new(1.02, 2.85, 1.12),
			CFrame.new(side * 2.08, -0.55, -0.18) * CFrame.Angles(math.rad(-6), 0, math.rad(side * 7)),
			COLORS.progenitorFlesh,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "SlamFistLeft" else "SlamFistRight",
			Vector3.new(1.42, 0.9, 1.65),
			CFrame.new(side * 2.18, -2.12, -0.35),
			COLORS.progenitorCarapace,
			Enum.Material.CorrodedMetal,
			nil
		)

		local broodSac = makeRigidPart(
			presentation,
			root,
			if side < 0 then "BroodSacLeft" else "BroodSacRight",
			Vector3.new(1.2, 1.55, 1.0),
			CFrame.new(side * 1.38, -0.38, 1.18) * CFrame.Angles(math.rad(-8), 0, math.rad(side * 13)),
			COLORS.progenitorSpore,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		addGlow(broodSac, COLORS.progenitorCore, 0.9, 5)
	end

	makeRigidPart(
		presentation,
		root,
		"PelvicCarapace",
		Vector3.new(3.25, 0.95, 1.55),
		CFrame.new(0, -1.25, 0.18),
		COLORS.progenitorCarapace,
		Enum.Material.CorrodedMetal,
		nil
	)

	for side = -1, 1, 2 do
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "PillarLegLeft" else "PillarLegRight",
			Vector3.new(1.05, 2.0, 1.14),
			CFrame.new(side * 0.88, -1.78, 0.28) * CFrame.Angles(math.rad(2), 0, math.rad(side * 2)),
			COLORS.progenitorFlesh,
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
		makeRigidPart(
			presentation,
			root,
			if side < 0 then "PlatedFootLeft" else "PlatedFootRight",
			Vector3.new(1.32, 0.58, 1.72),
			CFrame.new(side * 0.88, -2.72, -0.12),
			COLORS.progenitorCarapaceLight,
			Enum.Material.CorrodedMetal,
			nil
		)
	end

	for chimneyIndex = -1, 1, 2 do
		makeRigidPart(
			presentation,
			root,
			if chimneyIndex < 0 then "SporeChimneyLeft" else "SporeChimneyRight",
			Vector3.new(0.62, 1.65, 0.72),
			CFrame.new(chimneyIndex * 0.92, 1.48, 1.3) * CFrame.Angles(math.rad(-18), 0, math.rad(chimneyIndex * 8)),
			COLORS.progenitorSpore,
			Enum.Material.Slate,
			Enum.PartType.Cylinder
		)
	end

	for spineIndex = -2, 2 do
		makeRigidPart(
			presentation,
			root,
			"BackCarapaceSpine" .. tostring(spineIndex + 3),
			Vector3.new(0.24, 0.78 + (2 - math.abs(spineIndex)) * 0.13, 0.3),
			CFrame.new(spineIndex * 0.56, 0.55, 1.62) * CFrame.Angles(math.rad(-56), 0, math.rad(spineIndex * 4)),
			COLORS.progenitorBone,
			Enum.Material.Slate,
			nil
		)
	end

	presentation.PrimaryPart = coreBody
	return presentation
end

local function prepareAuthoritativeRoot(root: BasePart)
	-- The root remains the only gameplay body. It is merely visually demoted so
	-- the decorative shell reads clearly while the original alive/dead tint can
	-- still glow faintly through gaps.
	root.Transparency = 0.9
	root.Material = Enum.Material.Neon
	root.CastShadow = false
end

local function attachPresentation(enemyModel: Model)
	local archetypeId = enemyModel:GetAttribute("EnemyArchetypeId")
	if type(archetypeId) ~= "string" then
		return
	end

	local presentationName: string
	local createPresentation: (BasePart) -> Model
	if archetypeId == BLIGHT_SPITTER_ARCHETYPE_ID then
		presentationName = SPITTER_PRESENTATION_NAME
		createPresentation = createBlightSpitterPresentation
	elseif archetypeId == PROGENITOR_ARCHETYPE_ID then
		presentationName = PROGENITOR_PRESENTATION_NAME
		createPresentation = createProgenitorPresentation
	else
		return
	end

	if enemyModel:FindFirstChild(presentationName) ~= nil then
		return
	end
	local root = enemyModel:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	prepareAuthoritativeRoot(root)
	local presentation = createPresentation(root)
	presentation.Parent = enemyModel
end

function EnemyArchetypePresentationService.start()
	if started then
		return
	end
	started = true

	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	assert(
		folder ~= nil and folder:IsA("Folder"),
		"EnemyArchetypePresentationService must start after EnemyDirectorService"
	)
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
