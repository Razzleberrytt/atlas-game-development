--!strict

--[[
	Studio-only, read-only enemy pressure validation probe. It creates no
	production remote, scheduler, heartbeat, enemy mutation, or gameplay authority
	path. A tester may invoke ServerStorage.LivingKingdomsEnemyValidation.ReadSnapshot
	from the Studio server to capture EnemyDirectorService state during a crowd-
	pressure playthrough. Repeated reads retain bounded sample/peak/average metrics;
	ResetMetrics starts a fresh measurement window without touching gameplay state.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local EnemyDirectorService = require(script.Parent.EnemyDirectorService)

export type Snapshot = {
	serverTimestamp: number,
	activeEnemyCount: number,
	pendingSpawnCount: number,
	ownedModelCount: number,
	ownedBasePartCount: number,
	livingCombatFactCount: number,
	isPressureActive: boolean,
	isStoodDown: boolean,
	escalationLevel: number,
	nextRoamingSpawnServerTimestamp: number?,
	recoveryWindowEndServerTimestamp: number?,
	sampleCount: number,
	baselineActiveEnemyCount: number,
	baselinePendingSpawnCount: number,
	baselineEscalationLevel: number,
	peakActiveEnemyCount: number,
	peakPendingSpawnCount: number,
	peakEscalationLevel: number,
	averageActiveEnemyCount: number,
	averagePendingSpawnCount: number,
}

type RawSnapshot = {
	serverTimestamp: number,
	activeEnemyCount: number,
	pendingSpawnCount: number,
	ownedModelCount: number,
	ownedBasePartCount: number,
	livingCombatFactCount: number,
	isPressureActive: boolean,
	isStoodDown: boolean,
	escalationLevel: number,
	nextRoamingSpawnServerTimestamp: number?,
	recoveryWindowEndServerTimestamp: number?,
}

local SERVICE_FOLDER_NAME = "LivingKingdomsEnemyValidation"
local READ_FUNCTION_NAME = "ReadSnapshot"
local RESET_FUNCTION_NAME = "ResetMetrics"
local ENEMY_FOLDER_NAME = "EnemyEntities"

local Service = {}
local started = false
local ownedFolder: Folder? = nil

local sampleCount = 0
local totalActiveEnemyCount = 0
local totalPendingSpawnCount = 0
local baselineActiveEnemyCount = 0
local baselinePendingSpawnCount = 0
local baselineEscalationLevel = 0
local peakActiveEnemyCount = 0
local peakPendingSpawnCount = 0
local peakEscalationLevel = 0

local function countOwnedInstances(): (number, number)
	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if folder == nil then
		return 0, 0
	end
	local models = 0
	local baseParts = 0
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("Model") then
			models += 1
		elseif descendant:IsA("BasePart") then
			baseParts += 1
		end
	end
	return models, baseParts
end

local function readRawSnapshot(): RawSnapshot
	local pressure = EnemyDirectorService.readPressureState()
	local ownedModelCount, ownedBasePartCount = countOwnedInstances()
	return {
		serverTimestamp = Workspace:GetServerTimeNow(),
		activeEnemyCount = pressure.activeEnemyCount,
		pendingSpawnCount = pressure.pendingSpawnCount,
		ownedModelCount = ownedModelCount,
		ownedBasePartCount = ownedBasePartCount,
		livingCombatFactCount = #EnemyDirectorService.readEnemyCombatFacts(),
		isPressureActive = pressure.isPressureActive,
		isStoodDown = pressure.isStoodDown,
		escalationLevel = pressure.escalationLevel,
		nextRoamingSpawnServerTimestamp = pressure.nextRoamingSpawnServerTimestamp,
		recoveryWindowEndServerTimestamp = pressure.recoveryWindowEndServerTimestamp,
	}
end

local function resetMetricsTo(raw: RawSnapshot)
	sampleCount = 0
	totalActiveEnemyCount = 0
	totalPendingSpawnCount = 0
	baselineActiveEnemyCount = raw.activeEnemyCount
	baselinePendingSpawnCount = raw.pendingSpawnCount
	baselineEscalationLevel = raw.escalationLevel
	peakActiveEnemyCount = raw.activeEnemyCount
	peakPendingSpawnCount = raw.pendingSpawnCount
	peakEscalationLevel = raw.escalationLevel
end

local function capture(raw: RawSnapshot): Snapshot
	sampleCount += 1
	totalActiveEnemyCount += raw.activeEnemyCount
	totalPendingSpawnCount += raw.pendingSpawnCount
	peakActiveEnemyCount = math.max(peakActiveEnemyCount, raw.activeEnemyCount)
	peakPendingSpawnCount = math.max(peakPendingSpawnCount, raw.pendingSpawnCount)
	peakEscalationLevel = math.max(peakEscalationLevel, raw.escalationLevel)

	return table.freeze({
		serverTimestamp = raw.serverTimestamp,
		activeEnemyCount = raw.activeEnemyCount,
		pendingSpawnCount = raw.pendingSpawnCount,
		ownedModelCount = raw.ownedModelCount,
		ownedBasePartCount = raw.ownedBasePartCount,
		livingCombatFactCount = raw.livingCombatFactCount,
		isPressureActive = raw.isPressureActive,
		isStoodDown = raw.isStoodDown,
		escalationLevel = raw.escalationLevel,
		nextRoamingSpawnServerTimestamp = raw.nextRoamingSpawnServerTimestamp,
		recoveryWindowEndServerTimestamp = raw.recoveryWindowEndServerTimestamp,
		sampleCount = sampleCount,
		baselineActiveEnemyCount = baselineActiveEnemyCount,
		baselinePendingSpawnCount = baselinePendingSpawnCount,
		baselineEscalationLevel = baselineEscalationLevel,
		peakActiveEnemyCount = peakActiveEnemyCount,
		peakPendingSpawnCount = peakPendingSpawnCount,
		peakEscalationLevel = peakEscalationLevel,
		averageActiveEnemyCount = totalActiveEnemyCount / sampleCount,
		averagePendingSpawnCount = totalPendingSpawnCount / sampleCount,
	})
end

function Service.readSnapshot(): Snapshot
	return capture(readRawSnapshot())
end

function Service.resetMetrics(): Snapshot
	local raw = readRawSnapshot()
	resetMetricsTo(raw)
	return capture(raw)
end

function Service.start()
	if started or not RunService:IsStudio() then
		return
	end
	started = true
	local existing = ServerStorage:FindFirstChild(SERVICE_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	resetMetricsTo(readRawSnapshot())

	local folder = Instance.new("Folder")
	folder.Name = SERVICE_FOLDER_NAME
	folder.Parent = ServerStorage

	local readFunction = Instance.new("BindableFunction")
	readFunction.Name = READ_FUNCTION_NAME
	readFunction.OnInvoke = function()
		return Service.readSnapshot()
	end
	readFunction.Parent = folder

	local resetFunction = Instance.new("BindableFunction")
	resetFunction.Name = RESET_FUNCTION_NAME
	resetFunction.OnInvoke = function()
		return Service.resetMetrics()
	end
	resetFunction.Parent = folder

	ownedFolder = folder
end

function Service.stop()
	if not started then
		return
	end
	started = false
	local folder = ownedFolder
	if folder ~= nil then
		folder:Destroy()
		ownedFolder = nil
	end
end

return table.freeze(Service)
