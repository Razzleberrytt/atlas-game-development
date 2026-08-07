--!strict

--[[
	Unbootstrapped server-only owner for gameplay-light activation state. It
	stores validated gameplay definitions separately from the deliberately flat
	runtime records exposed to consumers. It performs no spatial query,
	visibility evaluation, raycast, rendering, replication, or client work.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameplayLightingConfig = require(ReplicatedStorage.Shared.Config.GameplayLightingConfig)
local GameplayLightContracts = require(ReplicatedStorage.Shared.Lighting.GameplayLightContracts)
local GameplayLightDescriptorValidator = require(ReplicatedStorage.Shared.Lighting.GameplayLightDescriptorValidator)

export type GameplayLightRecord = {
	lightId: string,
	sourceId: string,
	visibilityProfileId: string,
	activationStateId: string,
	activatedAtServerTimestamp: number?,
	expiresAtServerTimestamp: number?,
	revision: number,
}

export type GameplayLightingSnapshot = {
	revision: number,
	records: { GameplayLightRecord },
}

export type GameplayLightingChange = {
	revision: number,
	changedRecords: { GameplayLightRecord },
	removedLightIds: { string },
}

export type OperationResult = {
	didChange: boolean,
	rejectionReasonId: string?,
	revision: number?,
	snapshot: GameplayLightingSnapshot?,
}

type GameplayLightDefinition = {
	sourceId: string,
	sourceTypeId: string,
	visibilityProfileId: string,
	coverage: { [string]: any },
	ownerEntityId: string?,
}

type StoredLight = {
	definition: GameplayLightDefinition,
	record: GameplayLightRecord,
	lastTransitionServerTimestamp: number?,
}

type Listener = (change: GameplayLightingChange) -> ()

type ListenerConnection = {
	Disconnect: (self: ListenerConnection) -> (),
}

local GameplayLightingService = {}

GameplayLightingService.RejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidLightIdentity = "InvalidLightIdentity",
	DuplicateLightIdentity = "DuplicateLightIdentity",
	UnknownLight = "UnknownLight",
})

local ACTIVE = GameplayLightContracts.GameplayLightActivationStateIds.Active
local INACTIVE = GameplayLightContracts.GameplayLightActivationStateIds.Inactive
local EXPIRED = GameplayLightContracts.GameplayLightActivationStateIds.Expired
local APPROVED_TEMPORARY = GameplayLightContracts.GameplayLightSourceTypeIds.ApprovedTemporary
local INVALID_DESCRIPTOR = GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidDescriptor
local INVALID_ACTIVATION_STATE = GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidActivationState
local INVALID_TIMESTAMP = GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidTimestamp
local INVALID_LIFETIME = GameplayLightContracts.GameplayLightRejectionReasonIds.InvalidLifetime
local BUDGET_EXCEEDED = GameplayLightContracts.GameplayLightRejectionReasonIds.BudgetExceeded
local STALE_TRANSITION = GameplayLightContracts.GameplayLightRejectionReasonIds.StaleTransition
local EXPIRY_SCHEDULER_EPSILON_SECONDS = 0.001

local lights: { [string]: StoredLight } = {}
local listeners: { [number]: Listener } = {}
local nextListenerId = 0
local revision = 0
local started = false
local timerGeneration = 0
local scheduledThread: any = nil

local scheduleNextExpiry: () -> ()

local function isNonemptyString(value: unknown): boolean
	return typeof(value) == "string" and #value > 0
end

local function isFiniteNonnegativeNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function rejected(reason: string): OperationResult
	return {
		didChange = false,
		rejectionReasonId = reason,
		revision = nil,
		snapshot = nil,
	}
end

local function copyRecord(record: GameplayLightRecord): GameplayLightRecord
	return table.freeze({
		lightId = record.lightId,
		sourceId = record.sourceId,
		visibilityProfileId = record.visibilityProfileId,
		activationStateId = record.activationStateId,
		activatedAtServerTimestamp = record.activatedAtServerTimestamp,
		expiresAtServerTimestamp = record.expiresAtServerTimestamp,
		revision = record.revision,
	})
end

local function copySnapshot(): GameplayLightingSnapshot
	local records = {}
	for _, stored in lights do
		table.insert(records, copyRecord(stored.record))
	end
	table.sort(records, function(left, right)
		return left.lightId < right.lightId
	end)
	return table.freeze({
		revision = revision,
		records = table.freeze(records),
	})
end

local function copyChange(change: GameplayLightingChange): GameplayLightingChange
	local changedRecords = {}
	for _, record in change.changedRecords do
		table.insert(changedRecords, copyRecord(record))
	end
	return table.freeze({
		revision = change.revision,
		changedRecords = table.freeze(changedRecords),
		removedLightIds = table.freeze(table.clone(change.removedLightIds)),
	})
end

local function notify(change: GameplayLightingChange)
	for _, listener in listeners do
		pcall(listener, copyChange(change))
	end
end

