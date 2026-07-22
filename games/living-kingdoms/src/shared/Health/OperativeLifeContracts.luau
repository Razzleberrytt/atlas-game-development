--!strict

--[[
	Canonical shared declarations for operative health, life state, revival,
	solo recovery, and squad viability. These declarations are safe to require
	from client or server code and implement no transitions or runtime behavior.
]]

local OperativeLifeContracts = {}

export type OperativeLifeStateId = "Alive" | "Incapacitated" | "Dead"

export type OperativeLifeTransitionRejectionReasonId =
	"InvalidSnapshot"
	| "InvalidHealth"
	| "InvalidDamage"
	| "InvalidServerTimestamp"
	| "IllegalTransition"
	| "StaleTransition"
	| "TransitionNotReady"
	| "AlreadyResolved"

export type ReviveSessionStatusId = "Active" | "Cancelled" | "Completed"

export type SquadFailureStatusId = "Viable" | "Pending" | "Failed"

export type SquadFailureRejectionReasonId =
	"InvalidFacts"
	| "InvalidState"
	| "InvalidServerTimestamp"
	| "StaleEvaluation"

export type ReviveRejectionReasonId =
	"InvalidReviveInput"
	| "ReviverNotAlive"
	| "TargetNotIncapacitated"
	| "SameOperative"
	| "TargetBusy"
	| "OutOfRange"
	| "NoLineOfSight"
	| "SessionNotActive"
	| "ReviveNotComplete"
	| "ReviveInterrupted"
	| "InvalidServerTimestamp"

export type OperativeHealthState = {
	currentHealth: number,
	maximumHealth: number,
}

export type IncapacitationState = {
	startedAtServerTimestamp: number,
	bleedOutDeadlineServerTimestamp: number,
}

export type SoloRecoveryState = {
	isEligible: boolean,
	recoveriesUsed: number,
	recoveryStartedAtServerTimestamp: number?,
	recoveryCompletionServerTimestamp: number?,
}

export type OperationParticipationFacts = {
	operationStartedSolo: boolean,
	hasEverHadMultipleParticipants: boolean,
}

export type ProcessedDamageEventIds = { [string]: boolean }

export type AuthoritativeOperativeDamage = {
	damageEventId: string,
	sourceEntityId: string?,
	targetEntityId: string,
	damageAmount: number,
	serverTimestamp: number,
}

export type OperativeLifeStateSnapshot = {
	operativeEntityId: string,
	lifeStateId: OperativeLifeStateId,
	healthState: OperativeHealthState,
	incapacitationState: IncapacitationState?,
	soloRecoveryState: SoloRecoveryState,
	processedDamageEventIds: ProcessedDamageEventIds,
}

export type OperativeLifeTransitionResult = {
	didTransition: boolean,
	rejectionReasonId: OperativeLifeTransitionRejectionReasonId?,
	lifeStateIdBefore: OperativeLifeStateId?,
	lifeStateIdAfter: OperativeLifeStateId?,
	transitionServerTimestamp: number?,
	damageEventId: string?,
	snapshotAfter: OperativeLifeStateSnapshot,
}

export type ReviveSessionState = {
	sessionId: string,
	reviverOperativeEntityId: string,
	targetOperativeEntityId: string,
	statusId: ReviveSessionStatusId,
	startedAtServerTimestamp: number,
	completionServerTimestamp: number,
}

export type ReviveBeginAuthorityFacts = {
	sessionId: string,
	reviverOperativeEntityId: string,
	targetOperativeEntityId: string,
	distanceStuds: number,
	hasLineOfSight: boolean,
	serverTimestamp: number,
	activeSessionIdForTarget: string?,
	hasConflictingActiveSession: boolean,
	reviveDurationSeconds: number?,
	restoredHealth: number?,
}

export type ReviveContinuationAuthorityFacts = ReviveBeginAuthorityFacts & {
	reviverRemainsConnectedAndParticipating: boolean,
	reviverMovementRemainedValid: boolean,
	reviverReceivedNoInterruptingDamage: boolean,
	holdRemainsActive: boolean,
}

