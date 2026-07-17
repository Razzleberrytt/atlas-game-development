--!strict

--[[
	P5-0106 read-only observability for production enemy validation. This module
	creates no scheduler, instances, remotes, or authority path. Reads are fresh
	copies; sampling advances only when an authorized Studio validation caller
	explicitly invokes sample.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Enemy.EnemyContracts)
local EnemyLifecycleService = require(script.Parent.EnemyLifecycleService)
local EnemyOperationIntegrationService = require(script.Parent.EnemyOperationIntegrationService)

export type Snapshot = {
	activeEnemies: number,
	deadEnemies: number,
	totalRegisteredEnemies: number,
	ownedModels: number,
	ownedBaseParts: number,
	selectedTargets: number,
	authorizedSchedulerConnectionBudget: number,
	attackAttempts: number,
	attackCommits: number,
	sampleCount: number,
	observedSpawns: number,
	observedRemovals: number,
	observedTargetChanges: number,
	observedModelMoves: number,
	firstSampleServerTimestamp: number?,
	lastSampleServerTimestamp: number?,
}

local Service = {}
local previousTargetsByEntityId: { [string]: string? } = {}
local previousPositionsByEntityId: { [string]: Vector3 } = {}
local sampleCount = 0
local observedSpawns = 0
local observedRemovals = 0
local observedTargetChanges = 0
local observedModelMoves = 0
local firstSampleServerTimestamp: number? = nil
local lastSampleServerTimestamp: number? = nil

local function enemyFolder(): Instance?
	return Workspace:FindFirstChild(EnemyConfig.ModelFolderName)
end

local function countOwnedInstances(): (number, number)
	local folder = enemyFolder()
	if folder == nil then
		return 0, 0
	end

	local modelCount = 0
	local basePartCount = 0
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("Model") then
			modelCount += 1
		elseif descendant:IsA("BasePart") then
			basePartCount += 1
		end
	end
	return modelCount, basePartCount
end

local function rootPosition(entityId: string): Vector3?
	local folder = enemyFolder()
	local model = if folder == nil then nil else folder:FindFirstChild(entityId)
	if model == nil or not model:IsA("Model") then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

function Service.resetSampling()
	table.clear(previousTargetsByEntityId)
	table.clear(previousPositionsByEntityId)
	sampleCount = 0
	observedSpawns = 0
	observedRemovals = 0
	observedTargetChanges = 0
	observedModelMoves = 0
	firstSampleServerTimestamp = nil
	lastSampleServerTimestamp = nil
end

function Service.sample(serverTimestamp: number)
	assert(serverTimestamp == serverTimestamp and serverTimestamp >= 0 and serverTimestamp < math.huge, "invalid sample time")
	local currentTargetsByEntityId: { [string]: string? } = {}
	local currentPositionsByEntityId: { [string]: Vector3 } = {}

	for _, snapshot in EnemyLifecycleService.readAll() do
		local entityId = snapshot.entityId
		currentTargetsByEntityId[entityId] = snapshot.selectedOperativeEntityId
		local position = rootPosition(entityId)
		if position ~= nil then
			currentPositionsByEntityId[entityId] = position
		end
		if sampleCount > 0 then
			if previousTargetsByEntityId[entityId] == nil and previousPositionsByEntityId[entityId] == nil then
				observedSpawns += 1
			elseif previousTargetsByEntityId[entityId] ~= snapshot.selectedOperativeEntityId then
				observedTargetChanges += 1
			end
			local previousPosition = previousPositionsByEntityId[entityId]
			if previousPosition ~= nil and position ~= nil and (position - previousPosition).Magnitude > 0.01 then
				observedModelMoves += 1
			end
		end
	end

	if sampleCount > 0 then
		for entityId in previousPositionsByEntityId do
			if currentPositionsByEntityId[entityId] == nil and currentTargetsByEntityId[entityId] == nil then
				observedRemovals += 1
			end
		end
	end

	previousTargetsByEntityId = currentTargetsByEntityId
	previousPositionsByEntityId = currentPositionsByEntityId
	sampleCount += 1
	firstSampleServerTimestamp = firstSampleServerTimestamp or serverTimestamp
	lastSampleServerTimestamp = serverTimestamp
end

function Service.read(): Snapshot
	local activeEnemies = 0
	local deadEnemies = 0
	local totalRegisteredEnemies = 0
	local selectedTargets = 0

	for _, snapshot in EnemyLifecycleService.readAll() do
		totalRegisteredEnemies += 1
		if snapshot.lifecycleStateId == EnemyContracts.LifecycleStateIds.Active then
			activeEnemies += 1
		elseif snapshot.lifecycleStateId == EnemyContracts.LifecycleStateIds.Dead then
			deadEnemies += 1
		end
		if snapshot.selectedOperativeEntityId ~= nil then
			selectedTargets += 1
		end
	end

	local operationMetrics = EnemyOperationIntegrationService.readMetrics()
	local ownedModels, ownedBaseParts = countOwnedInstances()
	return table.freeze({
		activeEnemies = activeEnemies,
		deadEnemies = deadEnemies,
		totalRegisteredEnemies = totalRegisteredEnemies,
		ownedModels = ownedModels,
		ownedBaseParts = ownedBaseParts,
		selectedTargets = selectedTargets,
		authorizedSchedulerConnectionBudget = 2,
		attackAttempts = operationMetrics.attackAttempts,
		attackCommits = operationMetrics.attackCommits,
		sampleCount = sampleCount,
		observedSpawns = observedSpawns,
		observedRemovals = observedRemovals,
		observedTargetChanges = observedTargetChanges,
		observedModelMoves = observedModelMoves,
		firstSampleServerTimestamp = firstSampleServerTimestamp,
		lastSampleServerTimestamp = lastSampleServerTimestamp,
	})
end

return table.freeze(Service)
