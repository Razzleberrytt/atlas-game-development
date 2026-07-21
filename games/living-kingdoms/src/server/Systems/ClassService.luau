--!strict

--[[
	Server owner for starting-class selection and the bounded P7-0103 Brace
	lifecycle. Clients request only a declared action and phase; assignment,
	participation, mission/life state, movement, replay, timing, interruption,
	cooldown, and the combat modifier are all derived here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local MissionContracts = require(ReplicatedStorage.Shared.Mission.MissionContracts)
local BraceResolver = require(script.Parent.BraceResolver)
local ClassSelectionResolver = require(script.Parent.ClassSelectionResolver)
local MissionDirectorService = require(script.Parent.MissionDirectorService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local NetworkOperationIds = ClassContracts.ClassSelectionNetworkOperationIds
local RejectionReasonIds = ClassContracts.ClassActionRejectionReasonIds
local SelectionStateIds = ClassContracts.ClassSelectionStateIds
local ActionStateIds = ClassContracts.ClassActionStateIds
local ActionIds = ClassContracts.ClassActionIds
local ActionPhaseIds = ClassContracts.ClassActionPhaseIds
local ClassIds = ClassContracts.ClassIds

local classNetwork = ReplicatedStorage:WaitForChild("ClassNetwork")
local selectionIntentRemote = classNetwork:WaitForChild("SelectionIntent") :: RemoteEvent
local actionIntentRemote = classNetwork:WaitForChild("ActionIntent") :: RemoteEvent
local stateRemote = classNetwork:WaitForChild("State") :: RemoteEvent
local readStateFunction = classNetwork:WaitForChild("ReadState") :: RemoteFunction

type ClassSelectionStateId = ClassContracts.ClassSelectionStateId
type AuthoritativeClassAssignment = ClassContracts.AuthoritativeClassAssignment
type AuthoritativeClassActionState = ClassContracts.AuthoritativeClassActionState
type ListenerConnection = { Disconnect: (self: ListenerConnection) -> () }

type Entry = {
	player: Player,
	operativeEntityId: string,
	assignment: AuthoritativeClassAssignment,
	actionState: AuthoritativeClassActionState,
	braceOriginPosition: Vector3?,
	processedRequestIds: { [string]: boolean },
	processedRequestOrder: { string },
	lastRequestServerTimestamp: number?,
	processedActionRequestIds: { [string]: boolean },
	processedActionRequestOrder: { string },
	lastActionRequestServerTimestamp: number?,
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
local actionRemoteConnection: RBXScriptConnection? = nil
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

local function idleActionState(): AuthoritativeClassActionState
	return table.freeze({
		actionStateId = ActionStateIds.Idle,
		actionId = nil,
		targetOperativeEntityId = nil,
		startedAtServerTimestamp = nil,
		completionServerTimestamp = nil,
		cooldownEndServerTimestamp = nil,
		statusReasonId = nil,
		revision = 1,
	})
end

local function copyActionState(state: AuthoritativeClassActionState): AuthoritativeClassActionState
	return table.freeze({
		actionStateId = state.actionStateId,
		actionId = state.actionId,
		targetOperativeEntityId = state.targetOperativeEntityId,
		startedAtServerTimestamp = state.startedAtServerTimestamp,
		completionServerTimestamp = state.completionServerTimestamp,
		cooldownEndServerTimestamp = state.cooldownEndServerTimestamp,
		statusReasonId = state.statusReasonId,
		revision = state.revision,
	})
end

local function operativePosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function operationIsActive(phaseId: string): boolean
	local phases = MissionContracts.MissionPhaseIds
	return phaseId == phases.Infiltration or phaseId == phases.Holdout or phaseId == phases.Exfiltration
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
				actionStateId = entry.actionState.actionStateId,
				actionId = entry.actionState.actionId,
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
		ownerActionState = if entry == nil then nil else copyActionState(entry.actionState),
		ownerResources = table.freeze({}),
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
		actionState = idleActionState(),
		braceOriginPosition = nil,
		processedRequestIds = {},
		processedRequestOrder = {},
		lastRequestServerTimestamp = nil,
		processedActionRequestIds = {},
		processedActionRequestOrder = {},
		lastActionRequestServerTimestamp = nil,
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

local function recordProcessedActionRequest(entry: Entry, requestId: string)
	entry.processedActionRequestIds[requestId] = true
	table.insert(entry.processedActionRequestOrder, requestId)
	local maximum = ClassConfig.ActionRequests.maximumProcessedRequestIdsPerOperative
	while #entry.processedActionRequestOrder > maximum do
		local expiredRequestId = table.remove(entry.processedActionRequestOrder, 1)
		if expiredRequestId ~= nil then
			entry.processedActionRequestIds[expiredRequestId] = nil
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

local function evaluateEntry(entry: Entry, serverTimestamp: number, didReloadBegin: boolean): boolean
	local state = entry.actionState
	if state.actionStateId == ActionStateIds.Idle then
		return false
	end
	local movementDistanceStuds = 0
	if state.actionStateId == ActionStateIds.Active then
		local position = operativePosition(entry.player)
		local origin = entry.braceOriginPosition
		movementDistanceStuds = if position == nil or origin == nil then 1e9 else (position - origin).Magnitude
	end
	local resolution = BraceResolver.resolveContinuity(state, {
		isOperationActive = operationIsActive(MissionDirectorService.read().phaseId),
		isActorAlive = OperativeLifeService.isCombatAllowed(entry.player),
		movementDistanceStuds = movementDistanceStuds,
		didReloadBegin = didReloadBegin,
		serverTimestamp = serverTimestamp,
	})
	if not resolution.didChange then
		return false
	end
	entry.actionState = copyActionState(resolution.actionStateAfter)
	if entry.actionState.actionStateId ~= ActionStateIds.Active then
		entry.braceOriginPosition = nil
	end
	return true
end

function Service.requestAction(player: Player, payload: unknown): OperationResult
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
	if not ClassContracts.validateClassActionIntent(payload) then
		return reject(player, RejectionReasonIds.InvalidIntent, requestId)
	end
	local intent = payload :: ClassContracts.ClassActionIntent
	local serverTimestamp = now()
	local previousTimestamp = entry.lastActionRequestServerTimestamp
	local isRateLimited = previousTimestamp ~= nil
		and serverTimestamp - previousTimestamp < ClassConfig.ActionRequests.minimumRequestIntervalSeconds
	entry.lastActionRequestServerTimestamp = serverTimestamp
	local isDuplicateRequest = entry.processedActionRequestIds[intent.requestId] == true

	local didAdvance = evaluateEntry(entry, serverTimestamp, false)
	if isDuplicateRequest then
		if didAdvance then
			rosterRevision += 1
			publishAll()
		end
		return reject(player, RejectionReasonIds.DuplicateRequest, intent.requestId)
	end
	if isRateLimited then
		if didAdvance then
			rosterRevision += 1
			publishAll()
		end
		return reject(player, RejectionReasonIds.RateLimited, intent.requestId)
	end

	local resolution
	if intent.phaseId == ActionPhaseIds.Begin then
		local startPosition = operativePosition(player)
		if startPosition == nil then
			return reject(player, RejectionReasonIds.ActorNotAlive, intent.requestId)
		end
		resolution = BraceResolver.resolveStart(entry.actionState, payload, {
			isParticipant = OperativeLifeService.read(player) ~= nil,
			isOperationActive = operationIsActive(MissionDirectorService.read().phaseId),
			assignedClassId = entry.assignment.classId,
			isActorAlive = OperativeLifeService.isCombatAllowed(player),
			serverTimestamp = serverTimestamp,
			isDuplicateRequest = false,
			isRateLimited = false,
		})
		if resolution.didActivate then
			entry.braceOriginPosition = startPosition
		end
	else
		resolution = BraceResolver.resolveCancel(entry.actionState, payload, serverTimestamp)
	end
	if not resolution.didChange then
		if didAdvance then
			rosterRevision += 1
			publishAll()
		end
		return reject(player, resolution.rejectionReasonId or RejectionReasonIds.InvalidIntent, resolution.requestId)
	end
	entry.actionState = copyActionState(resolution.actionStateAfter)
	if not resolution.didActivate then
		entry.braceOriginPosition = nil
	end
	recordProcessedActionRequest(entry, intent.requestId)
	rosterRevision += 1
	publishAll()
	return result(true, nil, intent.requestId, entry.assignment)
end

function Service.evaluateActionsAt(serverTimestamp: number)
	if not started or type(serverTimestamp) ~= "number" or serverTimestamp ~= serverTimestamp then
		return
	end
	local didChange = false
	for _, entry in entriesByOperativeId do
		didChange = evaluateEntry(entry, serverTimestamp, false) or didChange
	end
	if didChange then
		rosterRevision += 1
		publishAll()
	end
end

function Service.interruptBraceForReload(player: Player, serverTimestamp: number)
	if not started then
		return
	end
	local entry = entryByPlayer[player]
	if entry ~= nil and evaluateEntry(entry, serverTimestamp, true) then
		rosterRevision += 1
		publishAll()
	end
end

function Service.readBraceCadenceMultiplier(player: Player): number
	local entry = entryByPlayer[player]
	if
		entry ~= nil
		and entry.assignment.classId == ClassIds.CombatSpecialist
		and entry.actionState.actionStateId == ActionStateIds.Active
		and entry.actionState.actionId == ActionIds.Brace
	then
		return ClassConfig.Actions.Brace.cadenceIntervalMultiplier
	end
	return 1
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
	actionRemoteConnection = actionIntentRemote.OnServerEvent:Connect(function(player: Player, payload: unknown)
		Service.requestAction(player, payload)
	end)
	readStateFunction.OnServerInvoke = function(player: Player)
		return safeSnapshotForPlayer(player)
	end
	synchronizeSelectionWindow()
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
	if actionRemoteConnection ~= nil then
		actionRemoteConnection:Disconnect()
		actionRemoteConnection = nil
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
