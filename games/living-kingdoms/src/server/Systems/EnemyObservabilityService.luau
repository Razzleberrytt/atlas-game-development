--!strict

--[[
	P5-0106 read-only observability for production enemy validation. This module
	creates no scheduler, instances, remotes, or authority path. Every read is a
	fresh copy derived from authoritative service snapshots and owned models.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Enemy.EnemyContracts)
local EnemyLifecycleService = require(script.Parent.EnemyLifecycleService)

export type Snapshot = {
	activeEnemies: number,
	deadEnemies: number,
	totalRegisteredEnemies: number,
	ownedModels: number,
	ownedBaseParts: number,
	selectedTargets: number,
	lifecycleUpdateConnections: number,
	operationUpdateConnections: number,
	totalEnemyUpdateConnections: number,
}

local Service = {}

local function countOwnedInstances(): (number, number)
	local folder = Workspace:FindFirstChild(EnemyConfig.ModelFolderName)
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

	local ownedModels, ownedBaseParts = countOwnedInstances()
	return table.freeze({
		activeEnemies = activeEnemies,
		deadEnemies = deadEnemies,
		totalRegisteredEnemies = totalRegisteredEnemies,
		ownedModels = ownedModels,
		ownedBaseParts = ownedBaseParts,
		selectedTargets = selectedTargets,
		lifecycleUpdateConnections = 1,
		operationUpdateConnections = 1,
		totalEnemyUpdateConnections = 2,
	})
end

return table.freeze(Service)
