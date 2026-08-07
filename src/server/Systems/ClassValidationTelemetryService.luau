--!strict

--[[
	P7-0107 bounded read-only validation ledger. Authoritative class owners record
	already-committed lifecycle facts; this module cannot activate actions, spend
	resources, heal, grant ammunition, schedule work, or expose a remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)

local ActionIds = ClassContracts.ClassActionIds
local ClassIds = ClassContracts.ClassIds

export type ActionSnapshot = {
	actionId: string,
	availableCount: number,
	startCount: number,
	completionCount: number,
	interruptionCount: number,
	cooldownCount: number,
	activeSeconds: number,
	isActive: boolean,
}

export type OperativeSnapshot = {
	operativeEntityId: string,
	classId: string,
	isConnected: boolean,
	resourceIssued: number,
	resourceSpent: number,
	resourceRemaining: number,
	healthRestored: number,
	ammunitionGranted: number,
	actions: { ActionSnapshot },
}

export type Snapshot = {
	trackedOperativeCount: number,
	connectedOperativeCount: number,
	actionStartCount: number,
	actionCompletionCount: number,
	actionInterruptionCount: number,
	activeSeconds: number,
	resourceIssued: number,
	resourceSpent: number,
	resourceRemaining: number,
	healthRestored: number,
	ammunitionGranted: number,
	operatives: { OperativeSnapshot },
}

type ActionMetrics = {
	actionId: string,
	availableCount: number,
	startCount: number,
	completionCount: number,
	interruptionCount: number,
	cooldownCount: number,
	activeSeconds: number,
	activeStartedAt: number?,
}

type OperativeMetrics = {
	operativeEntityId: string,
	classId: string,
	isConnected: boolean,
	resourceIssued: number,
	resourceSpent: number,
	resourceRemaining: number,
	healthRestored: number,
	ammunitionGranted: number,
	actions: { [string]: ActionMetrics },
}

local MAXIMUM_TRACKED_OPERATIVES = 8
local Service = {}
local metricsByOperativeId: { [string]: OperativeMetrics } = {}

local function isFiniteNonnegative(value: number): boolean
	return value == value and value >= 0 and value < math.huge
end

local function actionIdsForClass(classId: string): { string }
	if classId == ClassIds.Medic then
		return { ActionIds.FieldTreatment, ActionIds.ReviveAssistance }
	elseif classId == ClassIds.Engineer then
		return { ActionIds.FieldResupply }
	end
	return { ActionIds.Brace }
end

local function countTracked(): number
	local count = 0
	for _ in metricsByOperativeId do
		count += 1
	end
	return count
end

function Service.reset()
	table.clear(metricsByOperativeId)
end

function Service.assign(operativeEntityId: string, classId: string, resourceIssued: number)
	assert(operativeEntityId ~= "" and ClassContracts.isKnownClassId(classId), "invalid class telemetry assignment")
	assert(isFiniteNonnegative(resourceIssued), "invalid issued class resource")
	assert(
		metricsByOperativeId[operativeEntityId] ~= nil or countTracked() < MAXIMUM_TRACKED_OPERATIVES,
		"class telemetry operative bound exceeded"
	)
	local actions: { [string]: ActionMetrics } = {}
	for _, actionId in actionIdsForClass(classId) do
		actions[actionId] = {
			actionId = actionId,
			availableCount = 1,
			startCount = 0,
			completionCount = 0,
			interruptionCount = 0,
			cooldownCount = 0,
			activeSeconds = 0,
			activeStartedAt = nil,
		}
	end
	metricsByOperativeId[operativeEntityId] = {
		operativeEntityId = operativeEntityId,
		classId = classId,
		isConnected = true,
		resourceIssued = resourceIssued,
		resourceSpent = 0,
		resourceRemaining = resourceIssued,
		healthRestored = 0,
		ammunitionGranted = 0,
		actions = actions,
	}
end

function Service.setConnected(operativeEntityId: string, isConnected: boolean)
	local metrics = metricsByOperativeId[operativeEntityId]
	if metrics ~= nil then
		metrics.isConnected = isConnected
	end
end

function Service.recordActionStarted(operativeEntityId: string, actionId: string, serverTimestamp: number)
	assert(isFiniteNonnegative(serverTimestamp), "invalid class action start time")
	local metrics = metricsByOperativeId[operativeEntityId]
	local action = if metrics == nil then nil else metrics.actions[actionId]
	if action == nil or action.activeStartedAt ~= nil then
		return
	end
	action.startCount += 1
	action.activeStartedAt = serverTimestamp
end

function Service.recordActionEnded(
	operativeEntityId: string,
	actionId: string,
	serverTimestamp: number,
	didComplete: boolean,
	didEnterCooldown: boolean
)
	assert(isFiniteNonnegative(serverTimestamp), "invalid class action end time")
	local metrics = metricsByOperativeId[operativeEntityId]
	local action = if metrics == nil then nil else metrics.actions[actionId]
	if action == nil or action.activeStartedAt == nil then
		return
	end
	action.activeSeconds += math.max(0, serverTimestamp - action.activeStartedAt)
	action.activeStartedAt = nil
	if didComplete then
		action.completionCount += 1
	else
		action.interruptionCount += 1
	end
	if didEnterCooldown then
		action.cooldownCount += 1
	end
end

function Service.recordActionAvailable(operativeEntityId: string, actionId: string)
	local metrics = metricsByOperativeId[operativeEntityId]
	local action = if metrics == nil then nil else metrics.actions[actionId]
	if action ~= nil then
		action.availableCount += 1
	end
end

function Service.recordResourceCommit(
	operativeEntityId: string,
	resourceSpent: number,
	healthRestored: number,
	ammunitionGranted: number
)
	assert(
		isFiniteNonnegative(resourceSpent)
			and isFiniteNonnegative(healthRestored)
			and isFiniteNonnegative(ammunitionGranted),
		"invalid class resource commit"
	)
	local metrics = metricsByOperativeId[operativeEntityId]
	if metrics == nil then
		return
	end
	local acceptedSpend = math.min(resourceSpent, metrics.resourceRemaining)
	metrics.resourceSpent += acceptedSpend
	metrics.resourceRemaining -= acceptedSpend
	metrics.healthRestored += healthRestored
	metrics.ammunitionGranted += ammunitionGranted
end

function Service.read(): Snapshot
	local operatives: { OperativeSnapshot } = {}
	local connectedOperativeCount = 0
	local actionStartCount = 0
	local actionCompletionCount = 0
	local actionInterruptionCount = 0
	local activeSeconds = 0
	local resourceIssued = 0
	local resourceSpent = 0
	local resourceRemaining = 0
	local healthRestored = 0
	local ammunitionGranted = 0
	for _, metrics in metricsByOperativeId do
		local actions: { ActionSnapshot } = {}
		for _, action in metrics.actions do
			table.insert(
				actions,
				table.freeze({
					actionId = action.actionId,
					availableCount = action.availableCount,
					startCount = action.startCount,
					completionCount = action.completionCount,
					interruptionCount = action.interruptionCount,
					cooldownCount = action.cooldownCount,
					activeSeconds = action.activeSeconds,
					isActive = action.activeStartedAt ~= nil,
				})
			)
			actionStartCount += action.startCount
			actionCompletionCount += action.completionCount
			actionInterruptionCount += action.interruptionCount
			activeSeconds += action.activeSeconds
		end
		table.sort(actions, function(left, right)
			return left.actionId < right.actionId
		end)
		table.freeze(actions)
		table.insert(
			operatives,
			table.freeze({
				operativeEntityId = metrics.operativeEntityId,
				classId = metrics.classId,
				isConnected = metrics.isConnected,
				resourceIssued = metrics.resourceIssued,
				resourceSpent = metrics.resourceSpent,
				resourceRemaining = metrics.resourceRemaining,
				healthRestored = metrics.healthRestored,
				ammunitionGranted = metrics.ammunitionGranted,
				actions = actions,
			})
		)
		if metrics.isConnected then
			connectedOperativeCount += 1
		end
		resourceIssued += metrics.resourceIssued
		resourceSpent += metrics.resourceSpent
		resourceRemaining += metrics.resourceRemaining
		healthRestored += metrics.healthRestored
		ammunitionGranted += metrics.ammunitionGranted
	end
	table.sort(operatives, function(left, right)
		return left.operativeEntityId < right.operativeEntityId
	end)
	table.freeze(operatives)
	return table.freeze({
		trackedOperativeCount = #operatives,
		connectedOperativeCount = connectedOperativeCount,
		actionStartCount = actionStartCount,
		actionCompletionCount = actionCompletionCount,
		actionInterruptionCount = actionInterruptionCount,
		activeSeconds = activeSeconds,
		resourceIssued = resourceIssued,
		resourceSpent = resourceSpent,
		resourceRemaining = resourceRemaining,
		healthRestored = healthRestored,
		ammunitionGranted = ammunitionGranted,
		operatives = operatives,
	})
end

return table.freeze(Service)
