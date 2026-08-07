--!strict

--[[
	Awards one bounded shared Field XP bonus when server-authored horde facts prove
	that a Choir Screamer died during an active reinforcement windup. This service
	observes only replicated server attributes, accepts no client request, and
	commits through RunProgressionService's existing idempotent reward boundary.

	The scan is deliberately separate from ordinary death XP so a scheduler-order
	race cannot miss the later Windup -> Interrupted transition.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local HordeExperienceConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)
local HordeSpecialTelegraphConfig = require(ReplicatedStorage.Shared.Config.HordeSpecialTelegraphConfig)
local ScreamerInterruptRewardConfig = require(ReplicatedStorage.Shared.Config.ScreamerInterruptRewardConfig)
local RelicRewardSourceConfig = require(ReplicatedStorage.Shared.Config.RelicRewardSourceConfig)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local RunBuildService = require(script.Parent.RunBuildService)
local RunProgressionService = require(script.Parent.RunProgressionService)

local LifeStateAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local DeadLifeStateId = EnemyPresentationContracts.LifeStateIds.Dead
local SpecialAttributeNames = HordeSpecialTelegraphConfig.AttributeNames
local SpecialKindIds = HordeSpecialTelegraphConfig.KindIds
local SpecialStateIds = HordeSpecialTelegraphConfig.StateIds

local ENEMY_FOLDER_NAME = "EnemyEntities"
local REWARD_ID_PREFIX = "screamer-interrupt"

local Service = {}

local started = false
local initialScanComplete = false
local interruptsSinceReward = 0
local accumulatedSeconds = 0
local heartbeatConnection: RBXScriptConnection? = nil
local rewardedSequences: { [Model]: number } = {}

local function readPositiveInteger(model: Model, attributeName: string): number?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "number" and value == value and value > 0 and value % 1 == 0 then value else nil
end

local function readNonEmptyString(model: Model, attributeName: string): string?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "string" and value ~= "" then value else nil
end

local function readConfirmedInterrupt(model: Model): (string?, number?)
	if model:GetAttribute("HordeRoleId") ~= HordeExperienceConfig.Roles.Screamer.Id then
		return nil, nil
	end
	if model:GetAttribute(LifeStateAttribute) ~= DeadLifeStateId then
		return nil, nil
	end
	if readPositiveInteger(model, HitSequenceAttribute) == nil then
		return nil, nil
	end
	if readNonEmptyString(model, SpecialAttributeNames.KindId) ~= SpecialKindIds.ScreamerReinforcement then
		return nil, nil
	end
	if readNonEmptyString(model, SpecialAttributeNames.StateId) ~= SpecialStateIds.Interrupted then
		return nil, nil
	end
	return readNonEmptyString(model, "CombatEntityId"), readPositiveInteger(model, SpecialAttributeNames.Sequence)
end

local function scanConfirmedInterrupts()
	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if folder == nil or not folder:IsA("Folder") then
		return
	end

	local seen: { [Model]: boolean } = {}
	local inspectedCount = 0
	for _, child in folder:GetChildren() do
		if inspectedCount >= ScreamerInterruptRewardConfig.MaximumTrackedEnemyModels then
			break
		end
		if not child:IsA("Model") then
			continue
		end
		inspectedCount += 1
		local model = child :: Model
		seen[model] = true

		local entityId, sequence = readConfirmedInterrupt(model)
		if entityId == nil or sequence == nil then
			continue
		end
		local previousSequence = rewardedSequences[model] or 0
		if sequence <= previousSequence then
			continue
		end
		rewardedSequences[model] = sequence
		if not initialScanComplete then
			continue
		end

		local rewardId = string.format("%s:%s:%d", REWARD_ID_PREFIX, entityId, sequence)
		if #rewardId <= ScreamerInterruptRewardConfig.MaximumRewardIdCharacters then
			RunProgressionService.awardFieldIntel(rewardId, ScreamerInterruptRewardConfig.BonusFieldXp)
			-- RPG-0110: confirmed interrupts also pay a relic choice, but on an
			-- interval rather than per interrupt, because interrupts are far more
			-- common than elite deaths.
			interruptsSinceReward += 1
			if interruptsSinceReward >= RelicRewardSourceConfig.SpecialInterruptsPerReward then
				interruptsSinceReward = 0
				RunBuildService.offerRelicRewardToParticipants(
					rewardId,
					RunRpgContracts.RewardSourceIds.SpecialInterrupt
				)
			end
		end
	end

	local staleModels: { Model } = {}
	for model in rewardedSequences do
		if seen[model] ~= true then
			table.insert(staleModels, model)
		end
	end
	for _, model in staleModels do
		rewardedSequences[model] = nil
	end
	initialScanComplete = true
end

function Service.start()
	if started then
		return
	end
	started = true
	initialScanComplete = false
	interruptsSinceReward = 0
	accumulatedSeconds = 0
	table.clear(rewardedSequences)
	scanConfirmedInterrupts()
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < ScreamerInterruptRewardConfig.ScanIntervalSeconds then
			return
		end
		accumulatedSeconds = 0
		scanConfirmedInterrupts()
	end)
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
	initialScanComplete = false
	interruptsSinceReward = 0
	accumulatedSeconds = 0
	table.clear(rewardedSequences)
end

return table.freeze(Service)
