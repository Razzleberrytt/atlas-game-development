--!strict

-- Run-scoped orchestration metadata. ExpeditionRuntime remains phase/outcome
-- authority; EnemyDirector remains combat authority. This module only tracks the
-- cross-system facts needed for lifecycle, cleanup, rewards, and telemetry.

export type LifecycleState =
	"Creating" | "WaitingForPlayers" | "Active" | "Encounter" | "Boss" | "Completed" | "Failed" | "CleaningUp"

local MAX_ARCHIVED_RESULTS = 32
local Service = {}
local activeByRunId: { [string]: any } = {}
local archivedByRunId: { [string]: any } = {}
local archiveOrder: { string } = {}
local lastResult: any = nil

local function validInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0
end

local function sortedNumbers(set: { [number]: boolean }): { number }
	local values = {}
	for value, included in set do
		if included then
			table.insert(values, value)
		end
	end
	table.sort(values)
	return table.freeze(values)
end

local function sortedStrings(set: { [string]: boolean }): { string }
	local values = {}
	for value, included in set do
		if included then
			table.insert(values, value)
		end
	end
	table.sort(values)
	return table.freeze(values)
end

local function normalizeRooms(roomPlan: any): ({ any }, number)
	local rooms = {}
	local progressCount = 0
	if type(roomPlan) ~= "table" or type(roomPlan.Nodes) ~= "table" then
		return table.freeze(rooms), 0
	end
	for _, node in roomPlan.Nodes do
		if type(node) == "table" and type(node.RoomId) == "string" and node.RoomId ~= "" then
			local roleId = if type(node.Role) == "string" then node.Role else node.RoleId
			table.insert(rooms, table.freeze({
				Index = if validInteger(node.Index) then node.Index else #rooms + 1,
				RoomId = node.RoomId,
				RoleId = roleId,
			}))
			if roleId ~= "Entry" and roleId ~= "Elite" and roleId ~= "Boss" then
				progressCount += 1
			end
		end
	end
	table.sort(rooms, function(left, right)
		return left.Index < right.Index
	end)
	return table.freeze(rooms), progressCount
end

local function snapshot(record: any): any
	local connected = sortedNumbers(record.ConnectedParticipantUserIds)
	return table.freeze({
		Revision = record.Revision,
		RunId = record.RunId,
		Seed = record.Seed,
		PartySize = record.PartySize,
		StartedAtUnix = record.StartedAtUnix,
		FinishedAtUnix = record.FinishedAtUnix,
		LifecycleState = record.LifecycleState,
		PhaseId = record.PhaseId,
		OutcomeId = record.OutcomeId,
		CurrentRoomId = record.CurrentRoomId,
		CurrentRoomRoleId = record.CurrentRoomRoleId,
		ActiveEncounterKey = record.ActiveEncounterKey,
		RoomsCompleted = record.RoomsCompleted,
		RoomsEncountered = record.RoomsEncountered,
		TotalRooms = record.TotalRooms,
		EncountersCompleted = record.EncountersCompleted,
		ParticipantUserIds = sortedNumbers(record.ParticipantUserIds),
		ConnectedParticipantUserIds = connected,
		ConnectedParticipantCount = #connected,
		RewardOutcomeIds = sortedStrings(record.RewardOutcomeIds),
		FailureReason = record.FailureReason,
		RoomOrder = record.RoomOrder,
	})
end

local function reply(accepted: boolean, reasonId: string, recordOrSummary: any?, extra: any?): any
	local value: any = { Accepted = accepted, ReasonId = reasonId, Snapshot = recordOrSummary }
	if type(extra) == "table" then
		for key, item in extra do
			value[key] = item
		end
	end
	return table.freeze(value)
end

local function buildResult(record: any): any
	local finishedAt = record.FinishedAtUnix or record.StartedAtUnix
	return table.freeze({
		RunId = record.RunId,
		Seed = record.Seed,
		DurationSeconds = math.max(0, finishedAt - record.StartedAtUnix),
		RoomsCompleted = record.RoomsCompleted,
		RoomsEncountered = record.RoomsEncountered,
		TotalRooms = record.TotalRooms,
		EncountersCompleted = record.EncountersCompleted,
		ParticipantUserIds = sortedNumbers(record.ParticipantUserIds),
		Success = record.OutcomeId == "Completed",
		OutcomeId = record.OutcomeId,
		RewardOutcomeIds = sortedStrings(record.RewardOutcomeIds),
		FailureReason = record.FailureReason,
	})
end

