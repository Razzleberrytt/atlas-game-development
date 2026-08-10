--!strict

--[[
	Applies one server-owned damage event to one canonical operative snapshot.
	This pure resolver cannot prove provenance: callers must construct every input
	from authoritative server state and atomically commit snapshotAfter before
	processing another event. The processed-event set is caller-owned; this module
	has no hidden state, cleanup policy, persistence, or runtime lifetime owner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeLifeConfig = require(ReplicatedStorage.Shared.Config.OperativeLifeConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)

type AuthoritativeOperativeDamage = OperativeLifeContracts.AuthoritativeOperativeDamage
type OperativeLifeStateId = OperativeLifeContracts.OperativeLifeStateId
type OperativeLifeStateSnapshot = OperativeLifeContracts.OperativeLifeStateSnapshot
type OperativeLifeTransitionRejectionReasonId = OperativeLifeContracts.OperativeLifeTransitionRejectionReasonId
type OperativeLifeTransitionResult = OperativeLifeContracts.OperativeLifeTransitionResult

type OperativeHealthResolver = {
	resolveDamage: (
		operativeSnapshot: OperativeLifeStateSnapshot,
		authoritativeDamage: AuthoritativeOperativeDamage,
		serverTimestamp: number
	) -> OperativeLifeTransitionResult,
}

local OperativeHealthResolver: OperativeHealthResolver = {} :: OperativeHealthResolver
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

local function validateSnapshotStructure(operativeSnapshot: any): boolean
	if type(operativeSnapshot) ~= "table" then
		return false
	end
	if not isNonEmptyString(operativeSnapshot.operativeEntityId) then
		return false
	end
	if not isKnownLifeStateId(operativeSnapshot.lifeStateId) then
		return false
	end
	if type(operativeSnapshot.healthState) ~= "table" then
		return false
	end
	if not isValidSoloRecoveryState(operativeSnapshot.soloRecoveryState) then
		return false
	end
	if not isValidProcessedDamageEventIds(operativeSnapshot.processedDamageEventIds) then
		return false
	end

	if operativeSnapshot.lifeStateId == lifeStateIds.Alive then
		return operativeSnapshot.incapacitationState == nil
	end
	if operativeSnapshot.lifeStateId == lifeStateIds.Incapacitated then
		return isValidIncapacitationState(operativeSnapshot.incapacitationState)
	end
	return operativeSnapshot.incapacitationState == nil
		or isValidIncapacitationState(operativeSnapshot.incapacitationState)
end

local function validateHealth(operativeSnapshot: any): boolean
	local healthState = operativeSnapshot.healthState
	local currentHealth = healthState.currentHealth
	local maximumHealth = healthState.maximumHealth
	if not isFiniteNumber(currentHealth) or not isFiniteNumber(maximumHealth) then
		return false
	end
	if maximumHealth < OperativeLifeConfig.MaximumHealth or maximumHealth > OperativeLifeConfig.MaximumHealth * 2 then
		return false
	end
	if currentHealth < 0 or currentHealth > maximumHealth then
		return false
	end
	if operativeSnapshot.lifeStateId == lifeStateIds.Alive then
		return currentHealth > 0
	end
	return currentHealth == 0
end

local function validateDamage(operativeSnapshot: any, authoritativeDamage: any): boolean
	if type(authoritativeDamage) ~= "table" then
		return false
	end
	if not isNonEmptyString(authoritativeDamage.damageEventId) then
		return false
	end
	if authoritativeDamage.sourceEntityId ~= nil and not isNonEmptyString(authoritativeDamage.sourceEntityId) then
		return false
	end
	if
		not isNonEmptyString(authoritativeDamage.targetEntityId)
		or authoritativeDamage.targetEntityId ~= operativeSnapshot.operativeEntityId
	then
		return false
	end
	return isFiniteNumber(authoritativeDamage.damageAmount) and authoritativeDamage.damageAmount > 0
end

local function validateServerTimestamp(authoritativeDamage: any, serverTimestamp: unknown): boolean
	if not isFiniteNumber(serverTimestamp) or (serverTimestamp :: number) < 0 then
		return false
	end
	if
		not isFiniteNumber(authoritativeDamage.serverTimestamp)
		or authoritativeDamage.serverTimestamp < 0
		or authoritativeDamage.serverTimestamp ~= serverTimestamp
	then
		return false
	end
	return true
end

local function rejected(
	operativeSnapshot: any,
	reasonId: OperativeLifeTransitionRejectionReasonId
): OperativeLifeTransitionResult
	return {
		didTransition = false,
		rejectionReasonId = reasonId,
		lifeStateIdBefore = nil,
		lifeStateIdAfter = nil,
		transitionServerTimestamp = nil,
		damageEventId = nil,
		snapshotAfter = deepCopy(operativeSnapshot),
	} :: any
end

function OperativeHealthResolver.resolveDamage(
	operativeSnapshot: OperativeLifeStateSnapshot,
	authoritativeDamage: AuthoritativeOperativeDamage,
	serverTimestamp: number
): OperativeLifeTransitionResult
	local untypedSnapshot = operativeSnapshot :: any
	local untypedDamage = authoritativeDamage :: any

	-- Stable first-failure order: snapshot, health, damage, server time,
	-- transition legality, then committed duplicate identity.
	if not validateSnapshotStructure(untypedSnapshot) then
		return rejected(untypedSnapshot, reasons.InvalidSnapshot)
	end
	if not validateHealth(untypedSnapshot) then
		return rejected(untypedSnapshot, reasons.InvalidHealth)
	end
	if not validateDamage(untypedSnapshot, untypedDamage) then
		return rejected(untypedSnapshot, reasons.InvalidDamage)
	end
	if not validateServerTimestamp(untypedDamage, serverTimestamp) then
		return rejected(untypedSnapshot, reasons.InvalidServerTimestamp)
	end
	if untypedSnapshot.lifeStateId ~= lifeStateIds.Alive then
		return rejected(untypedSnapshot, reasons.IllegalTransition)
	end
	if untypedSnapshot.processedDamageEventIds[untypedDamage.damageEventId] == true then
		return rejected(untypedSnapshot, reasons.AlreadyResolved)
	end

	local snapshotAfter = deepCopy(untypedSnapshot) :: OperativeLifeStateSnapshot
	snapshotAfter.processedDamageEventIds[untypedDamage.damageEventId] = true
	local healthAfter = math.max(
		0,
		math.min(
			snapshotAfter.healthState.maximumHealth,
			snapshotAfter.healthState.currentHealth - untypedDamage.damageAmount
		)
	)
	snapshotAfter.healthState.currentHealth = healthAfter

	if healthAfter == 0 then
		snapshotAfter.lifeStateId = lifeStateIds.Incapacitated
		snapshotAfter.incapacitationState = {
			startedAtServerTimestamp = serverTimestamp,
			bleedOutDeadlineServerTimestamp = serverTimestamp + OperativeLifeConfig.BleedOutDurationSeconds,
		}
	end

	return {
		didTransition = true,
		rejectionReasonId = nil,
		lifeStateIdBefore = lifeStateIds.Alive,
		lifeStateIdAfter = snapshotAfter.lifeStateId,
		transitionServerTimestamp = serverTimestamp,
		damageEventId = untypedDamage.damageEventId,
		snapshotAfter = snapshotAfter,
	}
end

return table.freeze(OperativeHealthResolver)
