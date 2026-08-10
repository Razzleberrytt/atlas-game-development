--!strict

--[[
	Pure P7-0104 Field Treatment lifecycle. The runtime derives every identity,
	life, resource, position, damage, visibility, timing, and optional cooldown-
	duration fact. A completed channel only requests a heal; the life owner still
	decides and commits it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)

local ActionIds = ClassContracts.ClassActionIds
local ActionStateIds = ClassContracts.ClassActionStateIds
local ClassIds = ClassContracts.ClassIds
local PhaseIds = ClassContracts.ClassActionPhaseIds
local ReasonIds = ClassContracts.ClassActionRejectionReasonIds

export type StartFacts = {
	isParticipant: boolean,
	isOperationActive: boolean,
	assignedClassId: string,
	isActorAlive: boolean,
	resourceAmount: number,
	isTargetKnown: boolean,
	isSelfTarget: boolean,
	isTargetAlive: boolean,
	isTargetInjured: boolean,
	distanceStuds: number,
	hasLineOfSight: boolean,
	serverTimestamp: number,
}

export type ContinuityFacts = {
	isOperationActive: boolean,
	isActorAlive: boolean,
	movementDistanceStuds: number,
	didActorTakeDamage: boolean,
	isTargetKnown: boolean,
	isTargetAlive: boolean,
	isTargetInjured: boolean,
	distanceStuds: number,
	hasLineOfSight: boolean,
	serverTimestamp: number,
}

export type Resolution = {
	didChange: boolean,
	didActivate: boolean,
	shouldCommitHealing: boolean,
	rejectionReasonId: string?,
	requestId: string?,
	actionStateAfter: ClassContracts.AuthoritativeClassActionState,
}

local Resolver = {}

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function normalizedCooldownDurationMultiplier(value: unknown): number?
	if value == nil then
		return 1
	end
	if
		type(value) ~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge
		or value <= 0
		or value > 1
	then
		return nil
	end
	return value
end

local function copyState(state: ClassContracts.AuthoritativeClassActionState)
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

local function result(didChange, didActivate, shouldCommitHealing, reasonId, requestId, state): Resolution
	return table.freeze({
		didChange = didChange,
		didActivate = didActivate,
		shouldCommitHealing = shouldCommitHealing,
		rejectionReasonId = reasonId,
		requestId = requestId,
		actionStateAfter = copyState(state),
	}) :: any
end

local function rejected(state, reasonId, requestId): Resolution
	return result(false, false, false, reasonId, requestId, state)
end

local function cooldownState(state, timestamp: number, reasonId: string, cooldownDurationMultiplier: number?)
	local multiplier = normalizedCooldownDurationMultiplier(cooldownDurationMultiplier) or 1
	return table.freeze({
		actionStateId = ActionStateIds.Cooldown,
		actionId = ActionIds.FieldTreatment,
		targetOperativeEntityId = nil,
		startedAtServerTimestamp = nil,
		completionServerTimestamp = nil,
		cooldownEndServerTimestamp = timestamp + ClassConfig.Actions.FieldTreatment.cooldownSeconds * multiplier,
		statusReasonId = reasonId,
		revision = state.revision + 1,
	})
end

local function idleState(state)
	return table.freeze({
		actionStateId = ActionStateIds.Idle,
		actionId = nil,
		targetOperativeEntityId = nil,
		startedAtServerTimestamp = nil,
		completionServerTimestamp = nil,
		cooldownEndServerTimestamp = nil,
		statusReasonId = nil,
		revision = state.revision + 1,
	})
end

local function validStartFacts(facts: unknown): boolean
	if type(facts) ~= "table" then
		return false
	end
	local value = facts :: any
	return type(value.isParticipant) == "boolean"
		and type(value.isOperationActive) == "boolean"
		and type(value.assignedClassId) == "string"
		and type(value.isActorAlive) == "boolean"
		and isFiniteNonnegative(value.resourceAmount)
		and type(value.isTargetKnown) == "boolean"
		and type(value.isSelfTarget) == "boolean"
		and type(value.isTargetAlive) == "boolean"
		and type(value.isTargetInjured) == "boolean"
		and isFiniteNonnegative(value.distanceStuds)
		and type(value.hasLineOfSight) == "boolean"
		and isFiniteNonnegative(value.serverTimestamp)
end

local function validContinuityFacts(facts: unknown): boolean
	if type(facts) ~= "table" then
		return false
	end
	local value = facts :: any
	return type(value.isOperationActive) == "boolean"
		and type(value.isActorAlive) == "boolean"
		and isFiniteNonnegative(value.movementDistanceStuds)
		and type(value.didActorTakeDamage) == "boolean"
		and type(value.isTargetKnown) == "boolean"
		and type(value.isTargetAlive) == "boolean"
		and type(value.isTargetInjured) == "boolean"
		and isFiniteNonnegative(value.distanceStuds)
		and type(value.hasLineOfSight) == "boolean"
		and isFiniteNonnegative(value.serverTimestamp)
end

function Resolver.resolveStart(currentState, rawIntent: unknown, facts: StartFacts): Resolution
	if not ClassContracts.validateAuthoritativeClassActionState(currentState) or not validStartFacts(facts) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	if not ClassContracts.validateClassActionIntent(rawIntent) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	local intent = rawIntent :: any
	local requestId = intent.requestId
	if intent.actionId ~= ActionIds.FieldTreatment then
		return rejected(currentState, ReasonIds.UnknownAction, requestId)
	end
	if intent.phaseId ~= PhaseIds.Begin or intent.candidateTargetOperativeEntityId == nil then
		return rejected(currentState, ReasonIds.InvalidIntent, requestId)
	end
	if not facts.isParticipant then
		return rejected(currentState, ReasonIds.NotParticipant, requestId)
	end
	if not facts.isOperationActive then
		return rejected(currentState, ReasonIds.OperationPhaseInvalid, requestId)
	end
	if facts.assignedClassId ~= ClassIds.Medic then
		return rejected(currentState, ReasonIds.WrongAssignedClass, requestId)
	end
	if not facts.isActorAlive then
		return rejected(currentState, ReasonIds.ActorNotAlive, requestId)
	end
	if currentState.actionStateId == ActionStateIds.Active then
		return rejected(currentState, ReasonIds.ActionAlreadyActive, requestId)
	end
	if currentState.actionStateId == ActionStateIds.Cooldown then
		return rejected(currentState, ReasonIds.ActionOnCooldown, requestId)
	end
	if facts.resourceAmount < ClassConfig.Actions.FieldTreatment.resourceCost then
		return rejected(currentState, ReasonIds.InsufficientResource, requestId)
	end
	if not facts.isTargetKnown then
		return rejected(currentState, ReasonIds.UnknownTarget, requestId)
	end
	if facts.isSelfTarget then
		return rejected(currentState, ReasonIds.SelfTargetNotAllowed, requestId)
	end
	if not facts.isTargetAlive then
		return rejected(currentState, ReasonIds.TargetNotAlive, requestId)
	end
	if not facts.isTargetInjured then
		return rejected(currentState, ReasonIds.TargetNotInjured, requestId)
	end
	if facts.distanceStuds > ClassConfig.Actions.FieldTreatment.maximumRangeStuds then
		return rejected(currentState, ReasonIds.OutOfRange, requestId)
	end
	if not facts.hasLineOfSight then
		return rejected(currentState, ReasonIds.NoLineOfSight, requestId)
	end
	return result(true, true, false, nil, requestId, {
		actionStateId = ActionStateIds.Active,
		actionId = ActionIds.FieldTreatment,
		targetOperativeEntityId = intent.candidateTargetOperativeEntityId,
		startedAtServerTimestamp = facts.serverTimestamp,
		completionServerTimestamp = facts.serverTimestamp + ClassConfig.Actions.FieldTreatment.channelDurationSeconds,
		cooldownEndServerTimestamp = nil,
		statusReasonId = nil,
		revision = currentState.revision + 1,
	})
end

function Resolver.resolveContinuity(
	currentState,
	facts: ContinuityFacts,
	cooldownDurationMultiplier: number?
): Resolution
	if
		not ClassContracts.validateAuthoritativeClassActionState(currentState)
		or not validContinuityFacts(facts)
		or normalizedCooldownDurationMultiplier(cooldownDurationMultiplier) == nil
	then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	if currentState.actionStateId == ActionStateIds.Cooldown then
		local deadline = currentState.cooldownEndServerTimestamp
		if deadline ~= nil and facts.serverTimestamp >= deadline then
			return result(true, false, false, nil, nil, idleState(currentState))
		end
		return result(false, false, false, nil, nil, currentState)
	end
	if currentState.actionStateId ~= ActionStateIds.Active or currentState.actionId ~= ActionIds.FieldTreatment then
		return result(false, false, false, nil, nil, currentState)
	end
	local reasonId = nil
	if not facts.isOperationActive then
		reasonId = ReasonIds.OperationResolved
	elseif not facts.isActorAlive then
		reasonId = ReasonIds.ActorNotAlive
	elseif facts.movementDistanceStuds > ClassConfig.Actions.FieldTreatment.movementToleranceStuds then
		reasonId = ReasonIds.MovementInterrupted
	elseif facts.didActorTakeDamage then
		reasonId = ReasonIds.DamageInterrupted
	elseif not facts.isTargetKnown then
		reasonId = ReasonIds.UnknownTarget
	elseif not facts.isTargetAlive then
		reasonId = ReasonIds.TargetNotAlive
	elseif not facts.isTargetInjured then
		reasonId = ReasonIds.TargetNotInjured
	elseif facts.distanceStuds > ClassConfig.Actions.FieldTreatment.maximumRangeStuds then
		reasonId = ReasonIds.OutOfRange
	elseif not facts.hasLineOfSight then
		reasonId = ReasonIds.NoLineOfSight
	end
	if reasonId ~= nil then
		return result(
			true,
			false,
			false,
			reasonId,
			nil,
			cooldownState(currentState, facts.serverTimestamp, reasonId, cooldownDurationMultiplier)
		)
	end
	local completion = currentState.completionServerTimestamp
	if completion ~= nil and facts.serverTimestamp >= completion then
		return result(
			true,
			false,
			true,
			ReasonIds.ActionCompleted,
			nil,
			cooldownState(currentState, facts.serverTimestamp, ReasonIds.ActionCompleted, cooldownDurationMultiplier)
		)
	end
	return result(false, false, false, nil, nil, currentState)
end

function Resolver.resolveCancel(
	currentState,
	rawIntent: unknown,
	serverTimestamp: number,
	cooldownDurationMultiplier: number?
): Resolution
	if
		not ClassContracts.validateAuthoritativeClassActionState(currentState)
		or not ClassContracts.validateClassActionIntent(rawIntent)
		or not isFiniteNonnegative(serverTimestamp)
		or normalizedCooldownDurationMultiplier(cooldownDurationMultiplier) == nil
	then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	local intent = rawIntent :: any
	if intent.actionId ~= ActionIds.FieldTreatment then
		return rejected(currentState, ReasonIds.UnknownAction, intent.requestId)
	end
	if intent.phaseId ~= PhaseIds.Cancel and intent.phaseId ~= PhaseIds.End then
		return rejected(currentState, ReasonIds.InvalidIntent, intent.requestId)
	end
	if currentState.actionStateId ~= ActionStateIds.Active or currentState.actionId ~= ActionIds.FieldTreatment then
		return rejected(currentState, ReasonIds.InvalidIntent, intent.requestId)
	end
	return result(
		true,
		false,
		false,
		ReasonIds.ActionCancelled,
		intent.requestId,
		cooldownState(currentState, serverTimestamp, ReasonIds.ActionCancelled, cooldownDurationMultiplier)
	)
end

function Resolver.resolveEffectRejected(
	currentState,
	serverTimestamp: number,
	cooldownDurationMultiplier: number?
): Resolution
	if
		not ClassContracts.validateAuthoritativeClassActionState(currentState)
		or not isFiniteNonnegative(serverTimestamp)
		or normalizedCooldownDurationMultiplier(cooldownDurationMultiplier) == nil
	then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	return result(
		true,
		false,
		false,
		ReasonIds.EffectCommitRejected,
		nil,
		cooldownState(currentState, serverTimestamp, ReasonIds.EffectCommitRejected, cooldownDurationMultiplier)
	)
end

return table.freeze(Resolver)