local function commit(changed: { StoredLight }, removedLightIds: { string }): OperationResult
	if #changed == 0 and #removedLightIds == 0 then
		return {
			didChange = false,
			rejectionReasonId = nil,
			revision = revision,
			snapshot = copySnapshot(),
		}
	end

	table.sort(changed, function(left, right)
		return left.record.lightId < right.record.lightId
	end)
	table.sort(removedLightIds)
	revision += 1
	local changedRecords = {}
	for _, stored in changed do
		stored.record.revision += 1
		table.insert(changedRecords, copyRecord(stored.record))
	end
	local change: GameplayLightingChange = {
		revision = revision,
		changedRecords = changedRecords,
		removedLightIds = removedLightIds,
	}
	notify(change)
	return {
		didChange = true,
		rejectionReasonId = nil,
		revision = revision,
		snapshot = copySnapshot(),
	}
end

local function cancelScheduledExpiry()
	timerGeneration += 1
	if scheduledThread ~= nil then
		task.cancel(scheduledThread)
		scheduledThread = nil
	end
end

local function nextExpiry(): (number?, string?, number?)
	local earliestExpiry = nil
	local earliestLightId = nil
	local earliestRecordRevision = nil
	for lightId, stored in lights do
		local record = stored.record
		local expiry = record.expiresAtServerTimestamp
		if
			record.activationStateId == ACTIVE
			and expiry ~= nil
			and (
				earliestExpiry == nil
				or expiry < earliestExpiry
				or (expiry == earliestExpiry and lightId < (earliestLightId :: string))
			)
		then
			earliestExpiry = expiry
			earliestLightId = lightId
			earliestRecordRevision = record.revision
		end
	end
	return earliestExpiry, earliestLightId, earliestRecordRevision
end

function GameplayLightingService.evaluateExpiriesAt(serverTimestamp: number): OperationResult
	if not started then
		return rejected(GameplayLightingService.RejectionReasonIds.ServiceStopped)
	end
	if not isFiniteNonnegativeNumber(serverTimestamp) then
		return rejected(INVALID_TIMESTAMP)
	end

	local changed = {}
	local lightIds = {}
	for lightId in lights do
		table.insert(lightIds, lightId)
	end
	table.sort(lightIds)
	for _, lightId in lightIds do
		local stored = lights[lightId]
		local record = stored.record
		local expiry = record.expiresAtServerTimestamp
		if record.activationStateId == ACTIVE and expiry ~= nil and serverTimestamp >= expiry then
			record.activationStateId = EXPIRED
			record.activatedAtServerTimestamp = nil
			record.expiresAtServerTimestamp = nil
			stored.lastTransitionServerTimestamp = expiry
			table.insert(changed, stored)
		end
	end
	local result = commit(changed, {})
	scheduleNextExpiry()
	return result
end

scheduleNextExpiry = function()
	cancelScheduledExpiry()
	if not started then
		return
	end
	local expiry, lightId, recordRevision = nextExpiry()
	if expiry == nil or lightId == nil or recordRevision == nil then
		return
	end
	local generation = timerGeneration
	local expectedExpiry = expiry
	scheduledThread = task.delay(
		math.max(0, expiry - Workspace:GetServerTimeNow() + EXPIRY_SCHEDULER_EPSILON_SECONDS),
		function()
			scheduledThread = nil
			if not started or generation ~= timerGeneration then
				return
			end
			local stored = lights[lightId]
			local record = if stored == nil then nil else stored.record
			if
				record == nil
				or record.revision ~= recordRevision
				or record.activationStateId ~= ACTIVE
				or record.expiresAtServerTimestamp ~= expectedExpiry
			then
				return
			end
			GameplayLightingService.evaluateExpiriesAt(Workspace:GetServerTimeNow())
		end
	)
end

local function activeLightCount(): number
	local count = 0
	for _, stored in lights do
		if stored.record.activationStateId == ACTIVE then
			count += 1
		end
	end
	return count
end

local function copyDefinition(descriptor: any): GameplayLightDefinition
	return {
		sourceId = descriptor.sourceId,
		sourceTypeId = descriptor.sourceTypeId,
		visibilityProfileId = descriptor.visibilityProfileId,
		coverage = table.clone(descriptor.coverage),
		ownerEntityId = descriptor.ownerEntityId,
	}
end

function GameplayLightingService.start()
	if started then
		return
	end
	started = true
	scheduleNextExpiry()
end

function GameplayLightingService.stop()
	if not started then
		return
	end
	started = false
	cancelScheduledExpiry()
	table.clear(lights)
	table.clear(listeners)
	nextListenerId = 0
	revision = 0
end

