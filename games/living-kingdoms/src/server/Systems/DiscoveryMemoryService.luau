--!strict

--[[
	Server-only owner for recipient-specific discovery and bounded remembered
	information. Trusted server callers supply LK-0403 facts and the matching
	resolver output; this service revalidates that pair before creating records.
	It performs no spatial, lighting, renderer, raycast, targeting, or client
	request work.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PerceptionConfig = require(ReplicatedStorage.Shared.Config.PerceptionConfig)
local PerceptionContracts = require(ReplicatedStorage.Shared.Perception.PerceptionContracts)
local PerceptionContractsValidator = require(ReplicatedStorage.Shared.Perception.PerceptionContractsValidator)
local VisibilityResolver = require(ReplicatedStorage.Shared.Perception.VisibilityResolver)

export type DisclosureRecord = {
	observedEntityId: string,
	observationSourceId: string,
	disclosureStateId: string,
	perceptionStateId: string,
	memoryStateId: string,
	confidenceId: string,
	observedAtServerTimestamp: number,
	expiresAtServerTimestamp: number?,
	revision: number,
}

export type RecipientSnapshot = {
	recipientEntityId: string,
	revision: number,
	records: { DisclosureRecord },
}

export type DisclosureChange = {
	recipientEntityId: string,
	revision: number,
	changedRecords: { DisclosureRecord },
	removedObservedEntityIds: { string },
}

export type OperationResult = {
	didChange: boolean,
	rejectionReasonId: string?,
	revision: number?,
	snapshot: RecipientSnapshot?,
}

type StoredRecord = DisclosureRecord & {
	lastInputServerTimestamp: number,
}

type Listener = (change: DisclosureChange) -> ()

type RecipientEntry = {
	recipientEntityId: string,
	revision: number,
	latestServerTimestamp: number?,
	recordsByObservedEntityId: { [string]: StoredRecord },
	listeners: { [number]: Listener },
	nextListenerId: number,
}

type ListenerConnection = {
	Disconnect: (self: ListenerConnection) -> (),
}

local DiscoveryMemoryService = {}

DiscoveryMemoryService.RejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidRecipient = "InvalidRecipient",
	UnknownRecipient = "UnknownRecipient",
	RecipientMismatch = "RecipientMismatch",
	CandidateMismatch = "CandidateMismatch",
	InvalidVisibilityResolution = "InvalidVisibilityResolution",
})

local SOURCE_DIRECT_SIGHT = PerceptionContracts.ObservationSourceIds.DirectSight
local DISCLOSED = PerceptionContracts.DisclosureStateIds.Disclosed
local OBSERVED = PerceptionContracts.PerceptionStateIds.Observed
local UNKNOWN = PerceptionContracts.PerceptionStateIds.Unknown
local MEMORY_NONE = PerceptionContracts.MemoryStateIds.None
local REMEMBERED = PerceptionContracts.MemoryStateIds.Remembered
local INVALID_TIMESTAMP = PerceptionContracts.PerceptionRejectionReasonIds.InvalidTimestamp
local STALE_OBSERVATION = PerceptionContracts.PerceptionRejectionReasonIds.StaleObservation
local EXPIRY_SCHEDULER_EPSILON_SECONDS = 0.001

local recipients: { [string]: RecipientEntry } = {}
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

local function copyRecord(record: StoredRecord): DisclosureRecord
	return {
		observedEntityId = record.observedEntityId,
		observationSourceId = record.observationSourceId,
		disclosureStateId = record.disclosureStateId,
		perceptionStateId = record.perceptionStateId,
		memoryStateId = record.memoryStateId,
		confidenceId = record.confidenceId,
		observedAtServerTimestamp = record.observedAtServerTimestamp,
		expiresAtServerTimestamp = record.expiresAtServerTimestamp,
		revision = record.revision,
	}
end

