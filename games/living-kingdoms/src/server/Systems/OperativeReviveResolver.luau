--!strict

--[[
	Pure server-domain revive eligibility and continuous-hold transitions.
	Callers own every authority fact and must atomically commit returned state.
	This module owns no runtime sessions, clocks, scheduling, characters, or UI.

	Stable begin precedence: malformed input, invalid timestamp, same operative,
	reviver state, target state, target busy, range, then line of sight.

	Stable continuation precedence: malformed input, invalid timestamp, session
	status, participant/session mismatch, reviver state, target state, hold
	continuity, range, line of sight, stale timestamp, then deadline readiness.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeLifeConfig = require(ReplicatedStorage.Shared.Config.OperativeLifeConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)

type OperativeLifeStateSnapshot = OperativeLifeContracts.OperativeLifeStateSnapshot
type ReviveBeginAuthorityFacts = OperativeLifeContracts.ReviveBeginAuthorityFacts
type ReviveContinuationAuthorityFacts = OperativeLifeContracts.ReviveContinuationAuthorityFacts
type ReviveRejectionReasonId = OperativeLifeContracts.ReviveRejectionReasonId
type ReviveSessionState = OperativeLifeContracts.ReviveSessionState
type ReviveTransitionResult = OperativeLifeContracts.ReviveTransitionResult

type OperativeReviveResolver = {
	beginRevive: (
		reviverSnapshot: OperativeLifeStateSnapshot,
		targetSnapshot: OperativeLifeStateSnapshot,
		authorityFacts: ReviveBeginAuthorityFacts
	) -> ReviveTransitionResult,
	continueRevive: (
		reviverSnapshot: OperativeLifeStateSnapshot,
		targetSnapshot: OperativeLifeStateSnapshot,
		sessionState: ReviveSessionState,
		authorityFacts: ReviveContinuationAuthorityFacts
	) -> ReviveTransitionResult,
}

local Resolver: OperativeReviveResolver = {} :: OperativeReviveResolver
local lifeStateIds = OperativeLifeContracts.OperativeLifeStateIds
local reasons = OperativeLifeContracts.ReviveRejectionReasonIds
local statusIds = OperativeLifeContracts.ReviveSessionStatusIds

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in value do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function isKnownLifeStateId(value: unknown): boolean
	return value == lifeStateIds.Alive or value == lifeStateIds.Incapacitated or value == lifeStateIds.Dead
end

local function hasValidTimestampPair(startedAt: unknown, completionAt: unknown): boolean
	if startedAt == nil and completionAt == nil then
		return true
	end
	return isFiniteNumber(startedAt)
		and isFiniteNumber(completionAt)
		and (completionAt :: number) >= (startedAt :: number)
end

local function isValidSoloRecoveryState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end

	local state = value :: any
	return type(state.isEligible) == "boolean"
		and isFiniteNumber(state.recoveriesUsed)
		and state.recoveriesUsed % 1 == 0
		and state.recoveriesUsed >= 0
		and state.recoveriesUsed <= OperativeLifeConfig.SoloRecoveriesPerOperation
		and hasValidTimestampPair(state.recoveryStartedAtServerTimestamp, state.recoveryCompletionServerTimestamp)
end

local function isValidIncapacitationState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end

	local state = value :: any
	return isFiniteNumber(state.startedAtServerTimestamp)
		and isFiniteNumber(state.bleedOutDeadlineServerTimestamp)
		and state.bleedOutDeadlineServerTimestamp
			== state.startedAtServerTimestamp + OperativeLifeConfig.BleedOutDurationSeconds
end

local function isValidProcessedDamageEventIds(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end

	for damageEventId, wasProcessed in value :: any do
		if not isNonEmptyString(damageEventId) or wasProcessed ~= true then
			return false
		end
	end
	return true
end

local function isValidSnapshot(snapshot: unknown): boolean
	if type(snapshot) ~= "table" then
		return false
	end

	local value = snapshot :: any
	if
		not isNonEmptyString(value.operativeEntityId)
		or not isKnownLifeStateId(value.lifeStateId)
		or type(value.healthState) ~= "table"
		or not isValidSoloRecoveryState(value.soloRecoveryState)
		or not isValidProcessedDamageEventIds(value.processedDamageEventIds)
	then
		return false
	end

	local currentHealth = value.healthState.currentHealth
	local maximumHealth = value.healthState.maximumHealth
	if
		not isFiniteNumber(currentHealth)
		or not isFiniteNumber(maximumHealth)
		or maximumHealth ~= OperativeLifeConfig.MaximumHealth
		or currentHealth < 0
		or currentHealth > maximumHealth
	then
		return false
	end
	if value.lifeStateId == lifeStateIds.Alive then
		return currentHealth > 0 and value.incapacitationState == nil
	end
	if value.lifeStateId == lifeStateIds.Incapacitated then
		return currentHealth == 0 and isValidIncapacitationState(value.incapacitationState)
	end
	return currentHealth == 0
		and (value.incapacitationState == nil or isValidIncapacitationState(value.incapacitationState))
end

local function isValidCommonFactsShape(facts: unknown): boolean
	if type(facts) ~= "table" then
		return false
	end

	local value = facts :: any
	return isNonEmptyString(value.sessionId)
		and isNonEmptyString(value.reviverOperativeEntityId)
		and isNonEmptyString(value.targetOperativeEntityId)
		and type(value.distanceStuds) == "number"
		and type(value.hasLineOfSight) == "boolean"
		and type(value.serverTimestamp) == "number"
		and (value.activeSessionIdForTarget == nil or isNonEmptyString(value.activeSessionIdForTarget))
		and type(value.hasConflictingActiveSession) == "boolean"
end

local function isValidBeginInput(reviverSnapshot: unknown, targetSnapshot: unknown, facts: unknown): boolean
	if not isValidSnapshot(reviverSnapshot) or not isValidSnapshot(targetSnapshot) then
		return false
	end
	if not isValidCommonFactsShape(facts) then
		return false
	end

	local reviver = reviverSnapshot :: any
	local target = targetSnapshot :: any
	local value = facts :: any
	return value.reviverOperativeEntityId == reviver.operativeEntityId
		and value.targetOperativeEntityId == target.operativeEntityId
end

local function isValidSessionShape(sessionState: unknown): boolean
	if type(sessionState) ~= "table" then
		return false
	end

	local session = sessionState :: any
	if
		not isNonEmptyString(session.sessionId)
		or not isNonEmptyString(session.reviverOperativeEntityId)
		or not isNonEmptyString(session.targetOperativeEntityId)
		or (session.statusId ~= statusIds.Active and session.statusId ~= statusIds.Cancelled and session.statusId ~= statusIds.Completed)
		or not isFiniteNumber(session.startedAtServerTimestamp)
		or session.startedAtServerTimestamp < 0
		or not isFiniteNumber(session.completionServerTimestamp)
		or session.completionServerTimestamp < session.startedAtServerTimestamp
	then
		return false
	end

	if session.statusId == statusIds.Active then
		return session.completionServerTimestamp
			== session.startedAtServerTimestamp + OperativeLifeConfig.ReviveDurationSeconds
	end
	return true
end

local function isValidContinuationInput(
	reviverSnapshot: unknown,
	targetSnapshot: unknown,
	sessionState: unknown,
	facts: unknown
): boolean
	return isValidSnapshot(reviverSnapshot)
		and isValidSnapshot(targetSnapshot)
		and isValidSessionShape(sessionState)
		and isValidCommonFactsShape(facts)
		and type((facts :: any).holdRemainsActive) == "boolean"
end

local function copiedProgress(sessionState: any, serverTimestamp: unknown): number
	if sessionState == nil or not isValidSessionShape(sessionState) or not isFiniteNumber(serverTimestamp) then
		return 0
	end
	if sessionState.statusId == statusIds.Completed then
		return 1
	end
	if sessionState.statusId ~= statusIds.Active then
		return 0
	end
	local elapsed = (serverTimestamp :: number) - sessionState.startedAtServerTimestamp
	return math.clamp(elapsed / OperativeLifeConfig.ReviveDurationSeconds, 0, 1)
end

local function result(
	didTransition: boolean,
	reasonId: ReviveRejectionReasonId?,
	progress: number,
	sessionState: any,
	targetSnapshot: any
): ReviveTransitionResult
	return {
		didTransition = didTransition,
		rejectionReasonId = reasonId,
		normalizedProgress = math.clamp(progress, 0, 1),
		sessionStateAfter = if sessionState == nil then nil else deepCopy(sessionState),
		targetSnapshotAfter = deepCopy(targetSnapshot),
	} :: any
end

local function rejected(
	reasonId: ReviveRejectionReasonId,
	sessionState: any,
	targetSnapshot: any,
	serverTimestamp: unknown
): ReviveTransitionResult
	return result(false, reasonId, copiedProgress(sessionState, serverTimestamp), sessionState, targetSnapshot)
end

local function interrupted(
	reasonId: ReviveRejectionReasonId,
	sessionState: any,
	targetSnapshot: any
): ReviveTransitionResult
	local sessionAfter = deepCopy(sessionState)
	sessionAfter.statusId = statusIds.Cancelled
	return result(true, reasonId, 0, sessionAfter, targetSnapshot)
end

function Resolver.beginRevive(
	reviverSnapshot: OperativeLifeStateSnapshot,
	targetSnapshot: OperativeLifeStateSnapshot,
	authorityFacts: ReviveBeginAuthorityFacts
): ReviveTransitionResult
	local reviver = reviverSnapshot :: any
	local target = targetSnapshot :: any
	local facts = authorityFacts :: any

	if not isValidBeginInput(reviver, target, facts) then
		return rejected(
			reasons.InvalidReviveInput,
			nil,
			target,
			if type(facts) == "table" then facts.serverTimestamp else nil
		)
	end
	if not isFiniteNumber(facts.serverTimestamp) or facts.serverTimestamp < 0 then
		return rejected(reasons.InvalidServerTimestamp, nil, target, facts.serverTimestamp)
	end
	if facts.reviverOperativeEntityId == facts.targetOperativeEntityId then
		return rejected(reasons.SameOperative, nil, target, facts.serverTimestamp)
	end
	if reviver.lifeStateId ~= lifeStateIds.Alive then
		return rejected(reasons.ReviverNotAlive, nil, target, facts.serverTimestamp)
	end
	if target.lifeStateId ~= lifeStateIds.Incapacitated then
		return rejected(reasons.TargetNotIncapacitated, nil, target, facts.serverTimestamp)
	end
	if facts.activeSessionIdForTarget ~= nil or facts.hasConflictingActiveSession then
		return rejected(reasons.TargetBusy, nil, target, facts.serverTimestamp)
	end
	if
		not isFiniteNumber(facts.distanceStuds)
		or facts.distanceStuds < 0
		or facts.distanceStuds > OperativeLifeConfig.ReviveRangeStuds
	then
		return rejected(reasons.OutOfRange, nil, target, facts.serverTimestamp)
	end
	if not facts.hasLineOfSight then
		return rejected(reasons.NoLineOfSight, nil, target, facts.serverTimestamp)
	end

	local sessionState: ReviveSessionState = {
		sessionId = facts.sessionId,
		reviverOperativeEntityId = facts.reviverOperativeEntityId,
		targetOperativeEntityId = facts.targetOperativeEntityId,
		statusId = statusIds.Active,
		startedAtServerTimestamp = facts.serverTimestamp,
		completionServerTimestamp = facts.serverTimestamp + OperativeLifeConfig.ReviveDurationSeconds,
	}
	return result(true, nil, 0, sessionState, target)
end

function Resolver.continueRevive(
	reviverSnapshot: OperativeLifeStateSnapshot,
	targetSnapshot: OperativeLifeStateSnapshot,
	sessionState: ReviveSessionState,
	authorityFacts: ReviveContinuationAuthorityFacts
): ReviveTransitionResult
	local reviver = reviverSnapshot :: any
	local target = targetSnapshot :: any
	local session = sessionState :: any
	local facts = authorityFacts :: any
	local timestamp = if type(facts) == "table" then facts.serverTimestamp else nil

	if not isValidContinuationInput(reviver, target, session, facts) then
		return rejected(reasons.InvalidReviveInput, session, target, timestamp)
	end
	if not isFiniteNumber(timestamp) or timestamp < 0 then
		return rejected(reasons.InvalidServerTimestamp, session, target, timestamp)
	end
	if session.statusId ~= statusIds.Active then
		return rejected(reasons.SessionNotActive, session, target, timestamp)
	end
	if
		facts.sessionId ~= session.sessionId
		or facts.reviverOperativeEntityId ~= session.reviverOperativeEntityId
		or facts.targetOperativeEntityId ~= session.targetOperativeEntityId
		or reviver.operativeEntityId ~= session.reviverOperativeEntityId
		or target.operativeEntityId ~= session.targetOperativeEntityId
		or facts.activeSessionIdForTarget ~= session.sessionId
		or facts.hasConflictingActiveSession
	then
		return interrupted(reasons.ReviveInterrupted, session, target)
	end
	if reviver.lifeStateId ~= lifeStateIds.Alive then
		return interrupted(reasons.ReviverNotAlive, session, target)
	end
	if target.lifeStateId ~= lifeStateIds.Incapacitated then
		return interrupted(reasons.TargetNotIncapacitated, session, target)
	end
	if not facts.holdRemainsActive then
		return interrupted(reasons.ReviveInterrupted, session, target)
	end
	if
		not isFiniteNumber(facts.distanceStuds)
		or facts.distanceStuds < 0
		or facts.distanceStuds > OperativeLifeConfig.ReviveRangeStuds
	then
		return interrupted(reasons.OutOfRange, session, target)
	end
	if not facts.hasLineOfSight then
		return interrupted(reasons.NoLineOfSight, session, target)
	end
	if timestamp < session.startedAtServerTimestamp then
		return rejected(reasons.InvalidServerTimestamp, session, target, timestamp)
	end
	if timestamp < session.completionServerTimestamp then
		return rejected(reasons.ReviveNotComplete, session, target, timestamp)
	end

	local sessionAfter = deepCopy(session) :: ReviveSessionState
	sessionAfter.statusId = statusIds.Completed
	sessionAfter.completionServerTimestamp = timestamp

	local targetAfter = deepCopy(target) :: OperativeLifeStateSnapshot
	targetAfter.lifeStateId = lifeStateIds.Alive
	targetAfter.healthState.currentHealth = OperativeLifeConfig.ReviveHealth
	targetAfter.incapacitationState = nil
	targetAfter.soloRecoveryState.recoveryStartedAtServerTimestamp = nil
	targetAfter.soloRecoveryState.recoveryCompletionServerTimestamp = nil

	return result(true, nil, 1, sessionAfter, targetAfter)
end

return table.freeze(Resolver)
