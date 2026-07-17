--!strict

--[[
	VIS-0103 presentation-only owner for the Exclusion Walker procedural fallback.
	It attaches project-original visual geometry to the existing replicated enemy
	model without changing the authoritative HumanoidRootPart footprint, Humanoid,
	movement, targeting, health, attacks, cleanup, or network ownership.

	Bounded by construction: one EnemyEntities.ChildAdded connection, no heartbeat,
	no per-enemy connections, no timers, no remotes, and a fixed part count.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)

local EnemyPresentationService = {}

local ENEMY_FOLDER_NAME = "EnemyEntities"
local PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"

local COLORS = table.freeze({
	bone = Color3.fromRGB(113, 119, 113),
	armor = Color3.fromRGB(58, 65, 62),
	armorDark = Color3.fromRGB(30, 35, 34),
	flesh = Color3.fromRGB(104, 45, 48),
	claw = Color3.fromRGB(132, 128, 110),
	sensor = Color3.fromRGB(218, 78, 53),
	canister = Color3.fromRGB(75, 87, 68),
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

local function makePart(
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
	weld.Parent = root
	return part
end

local function createPresentation(root: BasePart): Model
	local presentation = Instance.new("Model")
	presentation.Name = PRESENTATION_MODEL_NAME
	presentation:SetAttribute("VisualAssetKey", VisualAssetContracts.AssetKeys.EnemyStandardHostileModel)
	presentation:SetAttribute("VisualCandidateId", "exclusion-walker.v1")
	presentation:SetAttribute("VisualStatus", "ProceduralFallback")
	presentation:SetAttribute("GameplayFootprintId", "enemy.exclusion_walker")

	local torso = makePart(
		presentation,
		root,
		"TorsoCore",
		Vector3.new(1.75, 2.20, 1.15),
		CFrame.new(0, 0.35, 0),
		COLORS.flesh,
		Enum.Material.Slate,
		nil
	)
	makePart(presentation, root, "RibCage", Vector3.new(2.25, 0.42, 1.30), CFrame.new(0, 0.95, 0), COLORS.armor, Enum.Material.Metal, nil)
	makePart(presentation, root, "ChestPlate", Vector3.new(1.55, 0.50, 1.05), CFrame.new(0, 1.42, -0.04), COLORS.armorDark, Enum.Material.Metal, nil)
	makePart(presentation, root, "Head", Vector3.new(0.95, 0.62, 0.90), CFrame.new(0, 2.05, -0.10), COLORS.bone, Enum.Material.Slate, nil)
	makePart(presentation, root, "Sensor", Vector3.new(0.56, 0.18, 0.30), CFrame.new(0, 2.10, -0.50), COLORS.sensor, Enum.Material.Neon, nil)
	makePart(presentation, root, "DorsalSpine", Vector3.new(1.05, 0.36, 0.36), CFrame.new(0, 1.95, 0.25) * CFrame.Angles(0, 0, math.rad(90)), COLORS.claw, Enum.Material.Metal, Enum.PartType.Cylinder)
	makePart(presentation, root, "ShoulderLeft", Vector3.new(0.65, 0.65, 0.80), CFrame.new(-1.35, 1.02, 0), COLORS.armor, Enum.Material.Metal, nil)
	makePart(presentation, root, "ShoulderRight", Vector3.new(0.65, 0.65, 0.80), CFrame.new(1.35, 1.02, 0), COLORS.armor, Enum.Material.Metal, nil)
	makePart(presentation, root, "ForearmLeft", Vector3.new(0.46, 1.55, 0.50), CFrame.new(-1.45, 0.05, 0) * CFrame.Angles(0, 0, math.rad(7)), COLORS.bone, Enum.Material.Slate, nil)
	makePart(presentation, root, "ForearmRight", Vector3.new(0.46, 1.55, 0.50), CFrame.new(1.45, 0.05, 0) * CFrame.Angles(0, 0, math.rad(-7)), COLORS.bone, Enum.Material.Slate, nil)
	makePart(presentation, root, "ClawLeft", Vector3.new(0.34, 0.78, 0.32), CFrame.new(-1.55, -0.95, -0.12) * CFrame.Angles(math.rad(12), 0, math.rad(6)), COLORS.claw, Enum.Material.Metal, nil)
	makePart(presentation, root, "ClawRight", Vector3.new(0.34, 0.78, 0.32), CFrame.new(1.55, -0.95, -0.12) * CFrame.Angles(math.rad(12), 0, math.rad(-6)), COLORS.claw, Enum.Material.Metal, nil)
	makePart(presentation, root, "HipGuard", Vector3.new(1.35, 0.52, 0.92), CFrame.new(0, -0.95, 0), COLORS.armorDark, Enum.Material.Metal, nil)
	makePart(presentation, root, "LegLeft", Vector3.new(0.55, 1.65, 0.68), CFrame.new(-0.52, -2.00, 0.05) * CFrame.Angles(0, 0, math.rad(2)), COLORS.bone, Enum.Material.Slate, nil)
	makePart(presentation, root, "LegRight", Vector3.new(0.55, 1.65, 0.68), CFrame.new(0.52, -2.00, 0.05) * CFrame.Angles(0, 0, math.rad(-2)), COLORS.bone, Enum.Material.Slate, nil)
	makePart(presentation, root, "FootLeft", Vector3.new(0.70, 0.34, 1.25), CFrame.new(-0.52, -3.00, -0.28), COLORS.armor, Enum.Material.Metal, nil)
	makePart(presentation, root, "FootRight", Vector3.new(0.70, 0.34, 1.25), CFrame.new(0.52, -3.00, -0.28), COLORS.armor, Enum.Material.Metal, nil)
	makePart(presentation, root, "BackCanister", Vector3.new(0.95, 0.64, 0.64), CFrame.new(0, 0.28, 0.72) * CFrame.Angles(0, 0, math.rad(90)), COLORS.canister, Enum.Material.Metal, Enum.PartType.Cylinder)

	presentation.PrimaryPart = torso
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