local function copySnapshot(entry: RecipientEntry): RecipientSnapshot
	local records = {}
	for _, record in entry.recordsByObservedEntityId do
		if record.disclosureStateId == DISCLOSED and record.perceptionStateId ~= UNKNOWN then
			table.insert(records, copyRecord(record))
		end
	end
	table.sort(records, function(left, right)
		return left.observedEntityId < right.observedEntityId
	end)
	return {
		recipientEntityId = entry.recipientEntityId,
		revision = entry.revision,
		records = records,
	}
end

local function cloneStoredRecords(source: { [string]: StoredRecord }): { [string]: StoredRecord }
	local result = {}
	for observedEntityId, record in source do
		result[observedEntityId] = table.clone(record)
	end
	return result
end

local function recordsHaveSameDisclosure(left: StoredRecord?, right: StoredRecord?): boolean
	if left == nil or right == nil then
		return left == right
	end
	return left.observedEntityId == right.observedEntityId
		and left.observationSourceId == right.observationSourceId
		and left.disclosureStateId == right.disclosureStateId
		and left.perceptionStateId == right.perceptionStateId
		and left.memoryStateId == right.memoryStateId
		and left.confidenceId == right.confidenceId
		and left.observedAtServerTimestamp == right.observedAtServerTimestamp
		and left.expiresAtServerTimestamp == right.expiresAtServerTimestamp
end

local function copyChange(change: DisclosureChange): DisclosureChange
	local changedRecords = {}
	for _, record in change.changedRecords do
		table.insert(changedRecords, table.clone(record))
	end
	return {
		recipientEntityId = change.recipientEntityId,
		revision = change.revision,
		changedRecords = changedRecords,
		removedObservedEntityIds = table.clone(change.removedObservedEntityIds),
	}
end

local function notify(entry: RecipientEntry, change: DisclosureChange)
	for _, listener in entry.listeners do
		pcall(listener, copyChange(change))
	end
end

local function commitVisibleMutation(
	entry: RecipientEntry,
	recordsBefore: { [string]: StoredRecord }
): (boolean, DisclosureChange?)
	local changedEntityIds = {}
	local removedEntityIds = {}
	for observedEntityId, record in entry.recordsByObservedEntityId do
		if not recordsHaveSameDisclosure(recordsBefore[observedEntityId], record) then
			table.insert(changedEntityIds, observedEntityId)
		end
	end
	for observedEntityId in recordsBefore do
		if entry.recordsByObservedEntityId[observedEntityId] == nil then
			table.insert(removedEntityIds, observedEntityId)
		end
	end
	if #changedEntityIds == 0 and #removedEntityIds == 0 then
		return false, nil
	end

	table.sort(changedEntityIds)
	table.sort(removedEntityIds)
	entry.revision += 1
	local changedRecords = {}
	for _, observedEntityId in changedEntityIds do
		local record = entry.recordsByObservedEntityId[observedEntityId]
		record.revision = entry.revision
		table.insert(changedRecords, copyRecord(record))
	end
	local change: DisclosureChange = {
		recipientEntityId = entry.recipientEntityId,
		revision = entry.revision,
		changedRecords = changedRecords,
		removedObservedEntityIds = removedEntityIds,
	}
	notify(entry, change)
	return true, change
end

local function removeExpiredRecords(entry: RecipientEntry, serverTimestamp: number)
	for observedEntityId, record in entry.recordsByObservedEntityId do
		local expiry = record.expiresAtServerTimestamp
		if record.memoryStateId == REMEMBERED and expiry ~= nil and serverTimestamp > expiry then
			entry.recordsByObservedEntityId[observedEntityId] = nil
		end
	end
end

local function enforceRememberedLimit(entry: RecipientEntry)
	local remembered = {}
	for _, record in entry.recordsByObservedEntityId do
		if record.memoryStateId == REMEMBERED then
			table.insert(remembered, record)
		end
	end
	table.sort(remembered, function(left, right)
		if left.observedAtServerTimestamp ~= right.observedAtServerTimestamp then
			return left.observedAtServerTimestamp < right.observedAtServerTimestamp
		end
		return left.observedEntityId < right.observedEntityId
	end)
	local maximum = math.max(0, math.floor(PerceptionConfig.MaximumRememberedObservationsPerOperative))
	for index = 1, #remembered - maximum do
		entry.recordsByObservedEntityId[remembered[index].observedEntityId] = nil
	end
