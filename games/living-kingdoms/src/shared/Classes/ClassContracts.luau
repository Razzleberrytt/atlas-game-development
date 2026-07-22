--!strict

--[[
	P7 shared specialist-class declarations. These IDs, action-intent shapes,
	and copied presentation records are safe on either side of the boundary.
	Brace, Field Treatment, revive assistance, and Field Resupply are active
	through P7-0106. Objective effects and client-authored authority remain absent.
]]

local ClassContracts = {}

export type ClassId = "class.combat-specialist" | "class.medic" | "class.engineer"

export type ClassActionId =
	"class-action.brace"
	| "class-action.field-treatment"
	| "class-action.revive-assistance"
	| "class-action.field-resupply"

export type ClassActionStateId = "Idle" | "Active" | "Cooldown"
export type ClassActionPhaseId = "Begin" | "End" | "Cancel"
export type ClassSelectionStateId = "Open" | "Locked"
export type ClassSelectionNetworkOperationId = "Snapshot" | "Rejected"

export type ClassTargetKindId = "None" | "Self" | "AliveTeammate" | "IncapacitatedTeammate" | "SelfOrAliveTeammate"

export type ClassResourceId = "class-resource.medical-charge" | "class-resource.resupply-charge"

export type ClassActionRejectionReasonId =
	"ServiceStopped"
	| "InvalidIntent"
	| "UnknownClass"
	| "UnknownAction"
	| "UnknownTarget"
	| "NotParticipant"
	| "OperationPhaseInvalid"
	| "OperationResolved"
	| "SelectionClosed"
	| "ClassLocked"
	| "ClassUnavailable"
	| "WrongAssignedClass"
	| "ActorNotAlive"
	| "ActionAlreadyActive"
	| "ActionOnCooldown"
	| "InsufficientResource"
	| "InvalidTarget"
	| "SelfTargetNotAllowed"
	| "TargetNotAlive"
	| "TargetNotIncapacitated"
	| "TargetNotInjured"
	| "IncompatibleWeapon"
	| "NoCapacity"
	| "OutOfRange"
	| "NoLineOfSight"
	| "MovementInterrupted"
	| "DamageInterrupted"
	| "ReloadInterrupted"
	| "ActionCancelled"
	| "ActionCompleted"
	| "StaleRevision"
	| "DuplicateRequest"
	| "RateLimited"
	| "EffectCommitRejected"

export type AuthoritativeClassAssignment = {
	operativeEntityId: string,
	classId: ClassId,
	selectionStateId: ClassSelectionStateId,
	revision: number,
}

export type AuthoritativeClassActionState = {
	actionStateId: ClassActionStateId,
	actionId: ClassActionId?,
	targetOperativeEntityId: string?,
	startedAtServerTimestamp: number?,
	completionServerTimestamp: number?,
	cooldownEndServerTimestamp: number?,
	statusReasonId: ClassActionRejectionReasonId?,
	revision: number,
}

export type AuthoritativeClassResourceState = {
	resourceId: ClassResourceId,
	currentAmount: number,
	maximumAmount: number,
}

export type ClassSelectionIntent = {
	requestId: string,
	classId: ClassId,
}

export type ClassActionIntent = {
	requestId: string,
	actionId: ClassActionId,
	phaseId: ClassActionPhaseId,
	candidateTargetOperativeEntityId: string?,
}

export type ClassOwnerPresentationSnapshot = {
	assignment: AuthoritativeClassAssignment,
	actionState: AuthoritativeClassActionState,
	resources: { AuthoritativeClassResourceState },
}

export type ClassSquadMemberPresentationSnapshot = {
	operativeEntityId: string,
	classId: ClassId,
	actionStateId: ClassActionStateId,
	actionId: ClassActionId?,
}

export type SafeClassSelectionSnapshot = {
	operationId: ClassSelectionNetworkOperationId,
	rosterRevision: number,
	selectionStateId: ClassSelectionStateId,
	ownerAssignment: AuthoritativeClassAssignment?,
	ownerActionState: AuthoritativeClassActionState?,
	ownerResources: { AuthoritativeClassResourceState },
	squadMembers: { ClassSquadMemberPresentationSnapshot },
}

export type SafeClassSelectionRejection = {
	operationId: ClassSelectionNetworkOperationId,
	rosterRevision: number,
	rejectionReasonId: ClassActionRejectionReasonId,
	requestId: string?,
}

ClassContracts.ClassIds = table.freeze({
	CombatSpecialist = "class.combat-specialist",
	Medic = "class.medic",
	Engineer = "class.engineer",
})

ClassContracts.ClassActionIds = table.freeze({
	Brace = "class-action.brace",
	FieldTreatment = "class-action.field-treatment",
	ReviveAssistance = "class-action.revive-assistance",
	FieldResupply = "class-action.field-resupply",
})

