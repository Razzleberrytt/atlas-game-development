--!strict

--[[
	HROI-0105 server-owned squad Field XP. One bounded heartbeat scan observes
	the existing server-authored enemy presentation life state and awards shared
	run XP exactly once when an enemy transitions to authoritative death.

	There is no client reward request. The only client call is a read-only state
	snapshot used to recover the initial HUD state if the first event was missed.
	Progress resets when this service starts and is never persisted.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)
local RunProgressionResolver = require(ReplicatedStorage.Shared.Progression.RunProgressionResolver)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)

local LifeStateAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local DeadLifeStateId = EnemyPresentationContracts.LifeStateIds.Dead

local ENEMY_FOLDER_NAME = "EnemyEntities"

export type SafeRunProgressionSnapshot = {
	version: string,
	revision: number,
	level: number,
	xp: number,
	xpForNextLevel: number,
	totalXp: number,
	squadKills: number,
	lastGainAmount: number,
	lastGainSequence: number,
	levelsGainedLastAward: number,
}

local RunProgressionService = {}

local started = false
local revision = 0
local level = 1
local xp = 0
local totalXp = 0
local squadKills = 0
local lastGainAmount = 0
local lastGainSequence = 0
local levelsGainedLastAward = 0
local accumulatedSeconds = 0
local initialScanComplete = false
local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local trackedLifeStates: { [Model]: string } = {}

local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local stateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction

local function safeSnapshot(): SafeRunProgressionSnapshot
	return table.freeze({
		version = RunProgressionConfig.Version,
		revision = revision,
		level = level,
		xp = xp,
		xpForNextLevel = RunProgressionResolver.xpRequiredForLevel(level),
		totalXp = totalXp,
		squadKills = squadKills,
		lastGainAmount = lastGainAmount,
		lastGainSequence = lastGainSequence,
		levelsGainedLastAward = levelsGainedLastAward,
	}) :: SafeRunProgressionSnapshot
end

local function publishAll()
	revision += 1
	stateRemote:FireAllClients(safeSnapshot())
end

local function awardConfirmedEnemyDeath()
	local amount = RunProgressionConfig.FieldXpPerConfirmedEnemyDeath
	local resolution = RunProgressionResolver.applyAward(level, xp, amount)
	if not resolution.didApply then
		return
	end
	level = resolution.levelAfter
	xp = resolution.xpAfter
	totalXp += amount
	squadKills += 1
	lastGainAmount = amount
	lastGainSequence += 1
	levelsGainedLastAward = resolution.levelsGained
	publishAll()
end

local function isTrackedEnemy(model: Model): boolean
	return model:GetAttribute("EnemyArchetypeId") == EnemyConfig.Walker.ArchetypeId
end

local function readLifeState(model: Model): string?
	local value = model:GetAttribute(LifeStateAttribute)
	return if type(value) == "string" then value else nil
end

local function hasConfirmedHit(model: Model): boolean
	local value = model:GetAttribute(HitSequenceAttribute)
	return type(value) == "number" and value > 0 and value == value
end

local function scanEnemyDeaths()
	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if folder == nil or not folder:IsA("Folder") then
		return
	end

	local seen: { [Model]: boolean } = {}
	local inspectedCount = 0
	for _, child in folder:GetChildren() do
		if inspectedCount >= RunProgressionConfig.MaximumTrackedEnemyModels then
			break
		end
		if not child:IsA("Model") or not isTrackedEnemy(child) then
			continue
		end
		inspectedCount += 1
		local model = child :: Model
		seen[model] = true
		local lifeState = readLifeState(model)
		if lifeState == nil then
			continue
		end
		local previousLifeState = trackedLifeStates[model]
		if previousLifeState == nil then
			trackedLifeStates[model] = lifeState
			if initialScanComplete and lifeState == DeadLifeStateId and hasConfirmedHit(model) then
				awardConfirmedEnemyDeath()
			end
		elseif previousLifeState ~= DeadLifeStateId and lifeState == DeadLifeStateId then
			trackedLifeStates[model] = lifeState
			awardConfirmedEnemyDeath()
		else
			trackedLifeStates[model] = lifeState
		end
	end

	local staleModels: { Model } = {}
	for model in trackedLifeStates do
		if seen[model] ~= true then
			table.insert(staleModels, model)
		end
	end
	for _, model in staleModels do
		trackedLifeStates[model] = nil
	end
	initialScanComplete = true
end

function RunProgressionService.readSafeSnapshot(): SafeRunProgressionSnapshot
	return safeSnapshot()
end

function RunProgressionService.start()
	if started then
		return
	end
	started = true
	revision = 0
	level = 1
	xp = 0
	totalXp = 0
	squadKills = 0
	lastGainAmount = 0
	lastGainSequence = 0
	levelsGainedLastAward = 0
	accumulatedSeconds = 0
	initialScanComplete = false
	table.clear(trackedLifeStates)

	readStateRemote.OnServerInvoke = function(_player: Player)
		return safeSnapshot()
	end
	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		stateRemote:FireClient(player, safeSnapshot())
	end)
	scanEnemyDeaths()
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulatedSeconds += deltaTime
		if accumulatedSeconds < RunProgressionConfig.EnemyScanIntervalSeconds then
			return
		end
		accumulatedSeconds = 0
		scanEnemyDeaths()
	end)
end

function RunProgressionService.stop()
	if not started then
		return
	end
	started = false
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	readStateRemote.OnServerInvoke = nil
	table.clear(trackedLifeStates)
	accumulatedSeconds = 0
	initialScanComplete = false
end

return table.freeze(RunProgressionService)
