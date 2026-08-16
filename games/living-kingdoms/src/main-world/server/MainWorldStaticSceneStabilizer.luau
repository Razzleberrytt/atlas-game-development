--!strict

local MainWorldStaticSceneStabilizer = {}

local function anchorTree(root: Instance): number
	local changed = 0

	if root:IsA("BasePart") and not root.Anchored then
		root.Anchored = true
		changed += 1
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			descendant.Anchored = true
			changed += 1
		end
	end

	return changed
end

function MainWorldStaticSceneStabilizer.stabilize(worldRoot: Instance, staticRootNames: { string }): number
	local anchoredParts = 0

	for _, rootName in staticRootNames do
		local root = worldRoot:FindFirstChild(rootName)
		assert(root ~= nil, string.format("Main World static root %q is missing", rootName))
		anchoredParts += anchorTree(root)
	end

	return anchoredParts
end

return table.freeze(MainWorldStaticSceneStabilizer)
