--!strict

-- Presentation-only supply-chest geometry for SurvivalLootService.
-- Loot authority, claiming, item staging, collection, and proximity validation
-- remain in SurvivalLootService. This module owns only the visible chest model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModularAssetResolver = require(ReplicatedStorage.Shared.Assets.ModularAssetResolver)

local Presentation = {}

local COMMON_REWARD_ASSET_ID = "reward.chest.common"
local MODULAR_STATUS = "ModularGeneratedAsset"
local FALLBACK_STATUS = "ProceduralFallback"

type SupplyChestPresentation = {
	model: Model,
	lid: BasePart,
	Open: () -> (),
}

local function preparePart(part: BasePart, isRoot: boolean)
	part.Anchored = true
	part.CanCollide = isRoot
	part.CanTouch = false
	part.CanQuery = true
end

local function findBasePart(model: Model, name: string): BasePart?
	local candidate = model:FindFirstChild(name, true)
	return if candidate ~= nil and candidate:IsA("BasePart") then candidate else nil
end

local function createOpenAction(lid: BasePart): () -> ()
	local closedCFrame = lid.CFrame
	local opened = false
	return function()
		if opened or lid.Parent == nil then
			return
		end
		opened = true
		lid.CFrame = closedCFrame * CFrame.new(0, 1.1, 1) * CFrame.Angles(math.rad(-32), 0, 0)
	end
end

local function createModularChest(parent: Instance, modelName: string, position: Vector3): SupplyChestPresentation?
	local generatedRoot = ModularAssetResolver.GetGeneratedRoot(ReplicatedStorage)
	if generatedRoot == nil then
		return nil
	end

	local clone = ModularAssetResolver.CloneByAssetId(generatedRoot, COMMON_REWARD_ASSET_ID)
	if clone == nil or not clone:IsA("Model") then
		if clone ~= nil then
			clone:Destroy()
		end
		return nil
	end

	local model = clone :: Model
	local root = model.PrimaryPart or findBasePart(model, "Root")
	local lid = findBasePart(model, "Lid")
	if root == nil or lid == nil then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	model.Name = modelName
	model:SetAttribute("SourceAssetId", COMMON_REWARD_ASSET_ID)
	model:SetAttribute("VisualStatus", MODULAR_STATUS)
	model:SetAttribute("PresentationOnly", true)
	model:SetAttribute("GeneratedPrototype", nil)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			preparePart(descendant, descendant == root)
		end
	end

	model:PivotTo(CFrame.new(position))
	model.Parent = parent
	return table.freeze({
		model = model,
		lid = lid,
		Open = createOpenAction(lid),
	})
end

local function createFallbackChest(parent: Instance, modelName: string, position: Vector3): SupplyChestPresentation
	local model = Instance.new("Model")
	model.Name = modelName
	model:SetAttribute("SourceAssetId", COMMON_REWARD_ASSET_ID)
	model:SetAttribute("VisualStatus", FALLBACK_STATUS)
	model:SetAttribute("PresentationOnly", true)
	model.Parent = parent

	local base = Instance.new("Part")
	base.Name = "ChestBase"
	base.Size = Vector3.new(5, 2.4, 3.2)
	base.Position = position
	base.Color = Color3.fromRGB(73, 47, 28)
	base.Material = Enum.Material.WoodPlanks
	preparePart(base, true)
	base.Parent = model
	model.PrimaryPart = base

	local lid = Instance.new("Part")
	lid.Name = "ChestLid"
	lid.Size = Vector3.new(5.2, 1.1, 3.4)
	lid.Position = position + Vector3.new(0, 1.7, 0)
	lid.Color = Color3.fromRGB(102, 67, 34)
	lid.Material = Enum.Material.WoodPlanks
	preparePart(lid, false)
	lid.Parent = model

	local band = Instance.new("Part")
	band.Name = "MetalBand"
	band.Size = Vector3.new(0.55, 3.2, 3.45)
	band.Position = position + Vector3.new(0, 0.7, 0)
	band.Color = Color3.fromRGB(45, 48, 47)
	band.Material = Enum.Material.Metal
	preparePart(band, false)
	band.Parent = model

	return table.freeze({
		model = model,
		lid = lid,
		Open = createOpenAction(lid),
	})
end

function Presentation.createSupplyChest(parent: Instance, index: number, position: Vector3): SupplyChestPresentation
	local modelName = "LootChest" .. tostring(index)
	return createModularChest(parent, modelName, position) or createFallbackChest(parent, modelName, position)
end

return table.freeze(Presentation)