function GameplayLightingService.registerLight(lightId: string, descriptor: unknown): OperationResult
	if not started then
		return rejected(GameplayLightingService.RejectionReasonIds.ServiceStopped)
	end
	if not isNonemptyString(lightId) then
		return rejected(GameplayLightingService.RejectionReasonIds.InvalidLightIdentity)
	end
	if lights[lightId] ~= nil then
		return rejected(GameplayLightingService.RejectionReasonIds.DuplicateLightIdentity)
	end
	local validation = GameplayLightDescriptorValidator.validate(descriptor)
	if not validation.isValid then
		return rejected(validation.rejectionReasonId or INVALID_DESCRIPTOR)
	end
	local canonicalDescriptor = descriptor :: any
	if canonicalDescriptor.activation.stateId ~= INACTIVE then
		return rejected(INVALID_ACTIVATION_STATE)
	end

	local stored: StoredLight = {
		definition = copyDefinition(canonicalDescriptor),
		record = {
			lightId = lightId,
			sourceId = canonicalDescriptor.sourceId,
			visibilityProfileId = canonicalDescriptor.visibilityProfileId,
			activationStateId = INACTIVE,
			activatedAtServerTimestamp = nil,
			expiresAtServerTimestamp = nil,
			revision = 0,
		},
		lastTransitionServerTimestamp = nil,
	}
	lights[lightId] = stored
	return commit({ stored }, {})
end

function GameplayLightingService.activateLight(
	lightId: string,
	activatedAtServerTimestamp: number,
	expiresAtServerTimestamp: number?
): OperationResult
	if not started then
		return rejected(GameplayLightingService.RejectionReasonIds.ServiceStopped)
	end
	local stored = lights[lightId]
	if stored == nil then
		return rejected(GameplayLightingService.RejectionReasonIds.UnknownLight)
	end
	if
		not isFiniteNonnegativeNumber(activatedAtServerTimestamp)
		or (expiresAtServerTimestamp ~= nil and not isFiniteNonnegativeNumber(expiresAtServerTimestamp))
	then
		return rejected(INVALID_TIMESTAMP)
	end

	local record = stored.record
	if
		record.activationStateId == ACTIVE
		and record.activatedAtServerTimestamp == activatedAtServerTimestamp
		and record.expiresAtServerTimestamp == expiresAtServerTimestamp
	then
		return commit({}, {})
	end
	if
		stored.lastTransitionServerTimestamp ~= nil
		and activatedAtServerTimestamp <= stored.lastTransitionServerTimestamp
	then
		return rejected(STALE_TRANSITION)
	end
	if expiresAtServerTimestamp ~= nil then
		local lifetime = expiresAtServerTimestamp - activatedAtServerTimestamp
		if
			lifetime < GameplayLightingConfig.MinimumTemporaryLightLifetimeSeconds
			or lifetime > GameplayLightingConfig.MaximumTemporaryLightLifetimeSeconds
		then
			return rejected(INVALID_LIFETIME)
		end
	elseif stored.definition.sourceTypeId == APPROVED_TEMPORARY then
		return rejected(INVALID_LIFETIME)
	end
	if
		record.activationStateId ~= ACTIVE
		and activeLightCount() >= GameplayLightingConfig.MaximumActiveGameplayLocalizedLightsPerClientView
	then
		return rejected(BUDGET_EXCEEDED)
	end

	record.activationStateId = ACTIVE
	record.activatedAtServerTimestamp = activatedAtServerTimestamp
	record.expiresAtServerTimestamp = expiresAtServerTimestamp
	stored.lastTransitionServerTimestamp = activatedAtServerTimestamp
	local result = commit({ stored }, {})
	scheduleNextExpiry()
	return result
end

function GameplayLightingService.deactivateLight(lightId: string, serverTimestamp: number): OperationResult
	if not started then
		return rejected(GameplayLightingService.RejectionReasonIds.ServiceStopped)
	end
	local stored = lights[lightId]
	if stored == nil then
		return rejected(GameplayLightingService.RejectionReasonIds.UnknownLight)
	end
	if not isFiniteNonnegativeNumber(serverTimestamp) then
		return rejected(INVALID_TIMESTAMP)
	end
	if stored.record.activationStateId == INACTIVE then
		return commit({}, {})
	end
	if stored.lastTransitionServerTimestamp ~= nil and serverTimestamp <= stored.lastTransitionServerTimestamp then
		return rejected(STALE_TRANSITION)
	end

	stored.record.activationStateId = INACTIVE
	stored.record.activatedAtServerTimestamp = nil
	stored.record.expiresAtServerTimestamp = nil
	stored.lastTransitionServerTimestamp = serverTimestamp
	local result = commit({ stored }, {})
	scheduleNextExpiry()
	return result
end

function GameplayLightingService.removeLight(lightId: string): OperationResult
	if not started then
		return rejected(GameplayLightingService.RejectionReasonIds.ServiceStopped)
	end
	if lights[lightId] == nil then
		return rejected(GameplayLightingService.RejectionReasonIds.UnknownLight)
	end
	lights[lightId] = nil
	local result = commit({}, { lightId })
	scheduleNextExpiry()
	return result
end

function GameplayLightingService.readSnapshot(): GameplayLightingSnapshot?
	return if started then copySnapshot() else nil
end

function GameplayLightingService.subscribe(listener: Listener): ListenerConnection?
	if not started or typeof(listener) ~= "function" then
		return nil
	end
	nextListenerId += 1
	local listenerId = nextListenerId
	listeners[listenerId] = listener
	local connected = true
	local connection = {} :: ListenerConnection
	function connection:Disconnect()
		if not connected then
			return
		end
		connected = false
		listeners[listenerId] = nil
	end
	return connection
end

return table.freeze(GameplayLightingService)
