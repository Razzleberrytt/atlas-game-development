--!strict

-- Read-only helper for consumers that need presentation assets by stable semantic ID.
-- The resolver never owns or mutates gameplay state.

local Resolver = {}

local GENERATED_ROOT_READY_ATTRIBUTE = "GeneratedPrototypeReady"
local READY_POLL_SECONDS = 0.05

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
	if root and root:IsA("Folder") and root:GetAttribute(GENERATED_ROOT_READY_ATTRIBUTE) == true then
		return root
	end
	return nil
end

-- Bounded readiness helper for startup-sensitive presentation consumers. The
-- exact AssetId check matters on clients because a ready parent folder can be
-- observed before every descendant has finished replicating. A timeout of zero
-- is a single non-yielding lookup.
function Resolver.WaitForGeneratedAssetById(
	replicatedStorage: ReplicatedStorage,
	assetId: string,
	timeoutSeconds: number
): Instance?
	assert(assetId ~= "", "generated modular asset wait requires a non-empty AssetId")
	assert(timeoutSeconds >= 0 and timeoutSeconds < math.huge, "generated modular asset wait must be bounded")

	local deadline = time() + timeoutSeconds
	repeat
		local root = Resolver.GetGeneratedRoot(replicatedStorage)
		if root ~= nil then
			local source = Resolver.FindByAssetId(root, assetId)
			if source ~= nil then
				return source
			end
		end

		local remaining = deadline - time()
		if remaining <= 0 then
			return nil
		end
		task.wait(math.min(READY_POLL_SECONDS, remaining))
	until false
end

return table.freeze(Resolver)
