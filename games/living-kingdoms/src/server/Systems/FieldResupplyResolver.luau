--!strict

--[[
	Pure P7-0105 Field Resupply lifecycle. The client supplies only a candidate
	operative. The runtime derives class, life, resource, weapon compatibility,
	capacity, distance, visibility, movement, damage, and time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)

local ActionIds = ClassContracts.ClassActionIds
local ActionStateIds = ClassContracts.ClassActionStateIds
local ClassIds = ClassContracts.ClassIds
local PhaseIds = ClassContracts.ClassActionPhaseIds
local ReasonIds = ClassContracts.ClassActionRejectionReasonIds

export type Facts = {
	isParticipant: boolean,
	isOperationActive: boolean,
	assignedClassId: string,
	isActorAlive: boolean,
	resourceAmount: number,
	isTargetKnown: boolean,
	isTargetAlive: boolean,
	isWeaponCompatible: boolean,
	hasCapacity: boolean,
	distanceStuds: number,
	hasLineOfSight: boolean,
	movementDistanceStuds: number,
	didActorTakeDamage: boolean,
	serverTimestamp: number,
}

export type Resolution = {
	didChange: boolean,
	didActivate: boolean,
	shouldCommitResupply: boolean,
	rejectionReasonId: string?,
	requestId: string?,
	actionStateAfter: ClassContracts.AuthoritativeClassActionState,
}

local Resolver = {}

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function validFacts(facts: unknown): boolean
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
		and type(value.isTargetAlive) == "boolean"
		and type(value.isWeaponCompatible) == "boolean"
		and type(value.hasCapacity) == "boolean"
		and isFiniteNonnegative(value.distanceStuds)
		and type(value.hasLineOfSight) == "boolean"
		and isFiniteNonnegative(value.movementDistanceStuds)
		and type(value.didActorTakeDamage) == "boolean"
		and isFiniteNonnegative(value.serverTimestamp)
end

local function copyState(state)
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

local function result(changed, activated, shouldCommit, reasonId, requestId, state): Resolution
	return table.freeze({
		didChange = changed,
		didActivate = activated,
		shouldCommitResupply = shouldCommit,
		rejectionReasonId = reasonId,
		requestId = requestId,
		actionStateAfter = copyState(state),
	}) :: any
end

local function rejected(state, reasonId, requestId): Resolution
	return result(false, false, false, reasonId, requestId, state)
end

local function cooldownState(state, timestamp: number, reasonId: string)
	return table.freeze({
		actionStateId = ActionStateIds.Cooldown,
		actionId = ActionIds.FieldResupply,
		targetOperativeEntityId = nil,
		startedAtServerTimestamp = nil,
		completionServerTimestamp = nil,
		cooldownEndServerTimestamp = timestamp + ClassConfig.Actions.FieldResupply.cooldownSeconds,
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

local function eligibilityReason(facts: Facts): string?
	if not facts.isParticipant then
		return ReasonIds.NotParticipant
	elseif not facts.isOperationActive then
		return ReasonIds.OperationPhaseInvalid
	elseif facts.assignedClassId ~= ClassIds.Engineer then
		return ReasonIds.WrongAssignedClass
	elseif not facts.isActorAlive then
		return ReasonIds.ActorNotAlive
	elseif facts.resourceAmount < ClassConfig.Actions.FieldResupply.resourceCost then
		return ReasonIds.InsufficientResource
	elseif not facts.isTargetKnown then
		return ReasonIds.UnknownTarget
	elseif not facts.isTargetAlive then
		return ReasonIds.TargetNotAlive
	elseif not facts.isWeaponCompatible then
		return ReasonIds.IncompatibleWeapon
	elseif not facts.hasCapacity then
		return ReasonIds.NoCapacity
	elseif facts.distanceStuds > ClassConfig.Actions.FieldResupply.maximumRangeStuds then
		return ReasonIds.OutOfRange
	elseif not facts.hasLineOfSight then
		return ReasonIds.NoLineOfSight
	end
	return nil
end

function Resolver.resolveStart(currentState, rawIntent: unknown, facts: Facts): Resolution
	if not ClassContracts.validateAuthoritativeClassActionState(currentState) or not validFacts(facts) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	if not ClassContracts.validateClassActionIntent(rawIntent) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	local intent = rawIntent :: any
	if intent.actionId ~= ActionIds.FieldResupply then
		return rejected(currentState, ReasonIds.UnknownAction, intent.requestId)
	end
	if intent.phaseId ~= PhaseIds.Begin or intent.candidateTargetOperativeEntityId == nil then
		return rejected(currentState, ReasonIds.InvalidIntent, intent.requestId)
	end
	if currentState.actionStateId == ActionStateIds.Active then
		return rejected(currentState, ReasonIds.ActionAlreadyActive, intent.requestId)
	elseif currentState.actionStateId == ActionStateIds.Cooldown then
		return rejected(currentState, ReasonIds.ActionOnCooldown, intent.requestId)
	end
	local reasonId = eligibilityReason(facts)
	if reasonId ~= nil then
		return rejected(currentState, reasonId, intent.requestId)
	end
	return result(true, true, false, nil, intent.requestId, {
		actionStateId = ActionStateIds.Active,
		actionId = ActionIds.FieldResupply,
		targetOperativeEntityId = intent.candidateTargetOperativeEntityId,
		startedAtServerTimestamp = facts.serverTimestamp,
		completionServerTimestamp = facts.serverTimestamp + ClassConfig.Actions.FieldResupply.channelDurationSeconds,
		cooldownEndServerTimestamp = nil,
		statusReasonId = nil,
		revision = currentState.revision + 1,
	})
end

function Resolver.resolveContinuity(currentState, facts: Facts): Resolution
	if not ClassContracts.validateAuthoritativeClassActionState(currentState) or not validFacts(facts) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	if currentState.actionStateId == ActionStateIds.Cooldown then
		local deadline = currentState.cooldownEndServerTimestamp
		if deadline ~= nil and facts.serverTimestamp >= deadline then
			return result(true, false, false, nil, nil, idleState(currentState))
		end
		return result(false, false, false, nil, nil, currentState)
	end
	if currentState.actionStateId ~= ActionStateIds.Active or currentState.actionId ~= ActionIds.FieldResupply then
		return result(false, false, false, nil, nil, currentState)
	end
	local reasonId = if not facts.isOperationActive then ReasonIds.OperationResolved else eligibilityReason(facts)
	if reasonId == nil and facts.movementDistanceStuds > ClassConfig.Actions.FieldResupply.movementToleranceStuds then
		reasonId = ReasonIds.MovementInterrupted
	elseif reasonId == nil and facts.didActorTakeDamage then
		reasonId = ReasonIds.DamageInterrupted
	end
	if reasonId ~= nil then
		return result(true, false, false, reasonId, nil, cooldownState(currentState, facts.serverTimestamp, reasonId))
	end
	local completion = currentState.completionServerTimestamp
	if completion ~= nil and facts.serverTimestamp >= completion then
		return result(
			true,
			false,
			true,
			ReasonIds.ActionCompleted,
			nil,
			cooldownState(currentState, facts.serverTimestamp, ReasonIds.ActionCompleted)
		)
	end
	return result(false, false, false, nil, nil, currentState)
end

function Resolver.resolveCancel(currentState, rawIntent: unknown, timestamp: number): Resolution
	if
		not ClassContracts.validateAuthoritativeClassActionState(currentState)
		or not ClassContracts.validateClassActionIntent(rawIntent)
		or not isFiniteNonnegative(timestamp)
	then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	local intent = rawIntent :: any
	if intent.actionId ~= ActionIds.FieldResupply then
		return rejected(currentState, ReasonIds.UnknownAction, intent.requestId)
	end
	if
		(intent.phaseId ~= PhaseIds.Cancel and intent.phaseId ~= PhaseIds.End)
		or currentState.actionStateId ~= ActionStateIds.Active
		or currentState.actionId ~= ActionIds.FieldResupply
	then
		return rejected(currentState, ReasonIds.InvalidIntent, intent.requestId)
	end
	return result(
		true,
		false,
		false,
		ReasonIds.ActionCancelled,
		intent.requestId,
		cooldownState(currentState, timestamp, ReasonIds.ActionCancelled)
	)
end

function Resolver.resolveEffectRejected(currentState, timestamp: number): Resolution
	if not ClassContracts.validateAuthoritativeClassActionState(currentState) or not isFiniteNonnegative(timestamp) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	return result(
		true,
		false,
		false,
		ReasonIds.EffectCommitRejected,
		nil,
		cooldownState(currentState, timestamp, ReasonIds.EffectCommitRejected)
	)
end

return table.freeze(Resolver)
