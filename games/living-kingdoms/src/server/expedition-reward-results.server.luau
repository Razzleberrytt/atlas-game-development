--!strict

-- Server-owned reward/result integration for the first expedition slice.
-- It observes authoritative runtime snapshots, freezes the run participant roster,
-- claims each reward source once, persists rewards idempotently, and publishes
-- only a sanitized read-only debrief.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EquipmentContracts = require(ReplicatedStorage.Shared.Equipment.EquipmentRewardContracts)
local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local EquipmentRewardService = require(script.Parent.Systems.EquipmentRewardService)
local ExpeditionLiveRuntimeService = require(script.Parent.Systems.ExpeditionLiveRuntimeService)
local ExpeditionResultService = require(script.Parent.Systems.ExpeditionResultService)
local InventoryLiveService = require(script.Parent.Systems.InventoryLiveService)

local existing = ReplicatedStorage:FindFirstChild("ExpeditionResultNetwork")
if existing ~= nil then
	existing:Destroy()
end

local network = Instance.new("Folder")
network.Name = "ExpeditionResultNetwork"
network.Parent = ReplicatedStorage

local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State"
stateRemote.Parent = network

local readState = Instance.new("RemoteFunction")
readState.Name = "ReadState"
readState.Parent = network

local activeRunId: string? = nil
local rewardService: any = nil
local resultService: any = nil
local participantUserIds: { number } = {}
local persistedByPlayer: { [number]: boolean } = {}
local lastSafeSummary: any = nil
local lastSignature = ""
local accumulatedSeconds = 0

local function destroyOwners()
	if rewardService ~= nil then
		rewardService:destroy()
		rewardService = nil
	end
	if resultService ~= nil then
		resultService:destroy()
		resultService = nil
	end
	activeRunId = nil
	table.clear(participantUserIds)
	table.clear(persistedByPlayer)
end

local function safeReward(reward: any): any
	return table.freeze({
		DisplayName = reward.DisplayName,
		Slot = reward.Slot,
		Rarity = reward.Rarity,
		Power = reward.Power,
		SourceId = reward.SourceId,
	})
end

local function safeSummary(summary: any): any
	local rewards = {}
	for _, reward in summary.Rewards do
		table.insert(rewards, safeReward(reward))
	end
	return table.freeze({
		RunId = summary.RunId,
		OutcomeId = summary.OutcomeId,
		DurationSeconds = summary.DurationSeconds,
		PartySize = summary.PartySize,
		SecretDiscovered = summary.SecretDiscovered,
		Rewards = table.freeze(rewards),
	})
end

local function signature(summary: any): string
	if summary == nil then
		return "none"
	end
	local parts = {
		summary.RunId,
		summary.OutcomeId,
		tostring(summary.DurationSeconds),
		tostring(summary.SecretDiscovered),
	}
	for _, reward in summary.Rewards do
		table.insert(parts, string.format("%s:%s:%s:%d", reward.SourceId, reward.DisplayName, reward.Rarity, reward.Power))
	end
	return table.concat(parts, "|")
end

local function broadcastIfChanged(summary: any)
	local nextSignature = signature(summary)
	if nextSignature == lastSignature then
		return
	end
	lastSignature = nextSignature
	lastSafeSummary = summary
	stateRemote:FireAllClients(summary)
end

local function captureParticipants(partySize: number)
	local players = Players:GetPlayers()
	table.sort(players, function(left, right)
		return left.UserId < right.UserId
	end)
	for index = 1, math.min(partySize, #players) do
		table.insert(participantUserIds, players[index].UserId)
	end
end

local function ensureRun(snapshot: any)
	if activeRunId == snapshot.RunId then
		return
	end
	destroyOwners()
	activeRunId = snapshot.RunId
	rewardService = EquipmentRewardService.new(snapshot.RunId, snapshot.Seed)
	resultService = ExpeditionResultService.new()
	captureParticipants(snapshot.PartySize)
	lastSafeSummary = nil
	lastSignature = ""
end

local function claimIfReached(snapshot: any)
	if rewardService == nil then
		return
	end
	if snapshot.PhaseIndex > 4 then
		rewardService:claimReward(EquipmentContracts.SourceIds.Elite)
	end
	if snapshot.PhaseIndex > 5 then
		rewardService:claimReward(EquipmentContracts.SourceIds.Boss)
	end
end

local function persistRewards(summary: any)
	for _, playerId in participantUserIds do
		if persistedByPlayer[playerId] then
			continue
		end

		local allApplied = true
		for _, reward in summary.Rewards do
			local mutation = InventoryLiveService.applyReward(playerId, reward, os.time())
			if mutation.Accepted ~= true and mutation.ReasonId ~= "RewardAlreadyApplied" then
				allApplied = false
				if mutation.ReasonId ~= "PlayerNotLoaded" then
					warn(string.format(
						"[ExpeditionRewardResults] reward persistence rejected for %d: %s",
						playerId,
						mutation.ReasonId
					))
				end
				break
			end
		end

		if allApplied then
			persistedByPlayer[playerId] = true
		end
	end
end

local function finalizeIfTerminal(snapshot: any)
	if resultService == nil or rewardService == nil then
		return
	end
	if snapshot.OutcomeId == ExpeditionContracts.OutcomeIds.InProgress then
		return
	end

	local summary = resultService:getSummary()
	if summary == nil then
		local rewards = {}
		for _, sourceId in { EquipmentContracts.SourceIds.Elite, EquipmentContracts.SourceIds.Boss } do
			local reward = rewardService:getClaimedReward(sourceId)
			if reward ~= nil then
				table.insert(rewards, reward)
			end
		end

		local finalized = resultService:finalize({
			Snapshot = snapshot,
			FinishedAtUnix = Workspace:GetServerTimeNow(),
			Rewards = rewards,
		})
		if finalized.Accepted ~= true then
			warn("[ExpeditionRewardResults] result finalization rejected:", finalized.ReasonId)
			return
		end
		summary = finalized.Summary
		broadcastIfChanged(safeSummary(summary))
	end

	persistRewards(summary)
end

local function step()
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot == nil then
		return
	end
	ensureRun(snapshot)
	claimIfReached(snapshot)
	finalizeIfTerminal(snapshot)
end

readState.OnServerInvoke = function(_player: Player): any
	return lastSafeSummary
end

local connection = RunService.Heartbeat:Connect(function(deltaTime)
	accumulatedSeconds += deltaTime
	if accumulatedSeconds < 0.25 then
		return
	end
	accumulatedSeconds = 0
	step()
end)

Players.PlayerAdded:Connect(function(player)
	if lastSafeSummary ~= nil then
		stateRemote:FireClient(player, lastSafeSummary)
	end
end)

game:BindToClose(function()
	connection:Disconnect()
	destroyOwners()
end)

print("[Living Kingdoms] Expedition reward/result owner mounted")
