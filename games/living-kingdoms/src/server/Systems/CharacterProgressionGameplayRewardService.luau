--!strict

-- Server-only bridge from already-authoritative gameplay facts into durable
-- character XP. It does not accept client requests and does not decide combat
-- outcomes or expedition success; it observes the existing server owners.
--
-- Enemy kill/assist XP is deliberately NOT emitted here yet. Current main does
-- not expose a trusted per-enemy contributor ledger, so inferring attribution
-- from presentation hit/death state would risk rewarding uninvolved players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.CharacterProgressionConfig)
local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local ExpeditionRewardDispositionResolver =
	require(ReplicatedStorage.Shared.Expeditions.ExpeditionRewardDispositionResolver)
local CharacterProgressionService = require(script.Parent.CharacterProgressionService)
local ExpeditionLiveRuntimeService = require(script.Parent.ExpeditionLiveRuntimeService)
local ExpeditionRunRosterService = require(script.Parent.ExpeditionRunRosterService)

local Service = {}

local started = false
local accumulatedSeconds = 0
local heartbeatConnection: RBXScriptConnection? = nil
local completedDungeonAwards: { [string]: { [number]: boolean } = {}

local function awardDungeonCompletion()
	local snapshot = ExpeditionLiveRuntimeService.readSnapshot()
	if snapshot == nil or snapshot.OutcomeId == ExpeditionContracts.OutcomeIds.InProgress then
		return
	end
	if not ExpeditionRewardDispositionResolver.shouldPersist(snapshot.OutcomeId) then
		return
	end
	local roster = ExpeditionRunRosterService.read(snapshot.RunId)
	if roster == nil or roster.ParticipantCount ~= snapshot.PartySize then
		return
	end

	local completedForRun = completedDungeonAwards[snapshot.RunId]
	if completedForRun == nil then
		completedForRun = {}
		completedDungeonAwards[snapshot.RunId] = completedForRun
	end
	for _, userId in roster.ParticipantUserIds do
		if completedForRun[userId] then
			continue
		end
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			continue
		end
		local outcome = CharacterProgressionService.awardXP(
			player,
			Config.RewardXP.DungeonCompletion,
			Config.SourceIds.DungeonCompletion,
			"expedition:" .. snapshot.RunId .. ":completion"
		)
		if outcome.Accepted == true then
			completedForRun[userId] = true
		elseif outcome.ReasonId ~= "ProgressionNotLoaded" and outcome.ReasonId ~= "ProgressionPersistenceUnavailable" then
			warn(
				string.format(
					"[CharacterProgressionRewards] dungeon XP rejected for %d on %s: %s",
					userId,
					snapshot.RunId,
					tostring(outcome.ReasonId)
				)
			)
		end
	end
end

local function step(deltaTime: number)
	accumulatedSeconds += deltaTime
	if accumulatedSeconds < 0.2 then
		return
	end
	accumulatedSeconds = 0
	awardDungeonCompletion()
end

function Service.start()
	if started then
		return
	end
	started = true
	accumulatedSeconds = 0
	table.clear(completedDungeonAwards)
	heartbeatConnection = RunService.Heartbeat:Connect(step)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	table.clear(completedDungeonAwards)
end

return table.freeze(Service)