export type ReviveTransitionResult = {
	didTransition: boolean,
	rejectionReasonId: ReviveRejectionReasonId?,
	normalizedProgress: number,
	sessionStateAfter: ReviveSessionState?,
	targetSnapshotAfter: OperativeLifeStateSnapshot,
}

export type SquadViabilitySnapshot = {
	activeOperativeCount: number,
	hasAliveOperative: boolean,
	hasPendingSoloRecovery: boolean,
	isViable: boolean,
	failureGraceStartedAtServerTimestamp: number?,
	failureDeadlineServerTimestamp: number?,
}

export type SquadFailureFacts = {
	operativeSnapshots: { OperativeLifeStateSnapshot },
	operationStartedSolo: boolean,
	hasEverHadMultipleParticipants: boolean,
	lateJoiningProhibited: boolean,
	isAuthoritativelyAbandoned: boolean,
}

export type SquadFailureState = {
	statusId: SquadFailureStatusId,
	pendingStartedAtServerTimestamp: number?,
	pendingDeadlineServerTimestamp: number?,
	failedAtServerTimestamp: number?,
}

export type SquadFailureEvaluationResult = {
	didResolve: boolean,
	rejectionReasonId: SquadFailureRejectionReasonId?,
	isViable: boolean?,
	hasAliveOperative: boolean?,
	hasPendingSoloRecovery: boolean?,
	activeOperativeCount: number?,
	stateAfter: SquadFailureState,
}

OperativeLifeContracts.OperativeLifeStateIds = table.freeze({
	Alive = "Alive",
	Incapacitated = "Incapacitated",
	Dead = "Dead",
})

OperativeLifeContracts.OperativeLifeTransitionRejectionReasonIds = table.freeze({
	InvalidSnapshot = "InvalidSnapshot",
	InvalidHealth = "InvalidHealth",
	InvalidDamage = "InvalidDamage",
	InvalidServerTimestamp = "InvalidServerTimestamp",
	IllegalTransition = "IllegalTransition",
	StaleTransition = "StaleTransition",
	TransitionNotReady = "TransitionNotReady",
	AlreadyResolved = "AlreadyResolved",
})

OperativeLifeContracts.ReviveSessionStatusIds = table.freeze({
	Active = "Active",
	Cancelled = "Cancelled",
	Completed = "Completed",
})

OperativeLifeContracts.ReviveRejectionReasonIds = table.freeze({
	InvalidReviveInput = "InvalidReviveInput",
	ReviverNotAlive = "ReviverNotAlive",
	TargetNotIncapacitated = "TargetNotIncapacitated",
	SameOperative = "SameOperative",
	TargetBusy = "TargetBusy",
	OutOfRange = "OutOfRange",
	NoLineOfSight = "NoLineOfSight",
	SessionNotActive = "SessionNotActive",
	ReviveNotComplete = "ReviveNotComplete",
	ReviveInterrupted = "ReviveInterrupted",
	InvalidServerTimestamp = "InvalidServerTimestamp",
})

OperativeLifeContracts.SquadFailureStatusIds = table.freeze({
	Viable = "Viable",
	Pending = "Pending",
	Failed = "Failed",
})

OperativeLifeContracts.SquadFailureRejectionReasonIds = table.freeze({
	InvalidFacts = "InvalidFacts",
	InvalidState = "InvalidState",
	InvalidServerTimestamp = "InvalidServerTimestamp",
	StaleEvaluation = "StaleEvaluation",
})

--[[
	The canonical operative entity identity for a connected player. The life owner,
	the combat runtime, and the RPG run-build owner all address the same operative
	through this, so a fact recorded by one is readable by the others.
]]
function OperativeLifeContracts.deriveOperativeEntityId(userId: number): string
	return "operative.player:" .. tostring(userId)
end

return table.freeze(OperativeLifeContracts)
