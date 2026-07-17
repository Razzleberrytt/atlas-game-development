--!strict

--[[
	P7-0101 shared specialist-class declarations. These IDs and copied shapes
	are safe to require on either side of the boundary and create no runtime
	owner, network surface, action effect, healing, ammunition grant, or timer.
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

export type ClassTargetKindId =
	"None"
	| "Self"
	| "AliveTeammate"
	| "IncapacitatedTeammate"
	| "SelfOrAliveTeammate"

export type ClassResourceId = "class-resource.medical-charge" | "class-resource.resupply-charge"

export type ClassActionRejectionReasonId =
	"InvalidIntent"
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
	| "OutOfRange"
	| "NoLineOfSight"
	| "MovementInterrupted"
	| "DamageInterrupted"
	| "StaleRevision"
	| "DuplicateRequest"
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
	OutOfRange = "OutOfRange",
	NoLineOfSight = "NoLineOfSight",
	MovementInterrupted = "MovementInterrupted",
	DamageInterrupted = "DamageInterrupted",
	StaleRevision = "StaleRevision",
	DuplicateRequest = "DuplicateRequest",
	EffectCommitRejected = "EffectCommitRejected",
})

return table.freeze(ClassContracts)
