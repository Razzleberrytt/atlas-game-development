--!strict

--[[
	Same-server owner for one operation's participation facts and squad-failure
	state. Operative snapshots are always copied from OperativeLifeService. The
	operation roster freezes when beginOperation is called; later registrations
	are ignored for viability, so late joining cannot manufacture recovery.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OperativeLifeService = require(script.Parent.OperativeLifeService)
local SquadFailureEvaluator = require(script.Parent.SquadFailureEvaluator)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)

type SquadFailureState = OperativeLifeContracts.SquadFailureState
type SquadFailureFacts = OperativeLifeContracts.SquadFailureFacts

export type AuthoritativeRead = {
	revision: number,
	state: SquadFailureState,
}

export type EvaluationResult = {
	didCommit: boolean,
	rejectionReason: string?,
	revision: number,
	state: SquadFailureState,
}

type StatusListener = (state: SquadFailureState, revision: number) -> ()
type ListenerConnection = { Disconnect: (self: ListenerConnection) -> () }

type SquadFailureService = {
	start: () -> (),
	stop: () -> (),
	beginOperation: () -> EvaluationResult,
	markAuthoritativelyAbandoned: () -> EvaluationResult,
	evaluate: (expectedRevision: number) -> EvaluationResult,
	read: () -> AuthoritativeRead,
	readParticipationFacts: (
	) -> {
		operationStarted: boolean,
		operationStartedSolo: boolean,
		hasEverHadMultipleParticipants: boolean,
		lateJoiningProhibited: boolean,
		isAuthoritativelyAbandoned: boolean,
	},
	isOperativeAdmitted: (operativeEntityId: string) -> boolean,
	subscribe: (listener: StatusListener) -> ListenerConnection,
}

local statusIds = OperativeLifeContracts.SquadFailureStatusIds
local Service: SquadFailureService = {} :: SquadFailureService

local state: SquadFailureState = {
	statusId = statusIds.Viable,
	pendingStartedAtServerTimestamp = nil,
	pendingDeadlineServerTimestamp = nil,
	failedAtServerTimestamp = nil,
}
local revision = 0
local operationStarted = false
local operationStartedSolo = false
local hasEverHadMultipleParticipants = false
local lateJoiningProhibited = false
local isAuthoritativelyAbandoned = false
-- P10-0106: every operative admitted at insertion, for the whole operation. A
-- reconnecting operative resumes admission from this set; an identity that was
-- never admitted still cannot join mid-operation.
local everAdmittedOperativeIds: { [string]: boolean } = {}
local admittedOperativeIds: { [string]: boolean } = {}
local prestartOperativeIds: { [string]: boolean } = {}
local listeners: { [number]: StatusListener } = {}
local nextListenerId = 0
local lifeConnection: any = nil
local rosterConnection: any = nil
local timerGeneration = 0
local started = false

local function copyState(source: SquadFailureState): SquadFailureState
	return {
		statusId = source.statusId,
		pendingStartedAtServerTimestamp = source.pendingStartedAtServerTimestamp,
		pendingDeadlineServerTimestamp = source.pendingDeadlineServerTimestamp,
		failedAtServerTimestamp = source.failedAtServerTimestamp,
	}
end

local function statesEqual(left: SquadFailureState, right: SquadFailureState): boolean
	return left.statusId == right.statusId
		and left.pendingStartedAtServerTimestamp == right.pendingStartedAtServerTimestamp
		and left.pendingDeadlineServerTimestamp == right.pendingDeadlineServerTimestamp
		and left.failedAtServerTimestamp == right.failedAtServerTimestamp
end

local function notifyStatusChange()
	for _, listener in listeners do
		listener(copyState(state), revision)
	end
end

local function result(didCommit: boolean, rejectionReason: string?): EvaluationResult
	return {
		didCommit = didCommit,
		rejectionReason = rejectionReason,
		revision = revision,
		state = copyState(state),
	}
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function buildFacts(): SquadFailureFacts
	local snapshots = {}
	for _, read in OperativeLifeService.readAll() do
		if admittedOperativeIds[read.operativeEntityId] then
			table.insert(snapshots, read.snapshot)
		end
	end
	return {
		operativeSnapshots = snapshots,
		operationStartedSolo = operationStartedSolo,
		hasEverHadMultipleParticipants = hasEverHadMultipleParticipants,
		lateJoiningProhibited = lateJoiningProhibited,
		isAuthoritativelyAbandoned = isAuthoritativelyAbandoned,
	}
end

local evaluateAt: (serverTimestamp: number) -> EvaluationResult

local function scheduleDeadline()
	timerGeneration += 1
	local generation = timerGeneration
	local deadline = state.pendingDeadlineServerTimestamp
	if deadline == nil or state.statusId ~= statusIds.Pending then
		return
	end
	task.delay(math.max(0, deadline - now()), function()
		if not started or generation ~= timerGeneration or state.statusId ~= statusIds.Pending then
			return
		end
		evaluateAt(now())
	end)
end

evaluateAt = function(serverTimestamp: number): EvaluationResult
	if not operationStarted then
		return result(false, nil)
	end
	local beforeStatus = state.statusId
	local evaluated = SquadFailureEvaluator.resolve(copyState(state), buildFacts(), serverTimestamp)
	if not evaluated.didResolve then
		return result(false, evaluated.rejectionReasonId)
	end
	if statesEqual(state, evaluated.stateAfter) then
		if state.statusId == statusIds.Pending then
			scheduleDeadline()
		end
		return result(false, nil)
	end
	state = copyState(evaluated.stateAfter)
	revision += 1
	scheduleDeadline()
	if state.statusId ~= beforeStatus then
		notifyStatusChange()
	end
	return result(true, nil)
end

local function countIds(values: { [string]: boolean }): number
	local count = 0
	for _ in values do
		count += 1
	end
	return count
end

local function beginOperationAt(serverTimestamp: number): EvaluationResult
	if operationStarted then
		return result(false, nil)
	end
	operationStarted = true
	lateJoiningProhibited = true
	table.clear(admittedOperativeIds)
	for operativeEntityId in prestartOperativeIds do
		admittedOperativeIds[operativeEntityId] = true
		everAdmittedOperativeIds[operativeEntityId] = true
	end
	local participantCount = countIds(admittedOperativeIds)
	operationStartedSolo = participantCount == 1
	hasEverHadMultipleParticipants = participantCount > 1
	for operativeEntityId in admittedOperativeIds do
		OperativeLifeService.configureSoloOperationEligibility(operativeEntityId, operationStartedSolo)
	end
	if participantCount == 0 then
		isAuthoritativelyAbandoned = true
	end
	return evaluateAt(serverTimestamp)
end

function Service.start()
	if started then
		return
	end
	started = true
	for _, read in OperativeLifeService.readAll() do
		prestartOperativeIds[read.operativeEntityId] = true
	end
	lifeConnection = OperativeLifeService.subscribe(function()
		evaluateAt(now())
	end)
	rosterConnection = OperativeLifeService.subscribeRoster(function(eventName, operativeEntityId)
		if eventName == "Registered" then
			if not operationStarted then
				prestartOperativeIds[operativeEntityId] = true
			elseif everAdmittedOperativeIds[operativeEntityId] then
				-- A reconnecting operative resumes the admission they already held.
				-- Re-admitting an existing identity duplicates nothing: life,
				-- class, ammunition, and contribution are all keyed by the same ID.
				admittedOperativeIds[operativeEntityId] = true
			end
			-- An identity that was never admitted still cannot join mid-operation.
			evaluateAt(now())
			return
		end
		if not operationStarted then
			beginOperationAt(now())
		end
		prestartOperativeIds[operativeEntityId] = nil
		admittedOperativeIds[operativeEntityId] = nil
		if countIds(admittedOperativeIds) == 0 then
			isAuthoritativelyAbandoned = true
		end
		evaluateAt(now())
	end)
end

function Service.beginOperation(): EvaluationResult
	return beginOperationAt(now())
end

function Service.markAuthoritativelyAbandoned(): EvaluationResult
	if not operationStarted then
		beginOperationAt(now())
	end
	isAuthoritativelyAbandoned = true
	return evaluateAt(now())
end

function Service.evaluate(expectedRevision: number): EvaluationResult
	if
		type(expectedRevision) ~= "number"
		or expectedRevision % 1 ~= 0
		or expectedRevision < 0
		or expectedRevision ~= revision
	then
		return result(false, "StaleRevision")
	end
	return evaluateAt(now())
end

function Service.read(): AuthoritativeRead
	return { revision = revision, state = copyState(state) }
end

function Service.readParticipationFacts()
	return {
		operationStarted = operationStarted,
		operationStartedSolo = operationStartedSolo,
		hasEverHadMultipleParticipants = hasEverHadMultipleParticipants,
		lateJoiningProhibited = lateJoiningProhibited,
		isAuthoritativelyAbandoned = isAuthoritativelyAbandoned,
	}
end

function Service.isOperativeAdmitted(operativeEntityId: string): boolean
	return operationStarted
		and type(operativeEntityId) == "string"
		and operativeEntityId ~= ""
		and admittedOperativeIds[operativeEntityId] == true
end

function Service.subscribe(listener: StatusListener): ListenerConnection
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

function Service.stop()
	if not started then
		return
	end
	started = false
	if lifeConnection ~= nil then
		lifeConnection:Disconnect()
		lifeConnection = nil
	end
	if rosterConnection ~= nil then
		rosterConnection:Disconnect()
		rosterConnection = nil
	end
	timerGeneration += 1
	table.clear(listeners)
	table.clear(admittedOperativeIds)
	table.clear(prestartOperativeIds)
	state = {
		statusId = statusIds.Viable,
		pendingStartedAtServerTimestamp = nil,
		pendingDeadlineServerTimestamp = nil,
		failedAtServerTimestamp = nil,
	}
	revision = 0
	operationStarted = false
	operationStartedSolo = false
	hasEverHadMultipleParticipants = false
	lateJoiningProhibited = false
	isAuthoritativelyAbandoned = false
	table.clear(everAdmittedOperativeIds)
end

return Service