ClassContracts.ClassActionStateIds = table.freeze({
	Idle = "Idle",
	Active = "Active",
	Cooldown = "Cooldown",
})

ClassContracts.ClassActionPhaseIds = table.freeze({
	Begin = "Begin",
	End = "End",
	Cancel = "Cancel",
})

ClassContracts.ClassSelectionStateIds = table.freeze({
	Open = "Open",
	Locked = "Locked",
})

ClassContracts.ClassSelectionNetworkOperationIds = table.freeze({
	Snapshot = "Snapshot",
	Rejected = "Rejected",
})

ClassContracts.ClassTargetKindIds = table.freeze({
	None = "None",
	Self = "Self",
	AliveTeammate = "AliveTeammate",
	IncapacitatedTeammate = "IncapacitatedTeammate",
	SelfOrAliveTeammate = "SelfOrAliveTeammate",
})

ClassContracts.ClassResourceIds = table.freeze({
	MedicalCharge = "class-resource.medical-charge",
	ResupplyCharge = "class-resource.resupply-charge",
})

ClassContracts.ClassActionRejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidIntent = "InvalidIntent",
	UnknownClass = "UnknownClass",
	UnknownAction = "UnknownAction",
	UnknownTarget = "UnknownTarget",
	NotParticipant = "NotParticipant",
	OperationPhaseInvalid = "OperationPhaseInvalid",
	OperationResolved = "OperationResolved",
	SelectionClosed = "SelectionClosed",
	ClassLocked = "ClassLocked",
	ClassUnavailable = "ClassUnavailable",
	WrongAssignedClass = "WrongAssignedClass",
	ActorNotAlive = "ActorNotAlive",
	ActionAlreadyActive = "ActionAlreadyActive",
	ActionOnCooldown = "ActionOnCooldown",
	InsufficientResource = "InsufficientResource",
	InvalidTarget = "InvalidTarget",
	SelfTargetNotAllowed = "SelfTargetNotAllowed",
	TargetNotAlive = "TargetNotAlive",
	TargetNotIncapacitated = "TargetNotIncapacitated",
	TargetNotInjured = "TargetNotInjured",
	IncompatibleWeapon = "IncompatibleWeapon",
	NoCapacity = "NoCapacity",
	OutOfRange = "OutOfRange",
	NoLineOfSight = "NoLineOfSight",
	MovementInterrupted = "MovementInterrupted",
	DamageInterrupted = "DamageInterrupted",
	ReloadInterrupted = "ReloadInterrupted",
	ActionCancelled = "ActionCancelled",
	ActionCompleted = "ActionCompleted",
	StaleRevision = "StaleRevision",
	DuplicateRequest = "DuplicateRequest",
	RateLimited = "RateLimited",
	EffectCommitRejected = "EffectCommitRejected",
})

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and value ~= "" and #value <= maximumLength
end

local function isNonnegativeInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 0
		and value % 1 == 0
end

local function containsValue(values: { [string]: string }, candidate: unknown): boolean
	if type(candidate) ~= "string" then
		return false
	end
	for _, value in values do
		if value == candidate then
			return true
		end
	end
	return false
end

