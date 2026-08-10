--!strict

--[[
	Pure server-domain transitions for an operative that is already
	Incapacitated. Callers own authoritative time, operation-participation
	facts, scheduling, and atomic persistence of the returned snapshot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeLifeConfig = require(ReplicatedStorage.Shared.Config.OperativeLifeConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)

type AuthoritativeOperativeDamage = OperativeLifeContracts.AuthoritativeOperativeDamage
type OperationParticipationFacts = OperativeLifeContracts.OperationParticipationFacts
type OperativeLifeStateId = OperativeLifeContracts.OperativeLifeStateId
type OperativeLifeStateSnapshot = OperativeLifeContracts.OperativeLifeStateSnapshot
type RejectionReasonId = OperativeLifeContracts.OperativeLifeTransitionRejectionReasonId
type TransitionResult = OperativeLifeContracts.OperativeLifeTransitionResult

type OperativeIncapacitationResolver = {
	evaluateBleedOut: (operativeSnapshot: OperativeLifeStateSnapshot, serverTimestamp: number) -> TransitionResult,
	resolveFinishingDamage: (
		operativeSnapshot: OperativeLifeStateSnapshot,
		authoritativeDamage: AuthoritativeOperativeDamage,
		serverTimestamp: number
	) -> TransitionResult,
	evaluateSoloRecovery: (
		operativeSnapshot: OperativeLifeStateSnapshot,
		operationParticipation: OperationParticipationFacts,
		serverTimestamp: number
	) -> TransitionResult,
}

local Resolver: OperativeIncapacitationResolver = {} :: OperativeIncapacitationResolver
local lifeStateIds = OperativeLifeContracts.OperativeLifeStateIds
local reasons = OperativeLifeContracts.OperativeLifeTransitionRejectionReasonIds

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
	if not isFiniteNumber(startedAt) or not isFiniteNumber(completionAt) then
		return false
	end
	return (completionAt :: number) >= (startedAt :: number)
end

local function isValidSoloRecoveryState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end

	local state = value :: any
	if type(state.isEligible) ~= "boolean" then
		return false
	end
	if
		type(state.recoveriesUsed) ~= "number"
		or not isFiniteNumber(state.recoveriesUsed)
		or state.recoveriesUsed % 1 ~= 0
		or state.recoveriesUsed < 0
		or state.recoveriesUsed > OperativeLifeConfig.SoloRecoveriesPerOperation
	then
		return false
	end
	return hasValidTimestampPair(state.recoveryStartedAtServerTimestamp, state.recoveryCompletionServerTimestamp)
end

local function isValidIncapacitationState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end

	local state = value :: any
	if
		not isFiniteNumber(state.startedAtServerTimestamp)
		or not isFiniteNumber(state.bleedOutDeadlineServerTimestamp)
	then
		return false
	end
	return state.bleedOutDeadlineServerTimestamp
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

local function validateSnapshotStructure(snapshot: any): boolean
	if type(snapshot) ~= "table" or not isNonEmptyString(snapshot.operativeEntityId) then
		return false
	end
	if not isKnownLifeStateId(snapshot.lifeStateId) or type(snapshot.healthState) ~= "table" then
		return false
	end
	if not isValidSoloRecoveryState(snapshot.soloRecoveryState) then
		return false
	end
	if not isValidProcessedDamageEventIds(snapshot.processedDamageEventIds) then
		return false
	end

	if snapshot.lifeStateId == lifeStateIds.Alive then
		return snapshot.incapacitationState == nil
	end
	if snapshot.lifeStateId == lifeStateIds.Incapacitated then
		return isValidIncapacitationState(snapshot.incapacitationState)
	end
	return snapshot.incapacitationState == nil or isValidIncapacitationState(snapshot.incapacitationState)
end

local function validateHealth(snapshot: any): boolean
	local healthState = snapshot.healthState
	local currentHealth = healthState.currentHealth
	local maximumHealth = healthState.maximumHealth
	if not isFiniteNumber(currentHealth) or not isFiniteNumber(maximumHealth) then
		return false
	end
	if maximumHealth <= 0 then
		return false
	end
	if currentHealth < 0 or currentHealth > maximumHealth then
		return false
	end
	if snapshot.lifeStateId == lifeStateIds.Alive then
		return currentHealth > 0
	end
	return currentHealth == 0
end

local function validateDamage(snapshot: any, damage: any): boolean
	if type(damage) ~= "table" or not isNonEmptyString(damage.damageEventId) then
		return false
	end
	if damage.sourceEntityId ~= nil and not isNonEmptyString(damage.sourceEntityId) then
		return false
	end
	if not isNonEmptyString(damage.targetEntityId) or damage.targetEntityId ~= snapshot.operativeEntityId then
		return false
	end
	return isFiniteNumber(damage.damageAmount) and damage.damageAmount > 0
end

local function validateDamageTimestamp(damage: any, serverTimestamp: unknown): boolean
	return isFiniteNumber(serverTimestamp)
		and (serverTimestamp :: number) >= 0
		and isFiniteNumber(damage.serverTimestamp)
		and damage.serverTimestamp >= 0
		and damage.serverTimestamp == serverTimestamp
end

local function validateServerTimestamp(serverTimestamp: unknown): boolean
	return isFiniteNumber(serverTimestamp) and (serverTimestamp :: number) >= 0
end

local function validateParticipationFacts(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local facts = value :: any
	return type(facts.operationStartedSolo) == "boolean" and type(facts.hasEverHadMultipleParticipants) == "boolean"
end

local function rejected(snapshot: any, reasonId: RejectionReasonId): TransitionResult
	return {
		didTransition = false,
		rejectionReasonId = reasonId,
		lifeStateIdBefore = nil,
		lifeStateIdAfter = nil,
		transitionServerTimestamp = nil,
		damageEventId = nil,
		snapshotAfter = deepCopy(snapshot),
	} :: any
end

local function acceptedDead(snapshot: any, serverTimestamp: number, damageEventId: string?): TransitionResult
	local snapshotAfter = deepCopy(snapshot) :: OperativeLifeStateSnapshot
	snapshotAfter.lifeStateId = lifeStateIds.Dead
	snapshotAfter.healthState.currentHealth = 0
	snapshotAfter.incapacitationState = nil
	snapshotAfter.soloRecoveryState.isEligible = false
	snapshotAfter.soloRecoveryState.recoveryStartedAtServerTimestamp = nil
	snapshotAfter.soloRecoveryState.recoveryCompletionServerTimestamp = nil
	if damageEventId ~= nil then
		snapshotAfter.processedDamageEventIds[damageEventId] = true
	end

	return {
		didTransition = true,
		rejectionReasonId = nil,
		lifeStateIdBefore = lifeStateIds.Incapacitated,
		lifeStateIdAfter = lifeStateIds.Dead,
		transitionServerTimestamp = serverTimestamp,
		damageEventId = damageEventId,
		snapshotAfter = snapshotAfter,
	}
end

function Resolver.evaluateBleedOut(snapshot: OperativeLifeStateSnapshot, serverTimestamp: number): TransitionResult
	local untypedSnapshot = snapshot :: any

	-- Stable first-failure order: snapshot, health, server time, required life
	-- state, stale authoritative time, then deadline readiness.
	if not validateSnapshotStructure(untypedSnapshot) then
		return rejected(untypedSnapshot, reasons.InvalidSnapshot)
	end
	if not validateHealth(untypedSnapshot) then
		return rejected(untypedSnapshot, reasons.InvalidHealth)
	end
	if not validateServerTimestamp(serverTimestamp) then
		return rejected(untypedSnapshot, reasons.InvalidServerTimestamp)
	end
	if untypedSnapshot.lifeStateId == lifeStateIds.Dead then
		return rejected(untypedSnapshot, reasons.AlreadyResolved)
	end
	if untypedSnapshot.lifeStateId ~= lifeStateIds.Incapacitated then
		return rejected(untypedSnapshot, reasons.IllegalTransition)
	end
	local incapacitation = untypedSnapshot.incapacitationState
	if serverTimestamp < incapacitation.startedAtServerTimestamp then
		return rejected(untypedSnapshot, reasons.StaleTransition)
	end
	if serverTimestamp < incapacitation.bleedOutDeadlineServerTimestamp then
		return rejected(untypedSnapshot, reasons.TransitionNotReady)
	end

	return acceptedDead(untypedSnapshot, serverTimestamp, nil)
end

function Resolver.resolveFinishingDamage(
	snapshot: OperativeLifeStateSnapshot,
	damage: AuthoritativeOperativeDamage,
	serverTimestamp: number
): TransitionResult
	local untypedSnapshot = snapshot :: any
	local untypedDamage = damage :: any

	-- Stable first-failure order: snapshot, health, damage, server time,
	-- required life state, duplicate identity, then stale authoritative time.
	if not validateSnapshotStructure(untypedSnapshot) then
		return rejected(untypedSnapshot, reasons.InvalidSnapshot)
	end
	if not validateHealth(untypedSnapshot) then
		return rejected(untypedSnapshot, reasons.InvalidHealth)
	end
	if not validateDamage(untypedSnapshot, untypedDamage) then
		return rejected(untypedSnapshot, reasons.InvalidDamage)
	end
	if not validateDamageTimestamp(untypedDamage, serverTimestamp) then
		return rejected(untypedSnapshot, reasons.InvalidServerTimestamp)
	end
	if untypedSnapshot.lifeStateId == lifeStateIds.Dead then
		return rejected(untypedSnapshot, reasons.AlreadyResolved)
	end
	if untypedSnapshot.lifeStateId ~= lifeStateIds.Incapacitated then
		return rejected(untypedSnapshot, reasons.IllegalTransition)
	end
	if untypedSnapshot.processedDamageEventIds[untypedDamage.damageEventId] == true then
		return rejected(untypedSnapshot, reasons.AlreadyResolved)
	end
	if serverTimestamp < untypedSnapshot.incapacitationState.startedAtServerTimestamp then
		return rejected(untypedSnapshot, reasons.StaleTransition)
	end

	return acceptedDead(untypedSnapshot, serverTimestamp, untypedDamage.damageEventId)
end

function Resolver.evaluateSoloRecovery(
	snapshot: OperativeLifeStateSnapshot,
	operationParticipation: OperationParticipationFacts,
	serverTimestamp: number
): TransitionResult
	local untypedSnapshot = snapshot :: any
	local participation = operationParticipation :: any

	-- Stable first-failure order: snapshot, health, participation facts, server
	-- time, required life state, exhausted allowance, eligibility/history,
	-- canonical recovery timing, stale authoritative time, then completion readiness.
	if not validateSnapshotStructure(untypedSnapshot) then
		return rejected(untypedSnapshot, reasons.InvalidSnapshot)
	end
	if not validateHealth(untypedSnapshot) then
		return rejected(untypedSnapshot, reasons.InvalidHealth)
	end
	if not validateParticipationFacts(participation) then
		return rejected(untypedSnapshot, reasons.InvalidSnapshot)
	end
	if not validateServerTimestamp(serverTimestamp) then
		return rejected(untypedSnapshot, reasons.InvalidServerTimestamp)
	end
	if untypedSnapshot.lifeStateId ~= lifeStateIds.Incapacitated then
		return rejected(untypedSnapshot, reasons.AlreadyResolved)
	end

	local incapacitation = untypedSnapshot.incapacitationState
	local recovery = untypedSnapshot.soloRecoveryState
	if recovery.recoveriesUsed >= OperativeLifeConfig.SoloRecoveriesPerOperation then
		return rejected(untypedSnapshot, reasons.AlreadyResolved)
	end
	if
		not recovery.isEligible
		or not participation.operationStartedSolo
		or participation.hasEverHadMultipleParticipants
	then
		return rejected(untypedSnapshot, reasons.IllegalTransition)
	end
	if
		not isFiniteNumber(recovery.recoveryStartedAtServerTimestamp)
		or not isFiniteNumber(recovery.recoveryCompletionServerTimestamp)
		or recovery.recoveryStartedAtServerTimestamp ~= incapacitation.startedAtServerTimestamp
		or recovery.recoveryCompletionServerTimestamp
			~= recovery.recoveryStartedAtServerTimestamp + OperativeLifeConfig.SoloRecoveryDurationSeconds
	then
		return rejected(untypedSnapshot, reasons.InvalidSnapshot)
	end
	if serverTimestamp < recovery.recoveryStartedAtServerTimestamp then
		return rejected(untypedSnapshot, reasons.StaleTransition)
	end
	if serverTimestamp < recovery.recoveryCompletionServerTimestamp then
		return rejected(untypedSnapshot, reasons.TransitionNotReady)
	end

	local snapshotAfter = deepCopy(untypedSnapshot) :: OperativeLifeStateSnapshot
	snapshotAfter.lifeStateId = lifeStateIds.Alive
	snapshotAfter.healthState.currentHealth = OperativeLifeConfig.ReviveHealth
	snapshotAfter.incapacitationState = nil
	snapshotAfter.soloRecoveryState.isEligible = false
	snapshotAfter.soloRecoveryState.recoveriesUsed += 1
	snapshotAfter.soloRecoveryState.recoveryStartedAtServerTimestamp = nil
	snapshotAfter.soloRecoveryState.recoveryCompletionServerTimestamp = nil

	return {
		didTransition = true,
		rejectionReasonId = nil,
		lifeStateIdBefore = lifeStateIds.Incapacitated,
		lifeStateIdAfter = lifeStateIds.Alive,
		transitionServerTimestamp = serverTimestamp,
		damageEventId = nil,
		snapshotAfter = snapshotAfter,
	}
end

return table.freeze(Resolver)