end

local function cancelScheduledExpiry()
	timerGeneration += 1
	if scheduledThread ~= nil then
		task.cancel(scheduledThread)
		scheduledThread = nil
	end
end

local function nextExpiry(): (number?, string?, string?, number?)
	local earliestExpiry = nil
	local earliestRecipientId = nil
	local earliestObservedEntityId = nil
	local earliestRecordRevision = nil
	for recipientId, entry in recipients do
		for observedEntityId, record in entry.recordsByObservedEntityId do
			local expiry = record.expiresAtServerTimestamp
			if
				record.memoryStateId == REMEMBERED
				and expiry ~= nil
				and (
					earliestExpiry == nil
					or expiry < earliestExpiry
					or (expiry == earliestExpiry and recipientId < (earliestRecipientId :: string))
					or (
						expiry == earliestExpiry
						and recipientId == earliestRecipientId
						and observedEntityId < (earliestObservedEntityId :: string)
					)
				)
			then
				earliestExpiry = expiry
				earliestRecipientId = recipientId
				earliestObservedEntityId = observedEntityId
				earliestRecordRevision = record.revision
			end
		end
	end
	return earliestExpiry, earliestRecipientId, earliestObservedEntityId, earliestRecordRevision
end

function DiscoveryMemoryService.evaluateExpiriesAt(serverTimestamp: number): OperationResult
	if not started then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.ServiceStopped)
	end
	if not isFiniteNonnegativeNumber(serverTimestamp) then
		return rejected(INVALID_TIMESTAMP)
	end

	local anyChange = false
	local highestRevision = nil
	local recipientIds = {}
	for recipientId in recipients do
		table.insert(recipientIds, recipientId)
	end
	table.sort(recipientIds)
	for _, recipientId in recipientIds do
		local entry = recipients[recipientId]
		local before = cloneStoredRecords(entry.recordsByObservedEntityId)
		removeExpiredRecords(entry, serverTimestamp)
		local didChange = commitVisibleMutation(entry, before)
		if didChange then
			anyChange = true
			highestRevision = entry.revision
		end
	end
	scheduleNextExpiry()
	return {
		didChange = anyChange,
		rejectionReasonId = nil,
		revision = highestRevision,
		snapshot = nil,
	}
end

scheduleNextExpiry = function()
	cancelScheduledExpiry()
	if not started then
		return
	end
	local expiry, recipientId, observedEntityId, recordRevision = nextExpiry()
	if expiry == nil or recipientId == nil or observedEntityId == nil or recordRevision == nil then
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
			local entry = recipients[recipientId]
			local record = if entry == nil then nil else entry.recordsByObservedEntityId[observedEntityId]
			if
				record == nil
				or record.revision ~= recordRevision
				or record.expiresAtServerTimestamp ~= expectedExpiry
			then
				return
			end
			DiscoveryMemoryService.evaluateExpiriesAt(Workspace:GetServerTimeNow())
		end
	)
end

local function sameResolution(left: any, right: any): boolean
	return left.isValid == right.isValid
		and left.isGameplayVisible == right.isGameplayVisible
		and left.perceptionStateId == right.perceptionStateId
		and left.confidenceId == right.confidenceId
		and left.canCreateDirectSightObservation == right.canCreateDirectSightObservation
		and left.isTargetingVisible == right.isTargetingVisible
		and left.rejectionReasonId == right.rejectionReasonId
		and left.decisionReasonId == right.decisionReasonId
end