local function hasOnlyKeys(value: { [any]: any }, permittedKeys: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or permittedKeys[key] ~= true then
			return false
		end
	end
	return true
end

function ClassContracts.isKnownClassId(value: unknown): boolean
	return containsValue(ClassContracts.ClassIds, value)
end

function ClassContracts.isKnownActionId(value: unknown): boolean
	return containsValue(ClassContracts.ClassActionIds, value)
end

function ClassContracts.validateClassActionIntent(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local intent = value :: { [any]: any }
	if
		not hasOnlyKeys(intent, {
			requestId = true,
			actionId = true,
			phaseId = true,
			candidateTargetOperativeEntityId = true,
		})
	then
		return false
	end
	return isNonEmptyBoundedString(intent.requestId, 128)
		and isNonEmptyBoundedString(intent.actionId, 64)
		and containsValue(ClassContracts.ClassActionPhaseIds, intent.phaseId)
		and (
			intent.candidateTargetOperativeEntityId == nil
			or isNonEmptyBoundedString(intent.candidateTargetOperativeEntityId, 128)
		)
end

function ClassContracts.validateClassSelectionIntent(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local intent = value :: { [any]: any }
	if not hasOnlyKeys(intent, { requestId = true, classId = true }) then
		return false
	end
	return isNonEmptyBoundedString(intent.requestId, 128) and isNonEmptyBoundedString(intent.classId, 64)
end

function ClassContracts.validateAuthoritativeClassAssignment(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local assignment = value :: { [any]: any }
	if
		not hasOnlyKeys(assignment, {
			operativeEntityId = true,
			classId = true,
			selectionStateId = true,
			revision = true,
		})
	then
		return false
	end
	return isNonEmptyBoundedString(assignment.operativeEntityId, 128)
		and ClassContracts.isKnownClassId(assignment.classId)
		and containsValue(ClassContracts.ClassSelectionStateIds, assignment.selectionStateId)
		and isNonnegativeInteger(assignment.revision)
end

function ClassContracts.validateAuthoritativeClassActionState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local action = value :: { [any]: any }
	if
		not hasOnlyKeys(action, {
			actionStateId = true,
			actionId = true,
			targetOperativeEntityId = true,
			startedAtServerTimestamp = true,
			completionServerTimestamp = true,
			cooldownEndServerTimestamp = true,
			statusReasonId = true,
			revision = true,
		})
	then
		return false
	end
	local function optionalFiniteTimestamp(candidate: unknown): boolean
		return candidate == nil
			or (
				type(candidate) == "number"
				and candidate == candidate
				and candidate ~= math.huge
				and candidate ~= -math.huge
			)
	end
	return containsValue(ClassContracts.ClassActionStateIds, action.actionStateId)
		and (action.actionId == nil or ClassContracts.isKnownActionId(action.actionId))
		and (action.targetOperativeEntityId == nil or isNonEmptyBoundedString(action.targetOperativeEntityId, 128))
		and optionalFiniteTimestamp(action.startedAtServerTimestamp)
		and optionalFiniteTimestamp(action.completionServerTimestamp)
		and optionalFiniteTimestamp(action.cooldownEndServerTimestamp)
		and (action.statusReasonId == nil or containsValue(
			ClassContracts.ClassActionRejectionReasonIds,
			action.statusReasonId
		))
		and isNonnegativeInteger(action.revision)
end

local function validateResourceState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local resource = value :: { [any]: any }
	return hasOnlyKeys(resource, { resourceId = true, currentAmount = true, maximumAmount = true })
		and containsValue(ClassContracts.ClassResourceIds, resource.resourceId)
		and isNonnegativeInteger(resource.currentAmount)
		and isNonnegativeInteger(resource.maximumAmount)
		and resource.currentAmount <= resource.maximumAmount
end

local function validateSquadMember(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local member = value :: { [any]: any }
	if
		not hasOnlyKeys(member, {
			operativeEntityId = true,
			classId = true,
			actionStateId = true,
			actionId = true,
		})
	then
		return false
	end
	return isNonEmptyBoundedString(member.operativeEntityId, 128)
		and ClassContracts.isKnownClassId(member.classId)
		and containsValue(ClassContracts.ClassActionStateIds, member.actionStateId)
		and (member.actionId == nil or containsValue(ClassContracts.ClassActionIds, member.actionId))
end

function ClassContracts.validateSafeClassSelectionSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: { [any]: any }
	if
		not hasOnlyKeys(snapshot, {
			operationId = true,
			rosterRevision = true,
			selectionStateId = true,
			ownerAssignment = true,
			ownerActionState = true,
			ownerResources = true,
			squadMembers = true,
		})
	then
		return false
	end
	if snapshot.operationId ~= ClassContracts.ClassSelectionNetworkOperationIds.Snapshot then
		return false
	end
	if
		not isNonnegativeInteger(snapshot.rosterRevision)
		or not containsValue(ClassContracts.ClassSelectionStateIds, snapshot.selectionStateId)
		or (snapshot.ownerAssignment ~= nil and not ClassContracts.validateAuthoritativeClassAssignment(
			snapshot.ownerAssignment
		))
		or (snapshot.ownerActionState ~= nil and not ClassContracts.validateAuthoritativeClassActionState(
			snapshot.ownerActionState
		))
		or type(snapshot.ownerResources) ~= "table"
		or type(snapshot.squadMembers) ~= "table"
	then
		return false
	end
	for index, resource in snapshot.ownerResources :: { [any]: any } do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or not validateResourceState(resource) then
			return false
		end
	end
	local seenOperativeIds = {}
	for index, member in snapshot.squadMembers :: { [any]: any } do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or not validateSquadMember(member) then
			return false
		end
		local operativeEntityId = member.operativeEntityId
		if seenOperativeIds[operativeEntityId] then
			return false
		end
		seenOperativeIds[operativeEntityId] = true
	end
	return true
end

function ClassContracts.validateSafeClassSelectionRejection(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local rejection = value :: { [any]: any }
	if
		not hasOnlyKeys(rejection, {
			operationId = true,
			rosterRevision = true,
			rejectionReasonId = true,
			requestId = true,
		})
	then
		return false
	end
	return rejection.operationId == ClassContracts.ClassSelectionNetworkOperationIds.Rejected
		and isNonnegativeInteger(rejection.rosterRevision)
		and containsValue(ClassContracts.ClassActionRejectionReasonIds, rejection.rejectionReasonId)
		and (rejection.requestId == nil or isNonEmptyBoundedString(rejection.requestId, 128))
end

return table.freeze(ClassContracts)
