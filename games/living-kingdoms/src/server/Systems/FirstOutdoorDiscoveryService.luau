--!strict

--[[
	BA-052 narrow server-owned runtime for the first optional outdoor discovery.

	The source-generated Forest Service Lookout remains presentation/geometry
	authority. This service only mounts one readable cache interaction onto that
	canonical landmark, validates the triggering player's actual server position,
	requires the live expedition to still be in Approach, commits the existing
	ExpeditionRuntime SecretDiscovered fact, and then uses RunBuildService's
	canonical authored-container reward fan-out.

	There is no client reward request, persistence, route activation, or parallel
	discovery state machine. Duplicate interactions are rejected by the existing
	per-run SecretDiscovered fact, so a fresh expedition RunId naturally becomes
	eligible again without special replay cleanup.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FirstOutdoorDiscoveryConfig = require(ReplicatedStorage.Shared.Config.FirstOutdoorDiscoveryConfig)
local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local ExpeditionLiveRuntimeService = require(script.Parent.ExpeditionLiveRuntimeService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)
local RunBuildService = require(script.Parent.RunBuildService)

local Service = {}

local DISCOVERY = FirstOutdoorDiscoveryConfig.Discoveries[1]
local CACHE_PART_NAME = "LookoutDiscoveryCache"
local EXPECTED_PHASE_ID = "Approach"

local started = false
local cachePart: Part? = nil
local promptConnection: RBXScriptConnection? = nil
local lastDiscoveredRunId: string? = nil
local lastRewardOfferCount = 0

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function operativePosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function resolveLookout(): Model?
	local worldRoot = Workspace:FindFirstChild(WorldFoundationConfig.WorldRootName)
	if worldRoot == nil then
		return nil
	end
	local candidate = worldRoot:FindFirstChild(DISCOVERY.AnchorLandmarkId, true)
	if candidate == nil or not candidate:IsA("Model") then
		return nil
	end
	if candidate:GetAttribute("LandmarkId") ~= DISCOVERY.AnchorLandmarkId then
		return nil
	end
	return candidate
end

local function tryDiscover(player: Player)
	if not started or not OperativeLifeService.isCombatAllowed(player) then
		return
	end
	local part = cachePart
	if part == nil or part.Parent == nil then
		return
	end
	local position = operativePosition(player)
	if
		position == nil
		or horizontalDistance(position, part.Position) > DISCOVERY.Interaction.MaximumDistanceStuds
	then
		return
	end

	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot == nil or snapshot.PhaseId ~= EXPECTED_PHASE_ID or snapshot.SecretDiscovered == true then
		return
	end
	if not ExpeditionLiveRuntimeService.markSecretDiscovered(snapshot.RunId, EXPECTED_PHASE_ID) then
		return
	end

	local eventId = string.format("%s:%s", snapshot.RunId, DISCOVERY.Id)
	lastRewardOfferCount = RunBuildService.offerRelicRewardToParticipants(eventId, DISCOVERY.RewardSourceId)
	lastDiscoveredRunId = snapshot.RunId
	part:SetAttribute("LastDiscoveredRunId", snapshot.RunId)
	part:SetAttribute("LastRewardOfferCount", lastRewardOfferCount)
end

local function createCache(lookout: Model): Part?
	local floor = lookout:FindFirstChild("RuinedFloor")
	if floor == nil or not floor:IsA("BasePart") then
		return nil
	end
	local existing = lookout:FindFirstChild(CACHE_PART_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = CACHE_PART_NAME
	part.Size = Vector3.new(4.2, 2.2, 3.2)
	part.CFrame = floor.CFrame * CFrame.new(6, 1.6, 2)
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(88, 99, 72)
	part:SetAttribute("DiscoveryId", DISCOVERY.Id)
	part:SetAttribute("StreamingIdentityId", DISCOVERY.StreamingIdentityId)
	part.Parent = lookout

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DiscoverPrompt"
	prompt.ActionText = DISCOVERY.Interaction.ActionText
	prompt.ObjectText = DISCOVERY.DisplayName
	prompt.HoldDuration = DISCOVERY.Interaction.HoldDurationSeconds
	prompt.MaxActivationDistance = DISCOVERY.Interaction.MaximumDistanceStuds
	prompt.RequiresLineOfSight = true
	prompt.Parent = part
	promptConnection = prompt.Triggered:Connect(tryDiscover)
	return part
end

function Service.readRuntimeState(): any
	return table.freeze({
		Started = started,
		Mounted = cachePart ~= nil and cachePart.Parent ~= nil,
		LastDiscoveredRunId = lastDiscoveredRunId,
		LastRewardOfferCount = lastRewardOfferCount,
	})
end

function Service.start()
	if started then
		return
	end
	assert(FirstOutdoorDiscoveryConfig.RuntimeConsumptionActive == true, "BA-052 discovery runtime must be enabled")
	assert(
		FirstOutdoorDiscoveryConfig.RuntimeConsumptionScopeId == "LookoutCacheInteractionOnly",
		"BA-052 runtime scope must remain the Lookout Cache interaction"
	)
	local lookout = resolveLookout()
	if lookout == nil then
		warn("[FirstOutdoorDiscovery] canonical LookoutTower landmark is unavailable")
		return
	end
	local created = createCache(lookout)
	if created == nil then
		warn("[FirstOutdoorDiscovery] canonical LookoutTower RuinedFloor anchor is unavailable")
		return
	end
	cachePart = created
	lastDiscoveredRunId = nil
	lastRewardOfferCount = 0
	started = true
end

function Service.stop()
	if promptConnection ~= nil then
		promptConnection:Disconnect()
		promptConnection = nil
	end
	if cachePart ~= nil then
		cachePart:Destroy()
		cachePart = nil
	end
	started = false
	lastDiscoveredRunId = nil
	lastRewardOfferCount = 0
end

return table.freeze(Service)
