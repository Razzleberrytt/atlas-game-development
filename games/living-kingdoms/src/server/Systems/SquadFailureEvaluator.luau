--!strict

--[[
	Pure squad viability and failure-grace evaluation. Every fact and timestamp
	is supplied by a server owner; this module reads no Roblox instances, clocks,
	remotes, or mutable runtime state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeLifeConfig = require(ReplicatedStorage.Shared.Config.OperativeLifeConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)

type SquadFailureEvaluationResult = OperativeLifeContracts.SquadFailureEvaluationResult
type SquadFailureFacts = OperativeLifeContracts.SquadFailureFacts
type SquadFailureState = OperativeLifeContracts.SquadFailureState

type ViabilityResult = {
	isValid: boolean,
	rejectionReasonId: string?,
	isViable: boolean?,
	hasAliveOperative: boolean?,
	hasPendingSoloRecovery: boolean?,
	activeOperativeCount: number?,
}

type SquadFailureEvaluator = {
	evaluateViability: (facts: SquadFailureFacts, serverTimestamp: number) -> ViabilityResult,
	resolve: (
		state: SquadFailureState,
		facts: SquadFailureFacts,
		serverTimestamp: number
	) -> SquadFailureEvaluationResult,
}

local Evaluator: SquadFailureEvaluator = {} :: SquadFailureEvaluator
local lifeStateIds = OperativeLifeContracts.OperativeLifeStateIds
local statusIds = OperativeLifeContracts.SquadFailureStatusIds
local reasons = OperativeLifeContracts.SquadFailureRejectionReasonIds

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function copyState(state: any): SquadFailureState
	return {
		statusId = state.statusId,
		pendingStartedAtServerTimestamp = state.pendingStartedAtServerTimestamp,
		pendingDeadlineServerTimestamp = state.pendingDeadlineServerTimestamp,
		failedAtServerTimestamp = state.failedAtServerTimestamp,
	}
end

local function fallbackState(): SquadFailureState
	return {
		statusId = statusIds.Viable,
		pendingStartedAtServerTimestamp = nil,
		pendingDeadlineServerTimestamp = nil,
		failedAtServerTimestamp = nil,
	}
end

local function isValidRecoveryState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local recovery = value :: any
	if type(recovery.isEligible) ~= "boolean" then
		return false
	end
	if
		not isFiniteNonnegative(recovery.recoveriesUsed)
		or recovery.recoveriesUsed % 1 ~= 0
		or recovery.recoveriesUsed > OperativeLifeConfig.SoloRecoveriesPerOperation
	then
		return false
	end
	local startedAt = recovery.recoveryStartedAtServerTimestamp
	local completionAt = recovery.recoveryCompletionServerTimestamp
	return (startedAt == nil and completionAt == nil)
		or (isFiniteNonnegative(startedAt) and isFiniteNonnegative(completionAt) and completionAt >= startedAt)
end

local function isValidSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: any
	if
		not isNonEmptyString(snapshot.operativeEntityId)
		or not isValidRecoveryState(snapshot.soloRecoveryState)
		or type(snapshot.healthState) ~= "table"
	then
		return false
	end
	local health = snapshot.healthState
	if
		not isFiniteNonnegative(health.currentHealth)
		or not isFiniteNonnegative(health.maximumHealth)
		or health.maximumHealth <= 0
		or health.currentHealth > health.maximumHealth
	then
		return false
	end
	if snapshot.lifeStateId == lifeStateIds.Alive then
		return health.currentHealth > 0 and snapshot.incapacitationState == nil
	end
	if snapshot.lifeStateId == lifeStateIds.Dead then
		return health.currentHealth == 0 and snapshot.incapacitationState == nil
	end
	if snapshot.lifeStateId ~= lifeStateIds.Incapacitated or health.currentHealth ~= 0 then
		return false
	end
	local incapacitation = snapshot.incapacitationState
	return type(incapacitation) == "table"
		and isFiniteNonnegative(incapacitation.startedAtServerTimestamp)
		and isFiniteNonnegative(incapacitation.bleedOutDeadlineServerTimestamp)
		and incapacitation.bleedOutDeadlineServerTimestamp >= incapacitation.startedAtServerTimestamp
end

local function isValidFacts(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local facts = value :: any
	if
		type(facts.operativeSnapshots) ~= "table"
		or type(facts.operationStartedSolo) ~= "boolean"
		or type(facts.hasEverHadMultipleParticipants) ~= "boolean"
		or type(facts.lateJoiningProhibited) ~= "boolean"
		or type(facts.isAuthoritativelyAbandoned) ~= "boolean"
	then
		return false
	end
	local identities = {}
	local snapshotCount = 0
	for index, snapshot in facts.operativeSnapshots do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or not isValidSnapshot(snapshot) then
			return false
		end
		snapshotCount += 1
		local identity = snapshot.operativeEntityId
		if identities[identity] then
			return false
		end
		identities[identity] = true
	end
	for index = 1, snapshotCount do
		if facts.operativeSnapshots[index] == nil then
			return false
		end
	end
	return true
end

local function isValidState(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local state = value :: any
	local startedAt = state.pendingStartedAtServerTimestamp
	local deadline = state.pendingDeadlineServerTimestamp
	local failedAt = state.failedAtServerTimestamp
	if state.statusId == statusIds.Viable then
		return startedAt == nil and deadline == nil and failedAt == nil
	end
	if state.statusId == statusIds.Pending then
		return isFiniteNonnegative(startedAt)
			and isFiniteNonnegative(deadline)
			and deadline == startedAt + OperativeLifeConfig.SquadFailureGraceSeconds
			and failedAt == nil
	end
	return state.statusId == statusIds.Failed and startedAt == nil and deadline == nil and isFiniteNonnegative(failedAt)
end

local function rejected(state: unknown, reasonId: string): SquadFailureEvaluationResult
	return {
		didResolve = false,
		rejectionReasonId = reasonId,
		isViable = nil,
		hasAliveOperative = nil,
		hasPendingSoloRecovery = nil,
		activeOperativeCount = nil,
		stateAfter = if isValidState(state) then copyState(state) else fallbackState(),
	} :: any
end

function Evaluator.evaluateViability(facts: SquadFailureFacts, serverTimestamp: number): ViabilityResult
	if not isFiniteNonnegative(serverTimestamp) then
		return { isValid = false, rejectionReasonId = reasons.InvalidServerTimestamp }
	end
	if not isValidFacts(facts) then
		return { isValid = false, rejectionReasonId = reasons.InvalidFacts }
	end

	local snapshots = facts.operativeSnapshots
	local hasAlive = false
	for _, snapshot in snapshots do
		if snapshot.lifeStateId == lifeStateIds.Alive then
			hasAlive = true
			break
		end
	end

	local hasPendingSoloRecovery = false
	if #snapshots == 1 and not facts.isAuthoritativelyAbandoned then
		local snapshot = snapshots[1]
		local recovery = snapshot.soloRecoveryState
		local incapacitation = snapshot.incapacitationState
		local startedAt = recovery.recoveryStartedAtServerTimestamp
		local completionAt = recovery.recoveryCompletionServerTimestamp
		hasPendingSoloRecovery = snapshot.lifeStateId == lifeStateIds.Incapacitated
			and facts.operationStartedSolo
			and not facts.hasEverHadMultipleParticipants
			and recovery.isEligible
			and recovery.recoveriesUsed < OperativeLifeConfig.SoloRecoveriesPerOperation
			and incapacitation ~= nil
			and isFiniteNonnegative(startedAt)
			and isFiniteNonnegative(completionAt)
			and startedAt == incapacitation.startedAtServerTimestamp
			and completionAt == startedAt + OperativeLifeConfig.SoloRecoveryDurationSeconds
			and serverTimestamp >= startedAt
			and serverTimestamp <= completionAt
	end

	local isViable = not facts.isAuthoritativelyAbandoned and (hasAlive or hasPendingSoloRecovery)
	return {
		isValid = true,
		rejectionReasonId = nil,
		isViable = isViable,
		hasAliveOperative = hasAlive,
		hasPendingSoloRecovery = hasPendingSoloRecovery,
		activeOperativeCount = #snapshots,
	}
end

function Evaluator.resolve(
	state: SquadFailureState,
	facts: SquadFailureFacts,
	serverTimestamp: number
): SquadFailureEvaluationResult
	if not isFiniteNonnegative(serverTimestamp) then
		return rejected(state, reasons.InvalidServerTimestamp)
	end
	if not isValidState(state) then
		return rejected(state, reasons.InvalidState)
	end
	local relevantTimestamp = if state.statusId == statusIds.Pending
		then state.pendingStartedAtServerTimestamp
		elseif state.statusId == statusIds.Failed then state.failedAtServerTimestamp
		else nil
	if relevantTimestamp ~= nil and serverTimestamp < relevantTimestamp then
		return rejected(state, reasons.StaleEvaluation)
	end
	local viability = Evaluator.evaluateViability(facts, serverTimestamp)
	if not viability.isValid then
		return rejected(state, viability.rejectionReasonId :: string)
	end

	local stateAfter: SquadFailureState = copyState(state)
	if state.statusId ~= statusIds.Failed then
		if
			state.statusId == statusIds.Pending
			and serverTimestamp >= (state.pendingDeadlineServerTimestamp :: number)
		then
			stateAfter = {
				statusId = statusIds.Failed,
				pendingStartedAtServerTimestamp = nil,
				pendingDeadlineServerTimestamp = nil,
				failedAtServerTimestamp = serverTimestamp,
			}
		elseif viability.isViable then
			stateAfter = fallbackState()
		elseif state.statusId == statusIds.Viable then
			stateAfter = {
				statusId = statusIds.Pending,
				pendingStartedAtServerTimestamp = serverTimestamp,
				pendingDeadlineServerTimestamp = serverTimestamp + OperativeLifeConfig.SquadFailureGraceSeconds,
				failedAtServerTimestamp = nil,
			}
		end
	end

	return {
		didResolve = true,
		rejectionReasonId = nil,
		isViable = viability.isViable,
		hasAliveOperative = viability.hasAliveOperative,
		hasPendingSoloRecovery = viability.hasPendingSoloRecovery,
		activeOperativeCount = viability.activeOperativeCount,
		stateAfter = stateAfter,
	}
end

return table.freeze(Evaluator)
