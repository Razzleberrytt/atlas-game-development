--!strict

--[[
	Blueprint v2.7 safety guard for the active-place escaped Highlight incident.

	This controller is intentionally conservative. It does not own normal
	Highlight presentation and does not replace the future shared lease registry.
	It only rejects obviously invalid broad production targets that can wash an
	entire world/root model in a single fill/outline.

	Allowed examples: one enemy model, one character, one narrow interactable.
	Rejected examples: Workspace, Terrain, or a very large top-level world root.
]]

local Workspace = game:GetService("Workspace")

local BroadHighlightGuardController = {}

local MAXIMUM_TOP_LEVEL_TARGET_PARTS = 64

local started = false
local descendantAddedConnection: RBXScriptConnection? = nil

local function effectiveTarget(highlight: Highlight): Instance?
	if highlight.Adornee ~= nil then
		return highlight.Adornee
	end
	return highlight.Parent
end

local function hasTooManyParts(instance: Instance): boolean
	local count = 0
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
			if count > MAXIMUM_TOP_LEVEL_TARGET_PARTS then
				return true
			end
		end
	end
	return false
end

local function isBroadTarget(target: Instance?): boolean
	if target == nil then
		return false
	end
	if target == Workspace or target == Workspace.Terrain then
		return true
	end
	if target.Parent ~= Workspace then
		return false
	end
	if not (target:IsA("Model") or target:IsA("Folder")) then
		return false
	end
	return hasTooManyParts(target)
end

local function inspect(instance: Instance)
	if not instance:IsA("Highlight") then
		return
	end
	local target = effectiveTarget(instance)
	if not isBroadTarget(target) then
		return
	end

	instance.Enabled = false
	instance:SetAttribute("LK_BroadTargetRejected", true)
	warn(string.format(
		"[Living Kingdoms] Disabled broad Highlight %s targeting %s",
		instance:GetFullName(),
		if target ~= nil then target:GetFullName() else "nil"
	))
end

function BroadHighlightGuardController.start()
	if started then
		return
	end
	started = true

	for _, descendant in Workspace:GetDescendants() do
		inspect(descendant)
	end
	descendantAddedConnection = Workspace.DescendantAdded:Connect(function(instance)
		-- Most Highlight producers configure Adornee before parenting. Deferring
		-- once also catches producers that assign Adornee immediately after parent.
		task.defer(inspect, instance)
	end)
end

function BroadHighlightGuardController.stop()
	if not started then
		return
	end
	started = false
	if descendantAddedConnection ~= nil then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end
end

return table.freeze(BroadHighlightGuardController)
