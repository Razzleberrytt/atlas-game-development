--!strict

--[[
	HROI-0105 server-owned squad Field XP and run upgrades. One bounded heartbeat
	scan observes existing server-authored enemy death state and awards shared XP
	exactly once. Level thresholds create three server-generated upgrade choices;
	the first valid squad selection applies one bounded run-only modifier.

	Clients may submit only one offered upgrade ID. They cannot submit kills, XP,
	levels, stacks, modifier values, reward amounts, or combat outcomes. Applied
	combat modifiers are published as server-owned attributes on the progression
	network and reset whenever this service starts or stops.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)
local RunProgressionResolver = require(ReplicatedStorage.Shared.Progression.RunProgressionResolver)
local RunUpgradeResolver = require(ReplicatedStorage.Shared.Progression.RunUpgradeResolver)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)

local LifeStateAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local HitSequenceAttribute = EnemyPresentationContracts.AttributeNames.HitSequence
local DeadLifeStateId = EnemyPresentationContracts.LifeStateIds.Dead

local ENEMY_FOLDER_NAME = "EnemyEntities"

export type PublicUpgradeChoice = {
	id: string,
	name: string,
	description: string,
	stacks: number,
	maximumStacks: number,
}

export type PublicActiveUpgrade = {
	id: string,
	name: string,
	stacks: number,
}

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
	pendingChoices: { PublicUpgradeChoice },
	activeUpgrades: { PublicActiveUpgrade },
	unclaimedUpgradeChoices: number,
	selectionSequence: number,
	lastSelectedUpgradeId: string,
	lastSelectedUpgradeName: string,
	lastSelectedUpgradeStack: number,
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
local unclaimedUpgradeChoices = 0
local offerSequence = 0
local selectionSequence = 0
local lastSelectedUpgradeId = ""
local lastSelectedUpgradeName = ""
local lastSelectedUpgradeStack = 0
local heartbeatConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local choiceConnection: RBXScriptConnection? = nil
local trackedLifeStates: { [Model]: string } = {}
local upgradeStacks: RunUpgradeResolver.UpgradeStacks = {}
local pendingChoiceIds: { string } = {}
local lastUpgradeRequestTimestamps: { [Player]: number } = {}

local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local stateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction
local chooseUpgradeRemote = progressionNetwork:WaitForChild("ChooseUpgrade") :: RemoteEvent

local function publicPendingChoices(): { PublicUpgradeChoice }
	local result = {}
	for _, upgradeId in pendingChoiceIds do
		local definition = RunUpgradeResolver.readDefinition(upgradeId)
		if definition ~= nil then
			table.insert(result, {
				id = definition.Id,
				name = definition.Name,
				description = definition.Description,
				stacks = upgradeStacks[definition.Id] or 0,
				maximumStacks = definition.MaximumStacks,
			})
		end
	end
	return result
end

local function publicActiveUpgrades(): { PublicActiveUpgrade }
	local result = {}
	for _, definition in RunProgressionConfig.UpgradeDefinitions do
		local stacks = upgradeStacks[definition.Id] or 0
		if stacks > 0 then
			table.insert(result, {
				id = definition.Id,
				name = definition.Name,
				stacks = stacks,
			})
		end
	end
	return result
end

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
		pendingChoices = publicPendingChoices(),
		activeUpgrades = publicActiveUpgrades(),
		unclaimedUpgradeChoices = unclaimedUpgradeChoices,
		selectionSequence = selectionSequence,
		lastSelectedUpgradeId = lastSelectedUpgradeId,
		lastSelectedUpgradeName = lastSelectedUpgradeName,
		lastSelectedUpgradeStack = lastSelectedUpgradeStack,
	}) :: SafeRunProgressionSnapshot
end

local function syncCombatModifierAttributes()
	local modifiers = RunUpgradeResolver.deriveCombatModifiers(upgradeStacks)
	progressionNetwork:SetAttribute("RunDamageMultiplier", modifiers.damageMultiplier)
	progressionNetwork:SetAttribute("RunCadenceMultiplier", modifiers.cadenceMultiplier)
	progressionNetwork:SetAttribute("RunAmmoConservationChance", modifiers.ammoConservationChance)
	progressionNetwork:SetAttribute("RunCullDamageMultiplier", modifiers.cullDamageMultiplier)
	progressionNetwork:SetAttribute("RunCullHealthThreshold", modifiers.cullHealthThreshold)
