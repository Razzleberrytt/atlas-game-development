--!strict

--[[
	Adds a bounded, source-managed readability and environmental model pass after
	WorldFoundationService creates the operation world. These props are
	presentation-only: they do not collide, participate in queries, emit dynamic
	light, or own navigation truth.

	Environmental model positions are generated from deterministic composition
	fields rather than hand-authored coordinates. Semantic asset IDs still come
	from EnvironmentAssetKitRegistry, so authored meshes can replace the procedural
	model layer later without changing composition or gameplay contracts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local EnvironmentModelPlacementConfig = require(ReplicatedStorage.Shared.Config.EnvironmentModelPlacementConfig)
local EnvironmentCompositionPlanner = require(script.Parent.EnvironmentCompositionPlanner)
local EnvironmentModelFactory = require(script.Parent.EnvironmentModelFactory)

local DRESSING_FOLDER_NAME = "ReadabilityDressing"
local ENVIRONMENT_MODELS_FOLDER_NAME = "EnvironmentModels"

type PointSpec = { x: number, y: number, z: number }
type EnvironmentPlacementSpec = {
	id: string,
	assetId: string,
	field: string,
	tier: string,
	packingRadiusStuds: number,
	x: number,
	z: number,
	yawDegrees: number,
	fieldScore: number,
}

local function toVector3(spec: PointSpec): Vector3
	return Vector3.new(spec.x, spec.y, spec.z)
end

local function makePresentationPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildTrailReflector(parent: Instance, index: number, position: Vector3)
	local marker = Instance.new("Model")
	marker.Name = string.format("TrailReflector%02d", index)
	marker:SetAttribute("EnvironmentPresentationOnly", true)
	marker.Parent = parent

	makePresentationPart(
		marker,
		"Post",
		Vector3.new(0.5, 3.2, 0.5),
		CFrame.new(position),
		Color3.fromRGB(72, 77, 70),
		Enum.Material.Metal
	)

	-- Neon is intentionally emissive-only. A physical cap + post silhouette keeps
	-- the cue readable even when color fidelity is poor, with no dynamic light.
	makePresentationPart(
		marker,
		"ReflectiveCap",
		Vector3.new(0.9, 0.45, 0.9),
		CFrame.new(position + Vector3.new(0, 1.7, 0)),
		Color3.fromRGB(230, 220, 167),
		Enum.Material.Neon
	)

	makePresentationPart(
		marker,
		"ReflectiveBand",
		Vector3.new(0.68, 0.24, 0.68),
		CFrame.new(position + Vector3.new(0, 0.72, 0)),
		Color3.fromRGB(201, 194, 150),
		Enum.Material.Neon
	)
end

local function groundedPlacementCFrame(worldRoot: Folder, placementSpec: EnvironmentPlacementSpec): CFrame
	local terrainFoundation = worldRoot:FindFirstChild("TerrainFoundation")
	assert(terrainFoundation ~= nil, "TerrainFoundation must exist before environment composition")

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { terrainFoundation }

	local origin = Vector3.new(placementSpec.x, 160, placementSpec.z)
	local raycastResult = Workspace:Raycast(origin, Vector3.new(0, -320, 0), raycastParams)
	local groundY = if raycastResult ~= nil then raycastResult.Position.Y else 0

	return CFrame.new(placementSpec.x, groundY, placementSpec.z)
		* CFrame.Angles(0, math.rad(placementSpec.yawDegrees), 0)
end

local function buildEnvironmentModels(parent: Instance, worldRoot: Folder)
	local modelsFolder = Instance.new("Folder")
	modelsFolder.Name = ENVIRONMENT_MODELS_FOLDER_NAME
	modelsFolder:SetAttribute("EnvironmentModelVersion", EnvironmentModelPlacementConfig.Version)
	modelsFolder:SetAttribute("EnvironmentCompositionAlgorithm", EnvironmentModelPlacementConfig.AlgorithmVersion)
	modelsFolder:SetAttribute("EnvironmentCompositionSeed", EnvironmentModelPlacementConfig.Seed)
	modelsFolder:SetAttribute(
		"EnvironmentCrossFamilySpacingScale",
		EnvironmentModelPlacementConfig.CrossFamilySpacingScale
	)
	modelsFolder:SetAttribute("EnvironmentPresentationOnly", true)
	modelsFolder.Parent = parent

	local placements = EnvironmentCompositionPlanner.Plan()
	for _, rawPlacementSpec in placements do
		local placementSpec = rawPlacementSpec :: EnvironmentPlacementSpec
		assert(
			EnvironmentModelFactory.Supports(placementSpec.assetId),
			string.format("Unsupported environment model placement asset: %s", placementSpec.assetId)
		)

		local model = EnvironmentModelFactory.Build(
			modelsFolder,
			placementSpec.assetId,
			groundedPlacementCFrame(worldRoot, placementSpec)
		)
		model.Name = placementSpec.id
		model:SetAttribute("EnvironmentPlacementId", placementSpec.id)
		model:SetAttribute("EnvironmentField", placementSpec.field)
		model:SetAttribute("EnvironmentCompositionTier", placementSpec.tier)
		model:SetAttribute("EnvironmentPackingRadiusStuds", placementSpec.packingRadiusStuds)
		model:SetAttribute("EnvironmentFieldScore", placementSpec.fieldScore)
		model:SetAttribute("EnvironmentCompositionSeed", EnvironmentModelPlacementConfig.Seed)
		model:SetAttribute("EnvironmentCompositionAlgorithm", EnvironmentModelPlacementConfig.AlgorithmVersion)
	end

	modelsFolder:SetAttribute("EnvironmentModelCount", #placements)
end

local function applyDressing(worldRoot: Folder)
	local existing = worldRoot:FindFirstChild(DRESSING_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local dressing = Instance.new("Folder")
	dressing.Name = DRESSING_FOLDER_NAME
	dressing:SetAttribute("WorldDressingVersion", Config.Dressing.Version)
	dressing:SetAttribute("EnvironmentModelVersion", EnvironmentModelPlacementConfig.Version)
	dressing:SetAttribute("EnvironmentCompositionAlgorithm", EnvironmentModelPlacementConfig.AlgorithmVersion)
	dressing:SetAttribute("EnvironmentCompositionSeed", EnvironmentModelPlacementConfig.Seed)
	dressing:SetAttribute("EnvironmentPresentationOnly", true)
	dressing.Parent = worldRoot

	for index, positionSpec in Config.Dressing.TrailReflectorPositions do
		buildTrailReflector(dressing, index, toVector3(positionSpec))
	end

	buildEnvironmentModels(dressing, worldRoot)

	worldRoot:SetAttribute("WorldDressingVersion", Config.Dressing.Version)
	worldRoot:SetAttribute("EnvironmentModelVersion", EnvironmentModelPlacementConfig.Version)
	worldRoot:SetAttribute("EnvironmentCompositionAlgorithm", EnvironmentModelPlacementConfig.AlgorithmVersion)
	worldRoot:SetAttribute("EnvironmentCompositionSeed", EnvironmentModelPlacementConfig.Seed)
end

local worldRootInstance = Workspace:WaitForChild(Config.WorldRootName)
assert(worldRootInstance:IsA("Folder"), Config.WorldRootName .. " must be a Folder")
local worldRoot = worldRootInstance :: Folder

-- Waiting for Landmarks makes this pass deterministic relative to the synchronous
-- world builder without polling or adding a recurring server loop.
worldRoot:WaitForChild("Landmarks")
applyDressing(worldRoot)

print(
	string.format(
		"[Living Kingdoms] World visual dressing ready: %s / %s / %s",
		Config.Dressing.Version,
		EnvironmentModelPlacementConfig.Version,
		EnvironmentModelPlacementConfig.AlgorithmVersion
	)
)
