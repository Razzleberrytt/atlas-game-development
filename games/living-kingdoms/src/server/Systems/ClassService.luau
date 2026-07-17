--!strict

--[[
	P7-0102 server owner for starting-class selection and assignment. The only
	client mutation request contains a request ID and class ID. Operative identity,
	participation, mission phase/deadline, availability, request bounds, assignment,
	lock state, revisions, roster disclosure, and cleanup are derived here.

	This service owns no class action, healing, revive effect, weapon effect,
	ammunition grant, objective repair, or persistent unlock state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local ClassSelectionResolver = require(script.Parent.ClassSelectionResolver)
local MissionDirectorService = require(script.Parent.MissionDirectorService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local NetworkOperationIds = ClassContracts.ClassSelectionNetworkOperationIds
local RejectionReasonIds = ClassContracts.ClassActionRejectionReasonIds
local SelectionStateIds = ClassContracts.ClassSelectionStateIds
local ActionStateIds = ClassContracts.ClassActionStateIds

local classNetwork = ReplicatedStorage:WaitForChild("ClassNetwork")
local selectionIntentRemote = classNetwork:WaitForChild("SelectionIntent") :: RemoteEvent
local stateRemote = classNetwork:WaitForChild("State") :: RemoteEvent
local readStateFunction = classNetwork:WaitForChild("ReadState") :: RemoteFunction

type ClassId = ClassContracts.ClassId
type ClassSelectionStateId = ClassContracts.ClassSelectionStateId
type AuthoritativeClassAssignment = ClassContracts.AuthoritativeClassAssignment
type ListenerConnection = { Disconnect: (self: ListenerConnection) -> () }

type Entry = {
	player: Player,
	operativeEntityId: string,
	assignment: AuthoritativeClassAssignment,
	processedRequestIds: { [string]: boolean },
	processedRequestOrder: { string },
	lastRequestServerTimestamp: number?,
}

export type OperationResult = {
	didChange: boolean,
	rejectionReasonId: string?,
	requestId: string?,
	assignment: AuthoritativeClassAssignment?,
	rosterRevision: number,
}

local Service = {}
Service.RejectionReasonIds = RejectionReasonIds

local entriesByOperativeId: { [string]: Entry } = {}
local entryByPlayer: { [Player]: Entry } = {}
local availableClassIds: { [string]: boolean } = {}
local selectionStateId: ClassSelectionStateId = SelectionStateIds.Locked
local rosterRevision = 0
local started = false
local serviceGeneration = 0
local lockGeneration = 0
local lockThread: thread? = nil
local remoteConnection: RBXScriptConnection? = nil
local rosterConnection: ListenerConnection? = nil

for _, classId in ClassConfig.Selection.startingClassIds do
	availableClassIds[classId] = true
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function copyAssignment(assignment: AuthoritativeClassAssignment): AuthoritativeClassAssignment
	return table.freeze({
		operativeEntityId = assignment.operativeEntityId,
		classId = assignment.classId,
		selectionStateId = assignment.selectionStateId,
		revision = assignment.revision,
	})
end

local function result(
	didChange: boolean,
	rejectionReasonId: string?,
	requestId: string?,
	assignment: AuthoritativeClassAssignment?
): OperationResult
	return table.freeze({
		didChange = didChange,
		rejectionReasonId = rejectionReasonId,
		requestId = requestId,
		assignment = if assignment == nil then nil else copyAssignment(assignment),
		rosterRevision = rosterRevision,
	})
end

local function sortedSquadMembers(): { ClassContracts.ClassSquadMemberPresentationSnapshot }
	local members = {}
	for _, entry in entriesByOperativeId do
		table.insert(
			members,
			table.freeze({
				operativeEntityId = entry.operativeEntityId,
				classId = entry.assignment.classId,
				actionStateId = ActionStateIds.Idle,
				actionId = nil,
			})
		)
	end
	table.sort(members, function(left, right)
		return left.operativeEntityId < right.operativeEntityId
	end)
	return table.freeze(members)
end

local function safeSnapshotForPlayer(player: Player): ClassContracts.SafeClassSelectionSnapshot
	local entry = entryByPlayer[player]
	return table.freeze({
		operationId = NetworkOperationIds.Snapshot,
		rosterRevision = rosterRevision,
		selectionStateId = selectionStateId,
		ownerAssignment = if entry == nil then nil else copyAssignment(entry.assignment),
		squadMembers = sortedSquadMembers(),
	})
end

local function rejectionPayload(reasonId: string, requestId: string?): ClassContracts.SafeClassSelectionRejection
	return table.freeze({
		operationId = NetworkOperationIds.Rejected,
		rosterRevision = rosterRevision,
		rejectionReasonId = reasonId,
		requestId = requestId,
	})
end

local function publishAll()
	for player in entryByPlayer do
		pcall(function()
			stateRemote:FireClient(player, safeSnapshotForPlayer(player))
		end)
	end
end

local function reject(player: Player?, reasonId: string, requestId: string?): OperationResult
	if player ~= nil then
		pcall(function()
			stateRemote:FireClient(player, rejectionPayload(reasonId, requestId))
		end)
	end
	return result(false, reasonId, requestId, nil)
end

local function cancelLockTimer()
	lockGeneration += 1
	if lockThread ~= nil then
		pcall(task.cancel, lockThread)
		lockThread = nil
	end
end

local function lockAllSelections(): boolean
	if selectionStateId == SelectionStateIds.Locked then
		cancelLockTimer()
		return false
	end
	selectionStateId = SelectionStateIds.Locked
	local didChange = false
	for _, entry in entriesByOperativeId do
		if entry.assignment.selectionStateId ~= SelectionStateIds.Locked then
			entry.assignment = table.freeze({
				operativeEntityId = entry.operativeEntityId,
				classId = entry.assignment.classId,
				selectionStateId = SelectionStateIds.Locked,
				revision = entry.assignment.revision + 1,
			})
			didChange = true
		end
	end
	cancelLockTimer()
	if didChange then
		rosterRevision += 1
		publishAll()
	end
	return didChange
end

local function scheduleLock(deadlineServerTimestamp: number)
	cancelLockTimer()
	local generation = lockGeneration
	local serviceAtSchedule = serviceGeneration
	lockThread = task.delay(math.max(0, deadlineServerTimestamp - now()), function()
		if started and serviceAtSchedule == serviceGeneration and generation == lockGeneration then
			lockThread = nil
			lockAllSelections()
		end
	end)
end

local function registerPlayer(player: Player, allowLockedRegistration: boolean): boolean
	if entryByPlayer[player] ~= nil then
		return false
	end
	if selectionStateId == SelectionStateIds.Locked and not allowLockedRegistration then
		return false
	end
	local read = OperativeLifeService.read(player)
	if read == nil then
		return false
	end
	local operativeEntityId = read.snapshot.operativeEntityId
	if entriesByOperativeId[operativeEntityId] ~= nil then
		return false
	end
	local assignment = table.freeze({
		operativeEntityId = operativeEntityId,
		classId = ClassConfig.Selection.defaultClassId,
		selectionStateId = selectionStateId,
		revision = 1,
	})
	local entry: Entry = {
		player = player,
		operativeEntityId = operativeEntityId,
		assignment = assignment,
		processedRequestIds = {},
		processedRequestOrder = {},
		lastRequestServerTimestamp = nil,
	}
	entriesByOperativeId[operativeEntityId] = entry
	entryByPlayer[player] = entry
	rosterRevision += 1
	return true
end

local function removeOperative(operativeEntityId: string): boolean
	local entry = entriesByOperativeId[operativeEntityId]
	if entry == nil then
		return false
	end
	entriesByOperativeId[operativeEntityId] = nil
	entryByPlayer[entry.player] = nil
	rosterRevision += 1
	return true
end

local function recordProcessedRequest(entry: Entry, requestId: string)
	entry.processedRequestIds[requestId] = true
	table.insert(entry.processedRequestOrder, requestId)
	local maximum = ClassConfig.Selection.maximumProcessedRequestIdsPerOperative
	while #entry.processedRequestOrder > maximum do
		local expiredRequestId = table.remove(entry.processedRequestOrder, 1)
		if expiredRequestId ~= nil then
			entry.processedRequestIds[expiredRequestId] = nil
		end
	end
end

local function synchronizeSelectionWindow()
	local mission = MissionDirectorService.read()
	local deadline = mission.insertionDeadlineServerTimestamp
	if
		mission.phaseId == ClassConfig.Selection.openMissionPhaseId
		and deadline ~= nil
		and now() < deadline
		and selectionStateId ~= SelectionStateIds.Locked
	then
		scheduleLock(deadline)
		return
	end
	lockAllSelections()
end

function Service.requestSelection(player: Player, payload: unknown): OperationResult
	local requestId = if type(payload) == "table" and type((payload :: any).requestId) == "string"
		then (payload :: any).requestId
		else nil
	if not started then
		return reject(player, RejectionReasonIds.ServiceStopped, requestId)
	end
	local entry = entryByPlayer[player]
	if entry == nil then
		return reject(player, RejectionReasonIds.NotParticipant, requestId)
	end
	local serverTimestamp = now()
	local mission = MissionDirectorService.read()
	local deadline = mission.insertionDeadlineServerTimestamp
	if
		mission.phaseId ~= ClassConfig.Selection.openMissionPhaseId
		or deadline == nil
		or serverTimestamp >= deadline
	then
		lockAllSelections()
	end
	local previousRequestTimestamp = entry.lastRequestServerTimestamp
	local isRateLimited = previousRequestTimestamp ~= nil
		and serverTimestamp - previousRequestTimestamp < ClassConfig.Selection.minimumRequestIntervalSeconds
	entry.lastRequestServerTimestamp = serverTimestamp
	local isDuplicateRequest = requestId ~= nil and entry.processedRequestIds[requestId] == true
	local resolution = ClassSelectionResolver.resolve(entry.assignment, payload, {
		isParticipant = OperativeLifeService.read(player) ~= nil,
		missionPhaseId = mission.phaseId,
		insertionDeadlineServerTimestamp = deadline,
		serverTimestamp = serverTimestamp,
		availableClassIds = availableClassIds,
		isDuplicateRequest = isDuplicateRequest,
		isRateLimited = isRateLimited,
	})
	if not resolution.didSelect then
		return reject(player, resolution.rejectionReasonId or RejectionReasonIds.InvalidIntent, resolution.requestId)
	end
	entry.assignment = copyAssignment(resolution.assignmentAfter)
	if resolution.requestId ~= nil then
		recordProcessedRequest(entry, resolution.requestId)
	end
	rosterRevision += 1
	publishAll()
	return result(true, nil, resolution.requestId, entry.assignment)
end

function Service.read(player: Player): AuthoritativeClassAssignment?
	local entry = entryByPlayer[player]
	return if entry == nil then nil else copyAssignment(entry.assignment)
end

function Service.readRoster(): { AuthoritativeClassAssignment }
	local roster = {}
	for _, entry in entriesByOperativeId do
		table.insert(roster, copyAssignment(entry.assignment))
	end
	table.sort(roster, function(left, right)
		return left.operativeEntityId < right.operativeEntityId
	end)
	return table.freeze(roster)
end

function Service.readSafeSnapshot(player: Player): ClassContracts.SafeClassSelectionSnapshot
	return safeSnapshotForPlayer(player)
end

function Service.start()
	if started then
		return
	end
	started = true
	serviceGeneration += 1
	rosterRevision = 0
	local mission = MissionDirectorService.read()
	local deadline = mission.insertionDeadlineServerTimestamp
	selectionStateId = if mission.phaseId == ClassConfig.Selection.openMissionPhaseId
			and deadline ~= nil
			and now() < deadline
		then SelectionStateIds.Open
		else SelectionStateIds.Locked
	for _, read in OperativeLifeService.readAll() do
		local player = OperativeLifeService.playerForOperativeEntityId(read.operativeEntityId)
		if player ~= nil then
			registerPlayer(player, true)
		end
	end
	rosterConnection = OperativeLifeService.subscribeRoster(function(eventName, operativeEntityId)
		if not started then
			return
		end
		if eventName == "Registered" then
			local player = OperativeLifeService.playerForOperativeEntityId(operativeEntityId)
			if player ~= nil and registerPlayer(player, false) then
				publishAll()
			end
		elseif removeOperative(operativeEntityId) then
			publishAll()
		end
	end)
	remoteConnection = selectionIntentRemote.OnServerEvent:Connect(function(player: Player, payload: unknown)
		Service.requestSelection(player, payload)
	end)
	readStateFunction.OnServerInvoke = function(player: Player)
		return safeSnapshotForPlayer(player)
	end
	if selectionStateId == SelectionStateIds.Open and deadline ~= nil then
		scheduleLock(deadline)
	end
	publishAll()
end

function Service.stop()
	if not started then
		return
	end
	started = false
	serviceGeneration += 1
	cancelLockTimer()
	if remoteConnection ~= nil then
		remoteConnection:Disconnect()
		remoteConnection = nil
	end
	if rosterConnection ~= nil then
		rosterConnection:Disconnect()
		rosterConnection = nil
	end
	readStateFunction.OnServerInvoke = nil
	table.clear(entriesByOperativeId)
	table.clear(entryByPlayer)
	selectionStateId = SelectionStateIds.Locked
	rosterRevision = 0
end

return Service
