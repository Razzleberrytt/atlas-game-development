--!strict

--[[
	BA-052 server-owned runtime for the first optional outdoor discovery.

	The authored Lookout Cache is anchored from source-managed landmark metadata,
	not a raw Workspace path. A ProximityPrompt supplies only the triggering Player;
	the server revalidates distance, active expedition/run identity, Approach phase,
	and one-time secret state before committing the discovery and offering the
	canonical authored-container relic reward to current participants.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FirstOutdoorDiscoveryConfig = require(ReplicatedStorage.Shared.Config.FirstOutdoorDiscoveryConfig)
local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local ExpeditionLiveRuntimeService = require(script.Parent.ExpeditionLiveRuntimeService)
local RunBuildService = require(script.Parent.RunBuildService)

local ROOT_FOLDER_NAME = "OutdoorDiscoveries"
local CACHE_PART_NAME = "LookoutCache"
local Discovery = FirstOutdoorDiscoveryConfig.Discoveries[1]
local PhaseIds = ExpeditionContracts.PhaseIds
local OutcomeIds = ExpeditionContracts.OutcomeIds

local OutdoorDiscoveryService = {}
local started = false
local rootFolder: Folder? = nil
local cachePart: Part? = nil
local promptConnection: RBXScriptConnection? = nil

local function findRuntimeLandmark()
	for _, landmark in WorldFoundationConfig.Landmarks do
		if landmark.id == Discovery.RuntimeLandmarkId then
			return landmark
		end
	end
	return nil
end

local RuntimeLandmark = findRuntimeLandmark()
assert(RuntimeLandmark ~= nil, "BA-052 Lookout Cache requires the source-managed Lookout landmark")

local function operativePosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function horizontalDistance(left: Vector3, right: Vector3): number
	local dx = left.X - right.X
	local dz = left.Z - right.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function resolveCachePosition(): Vector3
	local landmark = RuntimeLandmark :: any
	local x = landmark.x
	local z = landmark.z
	local origin = Vector3.new(x, 80, z)
	local direction = Vector3.new(0, -160, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if rootFolder == nil then {} else { rootFolder }
	local hit = Workspace:Raycast(origin, direction, params)
	local surfaceY = if hit == nil then 1 else hit.Position.Y
	return Vector3.new(x, surfaceY + Discovery.Interaction.SurfaceOffsetStuds, z)
end

local function tryClaim(player: Player)
	if not started then
		return
	end
	local part = cachePart
	if part == nil or part.Parent == nil then
		return
	end
	local position = operativePosition(player)
	if position == nil or horizontalDistance(position, part.Position) > Discovery.Interaction.MaximumDistanceStuds then
		return
	end

	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if
		snapshot == nil
		or snapshot.OutcomeId ~= OutcomeIds.InProgress
		or snapshot.PhaseId ~= PhaseIds.Approach
		or snapshot.SecretDiscovered == true
	then
		return
	end

	local claim = ExpeditionLiveRuntimeService.markSecretDiscovered(snapshot.RunId)
	if claim.Accepted ~= true then
		return
	end

	local eventId = string.format("%s:%s", snapshot.RunId, Discovery.Id)
	local offeredCount = RunBuildService.offerRelicRewardToParticipants(eventId, Discovery.RewardSourceId)
	part:SetAttribute("LastClaimedRunId", snapshot.RunId)
	part:SetAttribute("LastRewardOfferCount", offeredCount)
end

local function createCache(parent: Folder)
	local part = Instance.new("Part")
	part.Name = CACHE_PART_NAME
	part.Size = Vector3.new(4.5, 2.2, 3.4)
	part.Position = resolveCachePosition()
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.CorrodedMetal
	part.Color = Color3.fromRGB(78, 92, 72)
	part:SetAttribute("DiscoveryId", Discovery.Id)
	part:SetAttribute("StreamingIdentityId", Discovery.StreamingIdentityId)
	part:SetAttribute("AnchorWorldContentId", Discovery.AnchorWorldContentId)
	part.Parent = parent
	cachePart = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DiscoverPrompt"
	prompt.ActionText = "Open Cache"
	prompt.ObjectText = Discovery.DisplayName
	prompt.HoldDuration = Discovery.Interaction.HoldDurationSeconds
	prompt.MaxActivationDistance = Discovery.Interaction.MaximumDistanceStuds
	prompt.RequiresLineOfSight = true
	prompt.Parent = part
	promptConnection = prompt.Triggered:Connect(tryClaim)
end

function OutdoorDiscoveryService.start()
	if started then
		return
	end
	assert(FirstOutdoorDiscoveryConfig.RuntimeConsumptionActive == true, "BA-052 discovery runtime must be enabled")
	assert(
		FirstOutdoorDiscoveryConfig.RuntimeConsumptionScopeId == "ApproachLookoutCacheOnly",
		"BA-052 discovery runtime scope drifted"
	)
	started = true

	local existing = Workspace:FindFirstChild(ROOT_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = ROOT_FOLDER_NAME
	folder.Parent = Workspace
	rootFolder = folder
	createCache(folder)
end

function OutdoorDiscoveryService.stop()
	if not started then
		return
	end
	started = false
	if promptConnection ~= nil then
		promptConnection:Disconnect()
		promptConnection = nil
	end
	cachePart = nil
	if rootFolder ~= nil then
		rootFolder:Destroy()
		rootFolder = nil
	end
end

return table.freeze(OutdoorDiscoveryService)
