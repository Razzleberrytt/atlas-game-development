--!strict

--[[
	Presentation-only extension of WorldVisualDressing. It consumes generated
	modular prop prototypes by stable asset ID and scatters a small deterministic
	set beside existing composition placements. Props never collide, query, or own
	interaction/navigation truth.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local ModularAssetCatalog = require(ReplicatedStorage.Shared.Config.ModularAssetProductionCatalog)
local ModularAssetResolver = require(ReplicatedStorage.Shared.Assets.ModularAssetResolver)
local EnvironmentCompositionPlanner = require(script.Parent.EnvironmentCompositionPlanner)

local DRESSING_FOLDER_NAME = "ReadabilityDressing"
local MODULAR_FOLDER_NAME = "ModularPropScatter"
local MAX_PROP_COUNT = 10
local WAIT_SECONDS = 8

type EnvironmentPlacementSpec = {
	id: string,
	assetId: string,
	field: string,
	x: number,
	z: number,
	yawDegrees: number,
	fieldScore: number,
}

local function groundedPlacementCFrame(worldRoot: Folder, placementSpec: EnvironmentPlacementSpec): CFrame
	local terrainFoundation = worldRoot:FindFirstChild("TerrainFoundation")
	assert(terrainFoundation ~= nil, "TerrainFoundation must exist before modular world dressing")

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { terrainFoundation }

	local origin = Vector3.new(placementSpec.x, 160, placementSpec.z)
	local raycastResult = Workspace:Raycast(origin, Vector3.new(0, -320, 0), raycastParams)
	local groundY = if raycastResult ~= nil then raycastResult.Position.Y else 0
	return CFrame.new(placementSpec.x, groundY, placementSpec.z)
		* CFrame.Angles(0, math.rad(placementSpec.yawDegrees), 0)
end

local function sanitizePresentationModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = true
		end
	end
	model:SetAttribute("EnvironmentPresentationOnly", true)
	model:SetAttribute("ModularRuntimeIntegrated", true)
end

local function pivotHeightAboveBottom(model: Model): number
	local modelPivot = model:GetPivot()
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local boundsBottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
	return math.max(0, modelPivot.Position.Y - boundsBottomY)
end

local function resolveGeneratedRoot(): Folder?
	local existing = ModularAssetResolver.GetGeneratedRoot(ReplicatedStorage)
	if existing ~= nil then
		return existing
	end
	local atlasAssets = ReplicatedStorage:WaitForChild("AtlasAssets", WAIT_SECONDS)
	if atlasAssets == nil then
		return nil
	end
	atlasAssets:WaitForChild(ModularAssetCatalog.GeneratedRootName, WAIT_SECONDS)
	return ModularAssetResolver.GetGeneratedRoot(ReplicatedStorage)
end

local worldRootInstance = Workspace:WaitForChild(WorldFoundationConfig.WorldRootName)
assert(worldRootInstance:IsA("Folder"), WorldFoundationConfig.WorldRootName .. " must be a Folder")
local worldRoot = worldRootInstance :: Folder

local dressingInstance = worldRoot:WaitForChild(DRESSING_FOLDER_NAME, WAIT_SECONDS)
if dressingInstance == nil or not dressingInstance:IsA("Folder") then
	warn("[Living Kingdoms] Modular prop dressing skipped: ReadabilityDressing was not ready")
	return
end

local generatedRoot = resolveGeneratedRoot()
if generatedRoot == nil then
	warn("[Living Kingdoms] Modular prop dressing skipped: generated modular asset library was not ready")
	return
end

local existing = dressingInstance:FindFirstChild(MODULAR_FOLDER_NAME)
if existing ~= nil then
	existing:Destroy()
end

local modularFolder = Instance.new("Folder")
modularFolder.Name = MODULAR_FOLDER_NAME
modularFolder:SetAttribute("CatalogVersion", ModularAssetCatalog.Version)
modularFolder:SetAttribute("EnvironmentPresentationOnly", true)
modularFolder.Parent = dressingInstance

local placements = EnvironmentCompositionPlanner.Plan()
local propDefinitions = ModularAssetCatalog.Props.Categories
local propCount = math.min(MAX_PROP_COUNT, #placements, #propDefinitions)
local builtCount = 0

for index = 1, propCount do
	local placementIndex = 1 + math.floor((index - 1) * #placements / propCount)
	local placementSpec = placements[placementIndex] :: EnvironmentPlacementSpec
	local propDefinition = propDefinitions[index]
	local clone = ModularAssetResolver.CloneByAssetId(generatedRoot, propDefinition.id, modularFolder)
	if clone == nil or not clone:IsA("Model") then
		if clone ~= nil then
			clone:Destroy()
		end
		continue
	end

	sanitizePresentationModel(clone)
	local horizontalOffset = if index % 2 == 0 then 5 + (index % 3) * 2 else -5 - (index % 3) * 2
	local depthOffset = ((index % 3) - 1) * 4
	local heightOffset = pivotHeightAboveBottom(clone)
	local placementCFrame = groundedPlacementCFrame(worldRoot, placementSpec)
		* CFrame.new(horizontalOffset, heightOffset, depthOffset)
	clone:PivotTo(placementCFrame)
	clone.Name = string.format("ModularProp%02d_%s", index, propDefinition.category)
	clone:SetAttribute("ModularPlacementSourceId", placementSpec.id)
	clone:SetAttribute("ModularPropAssetId", propDefinition.id)
	builtCount += 1
end

modularFolder:SetAttribute("ModularPropCount", builtCount)
worldRoot:SetAttribute("ModularAssetCatalogVersion", ModularAssetCatalog.Version)
worldRoot:SetAttribute("ModularPropCount", builtCount)

print(string.format("[Living Kingdoms] Modular world dressing ready: %d props", builtCount))