local function currentRecord(observedEntityId: string, confidenceId: string, serverTimestamp: number): StoredRecord
	return {
		observedEntityId = observedEntityId,
		observationSourceId = SOURCE_DIRECT_SIGHT,
		disclosureStateId = DISCLOSED,
		perceptionStateId = OBSERVED,
		memoryStateId = MEMORY_NONE,
		confidenceId = confidenceId,
		observedAtServerTimestamp = serverTimestamp,
		expiresAtServerTimestamp = nil,
		revision = 0,
		lastInputServerTimestamp = serverTimestamp,
	}
end

function DiscoveryMemoryService.start()
	if started then
		return
	end
	started = true
	scheduleNextExpiry()
end

function DiscoveryMemoryService.stop()
	if not started then
		return
	end
	started = false
	cancelScheduledExpiry()
	table.clear(recipients)
end

function DiscoveryMemoryService.registerRecipient(recipientEntityId: string): OperationResult
	if not started then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.ServiceStopped)
	end
	if not isNonemptyString(recipientEntityId) then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.InvalidRecipient)
	end
	local existing = recipients[recipientEntityId]
	if existing ~= nil then
		return {
			didChange = false,
			rejectionReasonId = nil,
			revision = existing.revision,
			snapshot = copySnapshot(existing),
		}
	end
	local entry: RecipientEntry = {
		recipientEntityId = recipientEntityId,
		revision = 0,
		latestServerTimestamp = nil,
		recordsByObservedEntityId = {},
		listeners = {},
		nextListenerId = 0,
	}
	recipients[recipientEntityId] = entry
	return {
		didChange = true,
		rejectionReasonId = nil,
		revision = 0,
		snapshot = copySnapshot(entry),
	}
end

function DiscoveryMemoryService.unregisterRecipient(recipientEntityId: string): boolean
	if not started or not isNonemptyString(recipientEntityId) or recipients[recipientEntityId] == nil then
		return false
	end
	recipients[recipientEntityId] = nil
	scheduleNextExpiry()
	return true
end

function DiscoveryMemoryService.readRecipientSnapshot(recipientEntityId: string): RecipientSnapshot?
	if not started or not isNonemptyString(recipientEntityId) then
		return nil
	end
	local entry = recipients[recipientEntityId]
	return if entry == nil then nil else copySnapshot(entry)
end

function DiscoveryMemoryService.subscribeRecipient(recipientEntityId: string, listener: Listener): ListenerConnection?
	if not started or typeof(listener) ~= "function" then
		return nil
	end
	local entry = recipients[recipientEntityId]
	if entry == nil then
		return nil
	end
	entry.nextListenerId += 1
	local listenerId = entry.nextListenerId
	entry.listeners[listenerId] = listener
	local connected = true
	local connection = {} :: ListenerConnection
	function connection:Disconnect()
		if not connected then
			return
		end
		connected = false
		local current = recipients[recipientEntityId]
		if current ~= nil then
			current.listeners[listenerId] = nil
		end
	end
	return connection
end

