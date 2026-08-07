--!strict

--[[
	Blueprint v2.7 R1 Studio capture helper.

	Run this source from the Roblox Studio Command Bar in the CLIENT context while
	playing the exact pinned R1 CI artifact. This file lives outside src/, so it is
	not included in the Rojo place and cannot change the build under test.

	The script reads the diagnostics already emitted by the R1 build and performs
	an independent scan for still-enabled broad Highlight targets. It does not
	modify gameplay, presentation, attributes, or instances.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MAXIMUM_TOP_LEVEL_TARGET_PARTS = 64
local SCHEMA = "LK_V27_R1_CAPTURE_V1"

local function fullName(instance: Instance?): string
	return if instance ~= nil then instance:GetFullName() else "nil"
end

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

local network = ReplicatedStorage:FindFirstChild("HordeNetwork")
assert(network ~= nil, "R1 capture requires ReplicatedStorage.HordeNetwork")

local networkAttributes = network:GetAttributes()
local workspaceAttributes = Workspace:GetAttributes()
local totalHighlights = 0
local enabledHighlights = 0
local rejectedHighlights = {}
local enabledBroadHighlights = {}

for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("Highlight") then
		totalHighlights += 1
		if descendant.Enabled then
			enabledHighlights += 1
		end

		local target = effectiveTarget(descendant)
		local row = {
			highlight = descendant:GetFullName(),
			target = fullName(target),
			enabled = descendant.Enabled,
		}

		if descendant:GetAttribute("LK_BroadTargetRejected") == true then
			table.insert(rejectedHighlights, row)
		end
		if descendant.Enabled and isBroadTarget(target) then
			table.insert(enabledBroadHighlights, row)
		end
	end
end

table.sort(rejectedHighlights, function(a, b)
	return a.highlight < b.highlight
end)
table.sort(enabledBroadHighlights, function(a, b)
	return a.highlight < b.highlight
end)

local capture = {
	schema = SCHEMA,
	unixTime = os.time(),
	listener = {
		bound = networkAttributes.V27_EarlyStateListenerBound,
		messagesReceived = networkAttributes.V27_StateMessagesReceived,
		invalidMessages = networkAttributes.V27_StateInvalidMessages,
		lastRevision = networkAttributes.V27_StateLastRevision,
	},
	highlightGuard = {
		active = workspaceAttributes.V27_BroadHighlightGuardActive,
		rejectedCount = workspaceAttributes.V27_BroadHighlightRejectedCount,
		lastTarget = workspaceAttributes.V27_BroadHighlightLastTarget,
	},
	highlightScan = {
		total = totalHighlights,
		enabled = enabledHighlights,
		rejectedInstances = rejectedHighlights,
		stillEnabledBroad = enabledBroadHighlights,
	},
}

local passableSnapshot = networkAttributes.V27_EarlyStateListenerBound == true
	and type(networkAttributes.V27_StateMessagesReceived) == "number"
	and networkAttributes.V27_StateMessagesReceived > 0
	and networkAttributes.V27_StateInvalidMessages == 0
	and type(networkAttributes.V27_StateLastRevision) == "number"
	and workspaceAttributes.V27_BroadHighlightGuardActive == true
	and #enabledBroadHighlights == 0

print("LK_V27_R1_CAPTURE " .. HttpService:JSONEncode(capture))
print("LK_V27_R1_CAPTURE_SNAPSHOT_PASSABLE", passableSnapshot)

if #enabledBroadHighlights > 0 then
	warn("LK_V27_R1_CAPTURE found one or more still-enabled broad Highlight targets")
end