function Service.create(parameters: any): any
	if type(parameters) ~= "table" or type(parameters.RunId) ~= "string" or #parameters.RunId < 8 or #parameters.RunId > 96 then
		return reply(false, "InvalidRunId", nil)
	end
	if not validInteger(parameters.Seed) or not validInteger(parameters.PartySize) or parameters.PartySize < 1 then
		return reply(false, "InvalidRunParameters", nil)
	end
	if type(parameters.StartedAtUnix) ~= "number" or parameters.StartedAtUnix < 0 then
		return reply(false, "InvalidStartTimestamp", nil)
	end
	if activeByRunId[parameters.RunId] ~= nil then
		return reply(false, "RunAlreadyTracked", snapshot(activeByRunId[parameters.RunId]))
	end
	local roomOrder, totalRooms = normalizeRooms(parameters.RoomPlan)
	local record = {
		Revision = 1,
		RunId = parameters.RunId,
		Seed = parameters.Seed,
		PartySize = parameters.PartySize,
		StartedAtUnix = parameters.StartedAtUnix,
		FinishedAtUnix = nil,
		LifecycleState = "Creating" :: LifecycleState,
		PhaseId = nil,
		OutcomeId = "InProgress",
		CurrentRoomId = nil,
		CurrentRoomRoleId = nil,
		ActiveEncounterKey = nil,
		RoomsCompleted = 0,
		RoomsEncountered = 0,
		TotalRooms = totalRooms,
		EncountersCompleted = 0,
		ParticipantUserIds = {},
		ConnectedParticipantUserIds = {},
		RewardOutcomeIds = {},
		FailureReason = nil,
		RoomOrder = roomOrder,
	}
	activeByRunId[parameters.RunId] = record
	return reply(true, "RunTracked", snapshot(record))
end

function Service.bindParticipants(runId: string, participantUserIds: { number }): any
	local record = activeByRunId[runId]
	if record == nil then
		return reply(false, "RunNotTracked", nil)
	end
	local normalized: { [number]: boolean } = {}
	for _, userId in participantUserIds do
		if not validInteger(userId) or userId <= 0 then
			return reply(false, "InvalidParticipantUserId", snapshot(record))
		end
		normalized[userId] = true
	end
	local ids = sortedNumbers(normalized)
	if #ids ~= record.PartySize then
		return reply(false, "ParticipantCountMismatch", snapshot(record))
	end
	if next(record.ParticipantUserIds) ~= nil then
		local existing = sortedNumbers(record.ParticipantUserIds)
		for index, userId in ids do
			if existing[index] ~= userId then
				return reply(false, "ParticipantRosterConflict", snapshot(record))
			end
		end
		return reply(true, "ParticipantsAlreadyBound", snapshot(record))
	end
	for _, userId in ids do
		record.ParticipantUserIds[userId] = true
		record.ConnectedParticipantUserIds[userId] = true
	end
	record.LifecycleState = "WaitingForPlayers"
	record.Revision += 1
	return reply(true, "ParticipantsBound", snapshot(record))
end

function Service.sync(runId: string, observation: any): any
	local record = activeByRunId[runId]
	if record == nil then
		return reply(false, "RunNotTracked", nil)
	end
	if type(observation) ~= "table" or type(observation.Snapshot) ~= "table" or observation.Snapshot.RunId ~= runId then
		return reply(false, "InvalidObservation", snapshot(record))
	end
	if type(observation.ObservedAtUnix) ~= "number" or observation.ObservedAtUnix < record.StartedAtUnix then
		return reply(false, "InvalidObservationTimestamp", snapshot(record))
	end
	local nextEncounterKey = if type(observation.EncounterKey) == "string" and observation.EncounterKey ~= "" then observation.EncounterKey else nil
	if record.ActiveEncounterKey ~= nil and nextEncounterKey ~= record.ActiveEncounterKey then
		record.EncountersCompleted += 1
	end
	local runtimeSnapshot = observation.Snapshot
	record.PhaseId = runtimeSnapshot.PhaseId
	record.OutcomeId = runtimeSnapshot.OutcomeId
	record.CurrentRoomId = observation.CurrentRoomId
	record.CurrentRoomRoleId = observation.CurrentRoomRoleId
	record.ActiveEncounterKey = nextEncounterKey
	if validInteger(observation.CompletedRoomCount) then record.RoomsCompleted = math.max(record.RoomsCompleted, observation.CompletedRoomCount) end
	if validInteger(observation.EncounteredRoomCount) then record.RoomsEncountered = math.max(record.RoomsEncountered, observation.EncounteredRoomCount) end
	if validInteger(observation.TotalRoomCount) then record.TotalRooms = math.max(record.TotalRooms, observation.TotalRoomCount) end
	if runtimeSnapshot.OutcomeId == "Completed" then
		record.LifecycleState = "Completed"
		record.FinishedAtUnix = record.FinishedAtUnix or observation.ObservedAtUnix
	elseif runtimeSnapshot.OutcomeId == "Failed" or runtimeSnapshot.OutcomeId == "Abandoned" then
		record.LifecycleState = "Failed"
		record.FinishedAtUnix = record.FinishedAtUnix or observation.ObservedAtUnix
	elseif runtimeSnapshot.PhaseId == "Boss" then
		record.LifecycleState = "Boss"
	elseif observation.EncounterActive == true then
		record.LifecycleState = "Encounter"
	else
		record.LifecycleState = "Active"
	end
	record.Revision += 1
	return reply(true, "RunSynchronized", snapshot(record))
