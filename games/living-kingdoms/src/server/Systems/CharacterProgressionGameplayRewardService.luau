--!strict

-- Server-only bridge from already-authoritative gameplay facts into durable
-- character XP. It does not accept client requests and does not decide combat
-- outcomes or expedition success; it observes the existing server owners.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.CharacterProgressionConfig)
local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local ExpeditionRewardDispositionResolver =
	require(ReplicatedStorage.Shared.Expeditions.ExpeditionRewardDispositionResolver)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local CharacterProgressionService = require(script.Parent.CharacterProgressionService)
local ExpeditionLiveRuntimeService = require(script.Parent.ExpeditionLiveRuntimeService)
local ExpeditionRunRosterService = require(script.Parent.ExpeditionRunRosterService)

local ENEMY_FOLDER_NAME = "EnemyEntities"
local LifeStateAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local DeadLifeStateId = EnemyPresentationContracts.LifeStateIds.Dead

local Service = {}

local started = false
local accumulatedSeconds = 0
local initialEnemyScanComplete = false
local heartbeatConnection: RBXScriptConnection? = nil
local trackedLifeStates: { [Model]: string } = {}
local completedDungeonAwards: { [string]: { [number]: boolean } } = {}

local function confirmedHit(model: Model): boolean
	local value = model:GetAttribute(HitSequenceAttribute)
	return type(value) == "number" and value == value and value > 0
end

local function enemyAttributionId(model: Model): string
	local entityId = model:GetAttribute("CombatEntityId")
	if type(entityId) == "string" and entityId ~= "" then
		return "enemy:" .. entityId
	end
	return "enemy-instance:" .. model:GetDebugId(32)
end

local function awardEnemyDeath(model: Model)
	if not confirmedHit(model) then
		return
	end
	local attributionId = enemyAttributionId(model)
	for _, player in Players:GetPlayers() do
		local outcome = CharacterProgressionService.awardXP(
			player,
			Config.RewardXP.EnemyKill,
			Config.SourceIds.EnemyKill,
			attributionId
		)
		if outcome.Accepted ~= true and outcome.ReasonId ~= "ProgressionNotLoaded" then
			warn(
				string.format(
					"[CharacterProgressionRewards] enemy XP rejected for %d: %s",
					player.UserId,
					tostring(outcome.ReasonId)
				)
			)
		end
	end
end

local function scanEnemyDeaths()
	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if folder == nil then
		return
	end
	local seen: { [Model]: boolean } = {}
	for _, instance in folder:GetChildren() do
		if not instance:IsA("Model") then
			continue
		end
		local model = instance :: Model
		seen[model] = true
		local lifeState = model:GetAttribute(LifeStateAttribute)
		if type(lifeState) ~= "string" then
			continue
		end
		local previous = trackedLifeStates[model]
		if previous == nil then
			trackedLifeStates[model] = lifeState
			if initialEnemyScanComplete and lifeState == DeadLifeStateId then
				awardEnemyDeath(model)
			end
		elseif previous ~= DeadLifeStateId and lifeState == DeadLifeStateId then
			trackedLifeStates[model] = lifeState
			awardEnemyDeath(model)
		else
			trackedLifeStates[model] = lifeState
		end
	end
	for model in trackedLifeStates do
		if seen[model] ~= true then
			trackedLifeStates[model] = nil
		end
	end
	initialEnemyScanComplete = true
end

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
		elseif outcome.ReasonId ~= "ProgressionNotLoaded" then
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
	scanEnemyDeaths()
	awardDungeonCompletion()
end

function Service.start()
	if started then
		return
	end
	started = true
	accumulatedSeconds = 0
	initialEnemyScanComplete = false
	table.clear(trackedLifeStates)
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
	table.clear(trackedLifeStates)
	table.clear(completedDungeonAwards)
end

return table.freeze(Service)