function DiscoveryMemoryService.applyVisibilityResolution(
	recipientEntityId: string,
	observedEntityId: string,
	candidateFacts: unknown,
	visibilityResolution: unknown,
	serverTimestamp: number
): OperationResult
	if not started then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.ServiceStopped)
	end
	local entry = recipients[recipientEntityId]
	if entry == nil then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.UnknownRecipient)
	end
	if not isFiniteNonnegativeNumber(serverTimestamp) then
		return rejected(INVALID_TIMESTAMP)
	end
	if entry.latestServerTimestamp ~= nil and serverTimestamp < entry.latestServerTimestamp then
		return rejected(STALE_OBSERVATION)
	end
	if typeof(candidateFacts) ~= "table" then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.InvalidVisibilityResolution)
	end
	local facts = candidateFacts :: any
	if facts.observerEntityId ~= recipientEntityId then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.RecipientMismatch)
	end
	if not isNonemptyString(observedEntityId) or facts.candidateEntityId ~= observedEntityId then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.CandidateMismatch)
	end
	if typeof(visibilityResolution) ~= "table" then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.InvalidVisibilityResolution)
	end
	local canonicalResolution = VisibilityResolver.resolve(candidateFacts)
	if canonicalResolution.isValid ~= true then
		return rejected(canonicalResolution.rejectionReasonId)
	end
	local resolution = visibilityResolution :: any
	if resolution.isValid ~= true or not sameResolution(resolution, canonicalResolution) then
		return rejected(DiscoveryMemoryService.RejectionReasonIds.InvalidVisibilityResolution)
	end

	local existing = entry.recordsByObservedEntityId[observedEntityId]
	local createsCurrent = resolution.canCreateDirectSightObservation == true
		and resolution.isGameplayVisible == true
		and resolution.perceptionStateId == OBSERVED
	if existing ~= nil and serverTimestamp == existing.lastInputServerTimestamp then
		if
			createsCurrent
			and existing.memoryStateId == MEMORY_NONE
			and existing.confidenceId == resolution.confidenceId
			and existing.observedAtServerTimestamp == serverTimestamp
		then
			return {
				didChange = false,
				rejectionReasonId = nil,
				revision = entry.revision,
				snapshot = copySnapshot(entry),
			}
		end
		return rejected(STALE_OBSERVATION)
	end
	if existing ~= nil and serverTimestamp < existing.lastInputServerTimestamp then
		return rejected(STALE_OBSERVATION)
	end

	local before = cloneStoredRecords(entry.recordsByObservedEntityId)
	if createsCurrent then
		local replacement = currentRecord(observedEntityId, resolution.confidenceId, serverTimestamp)
		local validation = PerceptionContractsValidator.validate(replacement, serverTimestamp)
		if not validation.isValid then
			return rejected(validation.rejectionReasonId)
		end
		entry.recordsByObservedEntityId[observedEntityId] = replacement
	elseif existing ~= nil and existing.memoryStateId == MEMORY_NONE then
		local expiry = existing.observedAtServerTimestamp + PerceptionConfig.MaximumObservationAgeSeconds
		if serverTimestamp > expiry then
			entry.recordsByObservedEntityId[observedEntityId] = nil
		else
			existing.memoryStateId = REMEMBERED
			existing.expiresAtServerTimestamp = expiry
			existing.lastInputServerTimestamp = serverTimestamp
			local validation = PerceptionContractsValidator.validate(existing, serverTimestamp)
			if not validation.isValid then
				entry.recordsByObservedEntityId = before
				return rejected(validation.rejectionReasonId)
			end
		end
	elseif existing ~= nil then
		-- This metadata prevents same-entity, same-timestamp conflicting replay.
		-- It does not alter or refresh the disclosed observation or its expiry.
		existing.lastInputServerTimestamp = serverTimestamp
	end

	entry.latestServerTimestamp = serverTimestamp
	removeExpiredRecords(entry, serverTimestamp)
	enforceRememberedLimit(entry)
	local didChange = commitVisibleMutation(entry, before)
	scheduleNextExpiry()
	return {
		didChange = didChange,
		rejectionReasonId = nil,
		revision = entry.revision,
		snapshot = copySnapshot(entry),
	}
end

function DiscoveryMemoryService.removeObservedEntity(observedEntityId: string): boolean
	if not started or not isNonemptyString(observedEntityId) then
		return false
	end
	local removed = false
	local recipientIds = {}
	for recipientId in recipients do
		table.insert(recipientIds, recipientId)
	end
	table.sort(recipientIds)
	for _, recipientId in recipientIds do
		local entry = recipients[recipientId]
		if entry.recordsByObservedEntityId[observedEntityId] ~= nil then
			local before = cloneStoredRecords(entry.recordsByObservedEntityId)
			entry.recordsByObservedEntityId[observedEntityId] = nil
			commitVisibleMutation(entry, before)
			removed = true
		end
	end
	if removed then
		scheduleNextExpiry()
	end
	return removed
end

return table.freeze(DiscoveryMemoryService)