end

function Service.setParticipantConnected(runId: string, userId: number, connected: boolean): any
	local record = activeByRunId[runId]
	if record == nil then
		return reply(false, "RunNotTracked", nil, { AllParticipantsDisconnected = false })
	end
	if record.ParticipantUserIds[userId] ~= true then
		return reply(false, "PlayerNotParticipant", snapshot(record), { AllParticipantsDisconnected = false })
	end
	if connected then record.ConnectedParticipantUserIds[userId] = true else record.ConnectedParticipantUserIds[userId] = nil end
	record.Revision += 1
	return reply(true, if connected then "ParticipantConnected" else "ParticipantDisconnected", snapshot(record), {
		AllParticipantsDisconnected = next(record.ConnectedParticipantUserIds) == nil,
	})
end

function Service.recordRewardOutcome(runId: string, outcomeId: string): any
	local record = activeByRunId[runId]
	if record == nil then return reply(false, "RunNotTracked", nil) end
	if type(outcomeId) ~= "string" or outcomeId == "" then return reply(false, "InvalidRewardOutcome", snapshot(record)) end
	if record.RewardOutcomeIds[outcomeId] then return reply(true, "RewardOutcomeAlreadyRecorded", snapshot(record)) end
	record.RewardOutcomeIds[outcomeId] = true
	record.Revision += 1
	return reply(true, "RewardOutcomeRecorded", snapshot(record))
end

function Service.fail(runId: string, reasonId: string, nowUnix: number, outcomeId: string?): any
	local record = activeByRunId[runId]
	if record == nil then return reply(false, "RunNotTracked", nil) end
	if record.LifecycleState == "Completed" or record.LifecycleState == "Failed" or record.LifecycleState == "CleaningUp" then
		return reply(false, "RunTerminal", snapshot(record))
	end
	if type(reasonId) ~= "string" or reasonId == "" or type(nowUnix) ~= "number" or nowUnix < record.StartedAtUnix then
		return reply(false, "InvalidFailure", snapshot(record))
	end
	record.LifecycleState = "Failed"
	record.OutcomeId = if outcomeId == "Abandoned" then "Abandoned" else "Failed"
	record.FailureReason = reasonId
	record.FinishedAtUnix = nowUnix
	record.ActiveEncounterKey = nil
	record.Revision += 1
	return reply(true, "RunFailed", snapshot(record))
end

function Service.completeCleanup(runId: string, nowUnix: number): any
	local record = activeByRunId[runId]
	if record == nil then
		local archived = archivedByRunId[runId]
		return reply(archived ~= nil, if archived ~= nil then "CleanupAlreadyCompleted" else "RunNotTracked", archived)
	end
	if record.LifecycleState ~= "Completed" and record.LifecycleState ~= "Failed" then
		Service.fail(runId, "RunStoppedBeforeCompletion", nowUnix, "Abandoned")
	end
	record.LifecycleState = "CleaningUp"
	record.FinishedAtUnix = record.FinishedAtUnix or nowUnix
	record.ActiveEncounterKey = nil
	local summary = buildResult(record)
	activeByRunId[runId] = nil
	archivedByRunId[runId] = summary
	table.insert(archiveOrder, runId)
	while #archiveOrder > MAX_ARCHIVED_RESULTS do
		archivedByRunId[table.remove(archiveOrder, 1)] = nil
	end
	lastResult = summary
	return reply(true, "CleanupCompleted", summary)
end

function Service.read(runId: string): any?
	local record = activeByRunId[runId]
	return if record ~= nil then snapshot(record) else nil
end

function Service.readResult(runId: string): any?
	return archivedByRunId[runId]
end

function Service.readLastResult(): any?
	return lastResult
end

function Service.readActiveRunIds(): { string }
	local ids = {}
	for runId in activeByRunId do table.insert(ids, runId) end
	table.sort(ids)
	return table.freeze(ids)
end

function Service.resetForTests()
	table.clear(activeByRunId)
	table.clear(archivedByRunId)
	table.clear(archiveOrder)
	lastResult = nil
end

return table.freeze(Service)
