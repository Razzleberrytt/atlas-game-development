--!strict

--[[
	Adds a bounded secondary prop layer around the existing seeded environmental
	composition. The hero composition remains the spatial/story authority; this
	pass only decorates those accepted anchors with reusable modular prototypes.

	Generated prototypes are cloned by stable AssetId, sanitized to presentation-
	only world geometry, and grounded against the authored TerrainFoundation.
	There is no recurring loop, gameplay interaction, collision, touch, or query
	authority in this script.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.ModularEnvironmentDressingConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local ModularAssetResolver = require(ReplicatedStorage.Shared.Assets.ModularAssetResolver)

local READABILITY_DRESSING_NAME = "ReadabilityDressing"
local HERO_MODELS_FOLDER_NAME = "EnvironmentModels"
local HASH_MODULUS = 2147483647
local HASH_MULTIPLIER = 131
local ASSET_READY_POLL_SECONDS = 0.05

local function stableHash(text: string): number
	local hash = 17
	for index = 1, #text do
		hash = (hash * HASH_MULTIPLIER + string.byte(text, index)) % HASH_MODULUS
	end
	return hash
end

local function requiredAssetIds(): { string }
	local seen = {}
	local result = {}
	for _, fieldSpec in Config.FieldSpecs do
		for _, assetId in fieldSpec.assetIds do
			if seen[assetId] then
				continue
			end
			seen[assetId] = true
			table.insert(result, assetId)
		end
	end
	table.sort(result)
	return result
end

local function generatedRootIsReady(root: Folder, assetIds: { string }): boolean
	for _, assetId in assetIds do
		if ModularAssetResolver.FindByAssetId(root, assetId) == nil then
			return false
		end
	end
	return true
end

local function waitForGeneratedRoot(): Folder?
	local assetIds = requiredAssetIds()
	local deadline = Workspace:GetServerTimeNow() + Config.GeneratedAssetWaitSeconds
	repeat
		local root = ModularAssetResolver.GetGeneratedRoot(ReplicatedStorage)
		if root ~= nil and generatedRootIsReady(root, assetIds) then
			return root
		end
		task.wait(ASSET_READY_POLL_SECONDS)
	until Workspace:GetServerTimeNow() >= deadline
	return nil
end

local function sanitizePresentationClone(instance: Instance)
	instance:SetAttribute("EnvironmentPresentationOnly", true)
	instance:SetAttribute("EnvironmentSecondaryDressing", true)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("ProximityPrompt") or descendant:IsA("ClickDetector") then
			descendant:Destroy()
		end
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
	end
end

local function groundPosition(worldRoot: Folder, x: number, z: number): Vector3
	local terrainFoundation = worldRoot:FindFirstChild("TerrainFoundation")
	assert(terrainFoundation ~= nil, "TerrainFoundation must exist before modular environment dressing")

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { terrainFoundation }

	local origin = Vector3.new(x, Config.GroundRayOriginY, z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -Config.GroundRayDistance, 0), raycastParams)
	if result ~= nil then
		return result.Position
	end
	return Vector3.new(x, 0, z)
end

local function placeClone(clone: Instance, cframe: CFrame)
	if clone:IsA("Model") then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
	else
		error("modular environment dressing asset must resolve to a Model or BasePart")
	end
end

local function collectAnchorsByField(heroModels: Folder): { [string]: { Model } }
	local byField: { [string]: { Model } } = {}
	for _, child in heroModels:GetChildren() do
		if not child:IsA("Model") then
			continue
		end
		local field = child:GetAttribute("EnvironmentField")
		if typeof(field) ~= "string" or Config.FieldSpecs[field] == nil then
			continue
		end
		local bucket = byField[field]
		if bucket == nil then
			bucket = {}
			byField[field] = bucket
		end
		table.insert(bucket, child)
	end
	for _, bucket in byField do
		table.sort(bucket, function(a: Model, b: Model): boolean
			return a.Name < b.Name
		end)
	end
	return byField
end

local function chooseAnchor(bucket: { Model }, slotIndex: number, slotCount: number): Model
	assert(#bucket > 0, "modular environment field requires at least one hero anchor")
	if slotCount <= 1 then
		return bucket[1]
	end
	local alpha = (slotIndex - 1) / (slotCount - 1)
	local index = math.clamp(math.floor(alpha * (#bucket - 1) + 1.5), 1, #bucket)
	return bucket[index]
end

local function cloneFieldProp(
	generatedRoot: Folder,
	worldRoot: Folder,
	folder: Folder,
	field: string,
	anchor: Model,
	slotIndex: number,
	assetIds: { string }
): boolean
	local key = string.format("%s|%s|%d|%d", field, anchor.Name, slotIndex, WorldConfig.Seed)
	local hash = stableHash(key)
	local assetId = assetIds[(hash % #assetIds) + 1]
	local clone = ModularAssetResolver.CloneByAssetId(generatedRoot, assetId, nil)
	if clone == nil then
		warn(string.format("[Living Kingdoms] Modular environment asset unavailable: %s", assetId))
		return false
	end

	local angle = math.rad(hash % 360)
	local radiusSpan = Config.MaximumOffsetStuds - Config.MinimumOffsetStuds
	local radiusFraction = ((math.floor(hash / 360)) % 1000) / 999
	local radius = Config.MinimumOffsetStuds + radiusSpan * radiusFraction
	local anchorPosition = anchor:GetPivot().Position
	local x = anchorPosition.X + math.cos(angle) * radius
	local z = anchorPosition.Z + math.sin(angle) * radius
	local ground = groundPosition(worldRoot, x, z)
	local yaw = math.rad((math.floor(hash / 17)) % 360)

	sanitizePresentationClone(clone)
	clone.Name = string.format("%s_%02d_%s", field, slotIndex, string.gsub(assetId, "[^%w]+", "_"))
	clone:SetAttribute("EnvironmentField", field)
	clone:SetAttribute("EnvironmentAnchorPlacementId", anchor:GetAttribute("EnvironmentPlacementId") or anchor.Name)
	clone:SetAttribute("EnvironmentDressingVersion", Config.Version)
	placeClone(clone, CFrame.new(ground) * CFrame.Angles(0, yaw, 0))
	clone.Parent = folder
	return true
end

local worldRootInstance = Workspace:WaitForChild(WorldConfig.WorldRootName, Config.WorldDressingWaitSeconds)
assert(
	worldRootInstance ~= nil,
	WorldConfig.WorldRootName .. " did not become available before the modular dressing timeout"
)
assert(worldRootInstance:IsA("Folder"), WorldConfig.WorldRootName .. " must be a Folder")
local worldRoot = worldRootInstance :: Folder

local dressing = worldRoot:WaitForChild(READABILITY_DRESSING_NAME, Config.WorldDressingWaitSeconds)
if dressing == nil or not dressing:IsA("Folder") then
	warn("[Living Kingdoms] Modular environment dressing skipped: ReadabilityDressing was not ready")
	return
end

local heroModels = dressing:WaitForChild(HERO_MODELS_FOLDER_NAME, Config.WorldDressingWaitSeconds)
if heroModels == nil or not heroModels:IsA("Folder") then
	warn("[Living Kingdoms] Modular environment dressing skipped: EnvironmentModels was not ready")
	return
end

local generatedRoot = waitForGeneratedRoot()
if generatedRoot == nil then
	warn("[Living Kingdoms] Modular environment dressing skipped: complete modular prop library was not ready")
	return
end

local oldFolder = dressing:FindFirstChild(Config.FolderName)
if oldFolder ~= nil then
	oldFolder:Destroy()
end

local output = Instance.new("Folder")
output.Name = Config.FolderName
output:SetAttribute("EnvironmentDressingVersion", Config.Version)
output:SetAttribute("EnvironmentPresentationOnly", true)
output:SetAttribute("EnvironmentPropBudget", Config.MaximumPropCount)
output.Parent = dressing

local anchorsByField = collectAnchorsByField(heroModels)
local created = 0
for field, fieldSpec in Config.FieldSpecs do
	local bucket = anchorsByField[field]
	if bucket == nil or #bucket == 0 then
		warn(string.format("[Living Kingdoms] Modular environment field has no anchors: %s", field))
		continue
	end
	for slotIndex = 1, fieldSpec.count do
		local anchor = chooseAnchor(bucket, slotIndex, fieldSpec.count)
		if cloneFieldProp(generatedRoot, worldRoot, output, field, anchor, slotIndex, fieldSpec.assetIds) then
			created += 1
		end
	end
end

output:SetAttribute("EnvironmentPropCount", created)
worldRoot:SetAttribute("ModularEnvironmentDressingVersion", Config.Version)
print(string.format("[Living Kingdoms] Modular environment dressing ready: %s / %d props", Config.Version, created))
