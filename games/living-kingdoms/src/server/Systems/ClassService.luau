--!strict

--[[
	Server owner for starting-class selection, Brace, and Field Treatment.
	Clients request only a declared action, phase, and optional candidate target;
	all consequential facts and commits are server-derived.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local OperativeLifeConfig = require(ReplicatedStorage.Shared.Config.OperativeLifeConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local MissionContracts = require(ReplicatedStorage.Shared.Mission.MissionContracts)
local BraceResolver = require(script.Parent.BraceResolver)
local ClassSelectionResolver = require(script.Parent.ClassSelectionResolver)
local FieldTreatmentResolver = require(script.Parent.FieldTreatmentResolver)
local FieldResupplyResolver = require(script.Parent.FieldResupplyResolver)
local MissionDirectorService = require(script.Parent.MissionDirectorService)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

local NetworkOperationIds = ClassContracts.ClassSelectionNetworkOperationIds
local RejectionReasonIds = ClassContracts.ClassActionRejectionReasonIds
local SelectionStateIds = ClassContracts.ClassSelectionStateIds
local ActionStateIds = ClassContracts.ClassActionStateIds
local ActionIds = ClassContracts.ClassActionIds
local ActionPhaseIds = ClassContracts.ClassActionPhaseIds
local ClassIds = ClassContracts.ClassIds
local ResourceIds = ClassContracts.ClassResourceIds
local LifeStateIds = OperativeLifeContracts.OperativeLifeStateIds

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
	actionOriginPosition: Vector3?,
	actionActorProcessedDamageEventIds: { [string]: boolean }?,
	resources: { [string]: ClassContracts.AuthoritativeClassResourceState },
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
local engineerResupplyInspector: ((Player) -> (boolean, boolean))? = nil
local engineerResupplyCommitter: ((Player, string, number) -> (boolean, number))? = nil

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

local function distanceAndLineOfSight(actor: Player, target: Player): (number, boolean)
	local actorPosition = operativePosition(actor)
	local targetPosition = operativePosition(target)
	if actorPosition == nil or targetPosition == nil then
		return math.huge, false
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = {}
	if actor.Character ~= nil then
		table.insert(excluded, actor.Character)
	end
	if target.Character ~= nil then
		table.insert(excluded, target.Character)
	end
	parameters.FilterDescendantsInstances = excluded
	local displacement = targetPosition - actorPosition
	return displacement.Magnitude, Workspace:Raycast(actorPosition, displacement, parameters) == nil
end

local function resourcesForClass(classId: string): { [string]: ClassContracts.AuthoritativeClassResourceState }
	local resourceConfig
	if classId == ClassIds.Medic then
		resourceConfig = ClassConfig.Resources.MedicalCharge
	elseif classId == ClassIds.Engineer then
		resourceConfig = ClassConfig.Resources.ResupplyCharge
	else
		return {}
	end
	local maximum = resourceConfig.maximumAmount
	return {
		[resourceConfig.resourceId] = table.freeze({
			resourceId = resourceConfig.resourceId,
			currentAmount = maximum,
			maximumAmount = maximum,
		}),
	}
end

local function sortedResources(entry: Entry): { ClassContracts.AuthoritativeClassResourceState }
	local resources = {}
	for _, resource in entry.resources do
		table.insert(
			resources,
			table.freeze({
				resourceId = resource.resourceId,
				currentAmount = resource.currentAmount,
				maximumAmount = resource.maximumAmount,
			})
		)
	end
	table.sort(resources, function(left, right)
		return left.resourceId < right.resourceId
	end)
	return table.freeze(resources)
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
		ownerResources = if entry == nil then table.freeze({}) else sortedResources(entry),
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
		actionOriginPosition = nil,
		actionActorProcessedDamageEventIds = nil,
		resources = resourcesForClass(ClassConfig.Selection.defaultClassId),
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
	local previousClassId = entry.assignment.classId
	entry.assignment = copyAssignment(resolution.assignmentAfter)
	if resolution.assignmentAfter.classId ~= previousClassId then
		entry.resources = resourcesForClass(resolution.assignmentAfter.classId)
	end
	if resolution.requestId ~= nil then
		recordProcessedRequest(entry, resolution.requestId)
	end
	rosterRevision += 1
	publishAll()
	return result(true, nil, resolution.requestId, entry.assignment)
end

local function actorTookDamage(entry: Entry, snapshot: OperativeLifeContracts.OperativeLifeStateSnapshot): boolean
	local baseline = entry.actionActorProcessedDamageEventIds
	if baseline == nil then
		return false
	end
	for damageEventId in snapshot.processedDamageEventIds do
		if baseline[damageEventId] ~= true then
			return true
		end
	end
	return false
end

local function clearActionContinuity(entry: Entry)
	entry.actionOriginPosition = nil
	entry.actionActorProcessedDamageEventIds = nil
end

local function evaluateEntry(entry: Entry, serverTimestamp: number, didReloadBegin: boolean): boolean
	local state = entry.actionState
	if state.actionStateId == ActionStateIds.Idle then
		return false
	end
	local movementDistanceStuds = 0
	if state.actionStateId == ActionStateIds.Active then
		local position = operativePosition(entry.player)
		local origin = entry.actionOriginPosition
		movementDistanceStuds = if position == nil or origin == nil then 1e9 else (position - origin).Magnitude
	end
	local resolution
	if state.actionId == ActionIds.FieldTreatment then
		local actorRead = OperativeLifeService.read(entry.player)
		local targetId = state.targetOperativeEntityId
		local targetEntry = if targetId == nil then nil else entriesByOperativeId[targetId]
		local targetRead = if targetId == nil then nil else OperativeLifeService.readByOperativeEntityId(targetId)
		local targetPlayer = if targetEntry == nil then nil else targetEntry.player
		local distanceStuds, hasLineOfSight = 0, false
		if targetPlayer ~= nil then
			distanceStuds, hasLineOfSight = distanceAndLineOfSight(entry.player, targetPlayer)
		end
		local targetSnapshot = if targetRead == nil then nil else targetRead.snapshot
		resolution = FieldTreatmentResolver.resolveContinuity(state, {
			isOperationActive = operationIsActive(MissionDirectorService.read().phaseId),
			isActorAlive = actorRead ~= nil and actorRead.snapshot.lifeStateId == LifeStateIds.Alive,
			movementDistanceStuds = movementDistanceStuds,
			didActorTakeDamage = actorRead ~= nil and actorTookDamage(entry, actorRead.snapshot),
			isTargetKnown = targetEntry ~= nil and targetRead ~= nil,
			isTargetAlive = targetSnapshot ~= nil and targetSnapshot.lifeStateId == LifeStateIds.Alive,
			isTargetInjured = targetSnapshot ~= nil
				and targetSnapshot.healthState.currentHealth < targetSnapshot.healthState.maximumHealth,
			distanceStuds = distanceStuds,
			hasLineOfSight = hasLineOfSight,
			serverTimestamp = serverTimestamp,
		})
		if resolution.shouldCommitHealing then
			local medical = entry.resources[ResourceIds.MedicalCharge]
			local committed = if targetRead == nil
					or targetId == nil
					or medical == nil
				then nil
				else OperativeLifeService.applyAuthoritativeHealing(targetId, targetRead.revision, {
					healingEventId = string.format("class-treatment:%s:%d", entry.operativeEntityId, state.revision),
					sourceEntityId = entry.operativeEntityId,
					targetEntityId = targetId,
					healingAmount = ClassConfig.Actions.FieldTreatment.healAmount,
					serverTimestamp = serverTimestamp,
				})
			if committed ~= nil and committed.didCommit and medical ~= nil then
				entry.resources[ResourceIds.MedicalCharge] = table.freeze({
					resourceId = medical.resourceId,
					currentAmount = medical.currentAmount - ClassConfig.Actions.FieldTreatment.resourceCost,
					maximumAmount = medical.maximumAmount,
				})
			else
				resolution = FieldTreatmentResolver.resolveEffectRejected(state, serverTimestamp)
			end
		end
	elseif state.actionId == ActionIds.FieldResupply then
		local actorRead = OperativeLifeService.read(entry.player)
		local targetId = state.targetOperativeEntityId
		local targetEntry = if targetId == nil then nil else entriesByOperativeId[targetId]
		local targetPlayer = if targetEntry == nil then nil else targetEntry.player
		local targetRead = if targetPlayer == nil then nil else OperativeLifeService.read(targetPlayer)
		local distanceStuds, hasLineOfSight = 0, false
		if targetPlayer == entry.player then
			hasLineOfSight = true
		elseif targetPlayer ~= nil then
			distanceStuds, hasLineOfSight = distanceAndLineOfSight(entry.player, targetPlayer)
		end
		local compatible, hasCapacity = false, false
		if targetPlayer ~= nil and engineerResupplyInspector ~= nil then
			compatible, hasCapacity = engineerResupplyInspector(targetPlayer)
		end
		local supply = entry.resources[ResourceIds.ResupplyCharge]
		resolution = FieldResupplyResolver.resolveContinuity(state, {
			isParticipant = actorRead ~= nil,
			isOperationActive = operationIsActive(MissionDirectorService.read().phaseId),
			assignedClassId = entry.assignment.classId,
			isActorAlive = actorRead ~= nil and actorRead.snapshot.lifeStateId == LifeStateIds.Alive,
			resourceAmount = if supply == nil then 0 else supply.currentAmount,
			isTargetKnown = targetEntry ~= nil and targetRead ~= nil,
			isTargetAlive = targetRead ~= nil and targetRead.snapshot.lifeStateId == LifeStateIds.Alive,
			isWeaponCompatible = compatible,
			hasCapacity = hasCapacity,
			distanceStuds = distanceStuds,
			hasLineOfSight = hasLineOfSight,
			movementDistanceStuds = movementDistanceStuds,
			didActorTakeDamage = actorRead ~= nil and actorTookDamage(entry, actorRead.snapshot),
			serverTimestamp = serverTimestamp,
		})
		if resolution.shouldCommitResupply then
			local didCommit, grantedRounds = false, 0
			if targetPlayer ~= nil and supply ~= nil and engineerResupplyCommitter ~= nil then
				didCommit, grantedRounds = engineerResupplyCommitter(
					targetPlayer,
					string.format("class-resupply:%s:%d", entry.operativeEntityId, state.revision),
					ClassConfig.Actions.FieldResupply.roundsPerCharge
				)
			end
			if didCommit and grantedRounds > 0 and supply ~= nil then
				entry.resources[ResourceIds.ResupplyCharge] = table.freeze({
					resourceId = supply.resourceId,
					currentAmount = supply.currentAmount - ClassConfig.Actions.FieldResupply.resourceCost,
					maximumAmount = supply.maximumAmount,
				})
			else
				resolution = FieldResupplyResolver.resolveEffectRejected(state, serverTimestamp)
			end
		end
	else
		resolution = BraceResolver.resolveContinuity(state, {
			isOperationActive = operationIsActive(MissionDirectorService.read().phaseId),
			isActorAlive = OperativeLifeService.isCombatAllowed(entry.player),
			movementDistanceStuds = movementDistanceStuds,
			didReloadBegin = didReloadBegin,
			serverTimestamp = serverTimestamp,
		})
	end
	if not resolution.didChange then
		return false
	end
	entry.actionState = copyActionState(resolution.actionStateAfter)
	if entry.actionState.actionStateId ~= ActionStateIds.Active then
		clearActionContinuity(entry)
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
		if intent.actionId == ActionIds.FieldTreatment then
			local targetId = intent.candidateTargetOperativeEntityId
			local targetEntry = if targetId == nil then nil else entriesByOperativeId[targetId]
			local targetRead = if targetId == nil then nil else OperativeLifeService.readByOperativeEntityId(targetId)
			local targetPlayer = if targetEntry == nil then nil else targetEntry.player
			local distanceStuds, hasLineOfSight = 0, false
			if targetPlayer ~= nil then
				distanceStuds, hasLineOfSight = distanceAndLineOfSight(player, targetPlayer)
			end
			local targetSnapshot = if targetRead == nil then nil else targetRead.snapshot
			local medical = entry.resources[ResourceIds.MedicalCharge]
			resolution = FieldTreatmentResolver.resolveStart(entry.actionState, payload, {
				isParticipant = OperativeLifeService.read(player) ~= nil,
				isOperationActive = operationIsActive(MissionDirectorService.read().phaseId),
				assignedClassId = entry.assignment.classId,
				isActorAlive = OperativeLifeService.isCombatAllowed(player),
				resourceAmount = if medical == nil then 0 else medical.currentAmount,
				isTargetKnown = targetEntry ~= nil and targetRead ~= nil,
				isSelfTarget = targetId == entry.operativeEntityId,
				isTargetAlive = targetSnapshot ~= nil and targetSnapshot.lifeStateId == LifeStateIds.Alive,
				isTargetInjured = targetSnapshot ~= nil
					and targetSnapshot.healthState.currentHealth < targetSnapshot.healthState.maximumHealth,
				distanceStuds = distanceStuds,
				hasLineOfSight = hasLineOfSight,
				serverTimestamp = serverTimestamp,
			})
			if resolution.didActivate then
				local actorRead = OperativeLifeService.read(player)
				entry.actionOriginPosition = startPosition
				entry.actionActorProcessedDamageEventIds = if actorRead == nil
					then {}
					else table.clone(actorRead.snapshot.processedDamageEventIds)
			end
		elseif intent.actionId == ActionIds.FieldResupply then
			local targetId = intent.candidateTargetOperativeEntityId
			local targetEntry = if targetId == nil then nil else entriesByOperativeId[targetId]
			local targetPlayer = if targetEntry == nil then nil else targetEntry.player
			local targetRead = if targetPlayer == nil then nil else OperativeLifeService.read(targetPlayer)
			local distanceStuds, hasLineOfSight = 0, false
			if targetPlayer == player then
				hasLineOfSight = true
			elseif targetPlayer ~= nil then
				distanceStuds, hasLineOfSight = distanceAndLineOfSight(player, targetPlayer)
			end
			local compatible, hasCapacity = false, false
			if targetPlayer ~= nil and engineerResupplyInspector ~= nil then
				compatible, hasCapacity = engineerResupplyInspector(targetPlayer)
			end
			local supply = entry.resources[ResourceIds.ResupplyCharge]
			resolution = FieldResupplyResolver.resolveStart(entry.actionState, payload, {
				isParticipant = OperativeLifeService.read(player) ~= nil,
				isOperationActive = operationIsActive(MissionDirectorService.read().phaseId),
				assignedClassId = entry.assignment.classId,
				isActorAlive = OperativeLifeService.isCombatAllowed(player),
				resourceAmount = if supply == nil then 0 else supply.currentAmount,
				isTargetKnown = targetEntry ~= nil and targetRead ~= nil,
				isTargetAlive = targetRead ~= nil and targetRead.snapshot.lifeStateId == LifeStateIds.Alive,
				isWeaponCompatible = compatible,
				hasCapacity = hasCapacity,
				distanceStuds = distanceStuds,
				hasLineOfSight = hasLineOfSight,
				movementDistanceStuds = 0,
				didActorTakeDamage = false,
				serverTimestamp = serverTimestamp,
			})
			if resolution.didActivate then
				local actorRead = OperativeLifeService.read(player)
				entry.actionOriginPosition = startPosition
				entry.actionActorProcessedDamageEventIds = if actorRead == nil
					then {}
					else table.clone(actorRead.snapshot.processedDamageEventIds)
			end
		else
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
				entry.actionOriginPosition = startPosition
			end
		end
	else
		resolution = if entry.actionState.actionId == ActionIds.FieldTreatment
			then FieldTreatmentResolver.resolveCancel(entry.actionState, payload, serverTimestamp)
			else if entry.actionState.actionId == ActionIds.FieldResupply
				then FieldResupplyResolver.resolveCancel(entry.actionState, payload, serverTimestamp)
				else BraceResolver.resolveCancel(entry.actionState, payload, serverTimestamp)
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
		clearActionContinuity(entry)
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

function Service.readMedicReviveBenefits(player: Player): (number, number, boolean)
	local entry = entryByPlayer[player]
	if entry ~= nil and entry.assignment.classId == ClassIds.Medic then
		return OperativeLifeConfig.ReviveDurationSeconds * ClassConfig.Actions.ReviveAssistance.reviveDurationMultiplier,
			ClassConfig.Actions.ReviveAssistance.restoredHealth,
			true
	end
	return OperativeLifeConfig.ReviveDurationSeconds, OperativeLifeConfig.ReviveHealth, false
end

function Service.configureEngineerResupplyBoundary(
	inspector: ((Player) -> (boolean, boolean))?,
	committer: ((Player, string, number) -> (boolean, number))?
)
	assert(inspector == nil or type(inspector) == "function", "engineer inspector must be a function or nil")
	assert(committer == nil or type(committer) == "function", "engineer committer must be a function or nil")
	assert((inspector == nil) == (committer == nil), "engineer boundary must configure both functions together")
	engineerResupplyInspector = inspector
	engineerResupplyCommitter = committer
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
