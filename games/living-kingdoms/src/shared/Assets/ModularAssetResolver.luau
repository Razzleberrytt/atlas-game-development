--!strict

-- Read-only helper for consumers that need presentation assets by stable semantic ID.
-- The resolver never owns or mutates gameplay state.

local Resolver = {}

local function collectByAssetId(root: Instance): { [string]: Instance }
	local index: { [string]: Instance } = {}
	if root:GetAttribute("AssetId") then
		index[root:GetAttribute("AssetId") :: string] = root
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		local assetId = descendant:GetAttribute("AssetId")
		if typeof(assetId) == "string" and assetId ~= "" and index[assetId] == nil then
			index[assetId] = descendant
		end
	end
	return index
end

function Resolver.BuildIndex(root: Instance): { [string]: Instance }
	return collectByAssetId(root)
end

function Resolver.FindByAssetId(root: Instance, assetId: string): Instance?
	if root:GetAttribute("AssetId") == assetId then
		return root
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:GetAttribute("AssetId") == assetId then
			return descendant
		end
	end
	return nil
end

function Resolver.CloneByAssetId(root: Instance, assetId: string, parent: Instance?): Instance?
	local source = Resolver.FindByAssetId(root, assetId)
	if source == nil then
		return nil
	end
	local clone = source:Clone()
	clone:SetAttribute("SourceAssetId", assetId)
	if parent ~= nil then
		clone.Parent = parent
	end
	return clone
end

function Resolver.GetGeneratedRoot(replicatedStorage: ReplicatedStorage): Folder?
	local atlasAssets = replicatedStorage:FindFirstChild("AtlasAssets")
	if atlasAssets == nil then
		return nil
	end
	local root = atlasAssets:FindFirstChild("GeneratedModularAssets")
	if root and root:IsA("Folder") then
		return root
	end
	return nil
end

return table.freeze(Resolver)