end

local function publishAll()
	revision += 1
	stateRemote:FireAllClients(safeSnapshot())
end

local function generatePendingChoices()
	if #pendingChoiceIds > 0 or unclaimedUpgradeChoices <= 0 then
		return
	end
	offerSequence += 1
	local generated = RunUpgradeResolver.generateChoices(upgradeStacks, offerSequence, squadKills)
	table.clear(pendingChoiceIds)
	for _, upgradeId in generated do
		table.insert(pendingChoiceIds, upgradeId)
	end
	if #pendingChoiceIds == 0 then
		unclaimedUpgradeChoices = 0
	end
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
	if resolution.levelsGained > 0 then
		unclaimedUpgradeChoices += resolution.levelsGained
		generatePendingChoices()
	end
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

local function onChooseUpgrade(player: Player, selectedUpgradeId: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(selectedUpgradeId) ~= "string" or #pendingChoiceIds == 0 then
		return
	end
	local serverTimestamp = Workspace:GetServerTimeNow()
	local previousRequestTimestamp = lastUpgradeRequestTimestamps[player] or -math.huge
	if serverTimestamp - previousRequestTimestamp < RunProgressionConfig.UpgradeRequestCooldownSeconds then
		return
	end
	lastUpgradeRequestTimestamps[player] = serverTimestamp

	local resolution = RunUpgradeResolver.applyChoice(upgradeStacks, pendingChoiceIds, selectedUpgradeId)
	if not resolution.didApply or resolution.upgradeId == nil then
		return
	end
	upgradeStacks = table.clone(resolution.stacksAfter)
	local definition = RunUpgradeResolver.readDefinition(resolution.upgradeId)
	if definition == nil then
		return
	end

	unclaimedUpgradeChoices = math.max(0, unclaimedUpgradeChoices - 1)
	selectionSequence += 1
	lastSelectedUpgradeId = definition.Id
	lastSelectedUpgradeName = definition.Name
	lastSelectedUpgradeStack = resolution.stackAfter
	table.clear(pendingChoiceIds)
	generatePendingChoices()
	syncCombatModifierAttributes()
	publishAll()
end

function RunProgressionService.readSafeSnapshot(): SafeRunProgressionSnapshot
	return safeSnapshot()
end

function RunProgressionService.readCombatModifiers(): RunUpgradeResolver.CombatModifiers
	return RunUpgradeResolver.deriveCombatModifiers(upgradeStacks)
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
	unclaimedUpgradeChoices = 0
	offerSequence = 0
	selectionSequence = 0
	lastSelectedUpgradeId = ""
	lastSelectedUpgradeName = ""
	lastSelectedUpgradeStack = 0
	table.clear(trackedLifeStates)
	table.clear(upgradeStacks)
	table.clear(pendingChoiceIds)
	table.clear(lastUpgradeRequestTimestamps)
	syncCombatModifierAttributes()

	readStateRemote.OnServerInvoke = function(_player: Player)
		return safeSnapshot()
	end
	choiceConnection = chooseUpgradeRemote.OnServerEvent:Connect(onChooseUpgrade)
	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		stateRemote:FireClient(player, safeSnapshot())
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		lastUpgradeRequestTimestamps[player] = nil
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
	for _, connection in { heartbeatConnection, playerAddedConnection, playerRemovingConnection, choiceConnection } do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	heartbeatConnection = nil
	playerAddedConnection = nil
	playerRemovingConnection = nil
	choiceConnection = nil
	readStateRemote.OnServerInvoke = nil
	table.clear(trackedLifeStates)
	table.clear(upgradeStacks)
	table.clear(pendingChoiceIds)
	table.clear(lastUpgradeRequestTimestamps)
	syncCombatModifierAttributes()
	accumulatedSeconds = 0
	initialScanComplete = false
end

return table.freeze(RunProgressionService)
