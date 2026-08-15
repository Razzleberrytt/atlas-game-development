--!strict

-- Builds the source-generated modular asset starter library into ReplicatedStorage.
-- This script only owns ReplicatedStorage/AtlasAssets/GeneratedModularAssets.
-- Authored replacements and gameplay systems remain independent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.ModularAssetProductionCatalog)
local Factory = require(ReplicatedStorage.Shared.Assets.ModularAssetFactory)

local atlasAssets = ReplicatedStorage:FindFirstChild("AtlasAssets")
if atlasAssets == nil then
	atlasAssets = Instance.new("Folder")
	atlasAssets.Name = "AtlasAssets"
	atlasAssets.Parent = ReplicatedStorage
end

local existing = atlasAssets:FindFirstChild(Catalog.GeneratedRootName)
if existing ~= nil and existing:GetAttribute("CatalogVersion") ~= Catalog.Version then
	existing:Destroy()
	existing = nil
end

if existing == nil then
	local generatedRoot = Instance.new("Folder")
	generatedRoot.Name = Catalog.GeneratedRootName
	generatedRoot:SetAttribute("CatalogVersion", Catalog.Version)
	generatedRoot:SetAttribute("GeneratedPrototypeRoot", true)
	generatedRoot:SetAttribute("PresentationOnly", true)
	generatedRoot.Parent = atlasAssets
	Factory.BuildStarterLibrary(generatedRoot)
end
