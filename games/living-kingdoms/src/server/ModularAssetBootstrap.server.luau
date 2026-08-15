--!strict

-- Builds the source-generated modular asset starter library into ReplicatedStorage.
-- This script only owns ReplicatedStorage/AtlasAssets/GeneratedModularAssets.
-- Authored replacements and gameplay systems remain independent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.ModularAssetProductionCatalog)
local Factory = require(ReplicatedStorage.Shared.Assets.ModularAssetFactory)

local READY_ATTRIBUTE = "GeneratedPrototypeReady"

local atlasAssets = ReplicatedStorage:FindFirstChild("AtlasAssets")
if atlasAssets == nil then
	atlasAssets = Instance.new("Folder")
	atlasAssets.Name = "AtlasAssets"
	atlasAssets.Parent = ReplicatedStorage
end

local existing = atlasAssets:FindFirstChild(Catalog.GeneratedRootName)
if
	existing ~= nil
	and (
		existing:GetAttribute("CatalogVersion") ~= Catalog.Version
		or existing:GetAttribute(READY_ATTRIBUTE) ~= true
	)
then
	existing:Destroy()
	existing = nil
end

if existing == nil then
	-- Build off-tree so no server/client consumer can observe a partially populated
	-- generated library. Ready is stamped only after construction succeeds, then
	-- the completed hierarchy is published to ReplicatedStorage in one step.
	local generatedRoot = Instance.new("Folder")
	generatedRoot.Name = Catalog.GeneratedRootName
	generatedRoot:SetAttribute("CatalogVersion", Catalog.Version)
	generatedRoot:SetAttribute("GeneratedPrototypeRoot", true)
	generatedRoot:SetAttribute("PresentationOnly", true)
	Factory.BuildStarterLibrary(generatedRoot)
	generatedRoot:SetAttribute(READY_ATTRIBUTE, true)
	generatedRoot.Parent = atlasAssets
end
