--!strict

--[[
	Pure P7-0103 Brace lifecycle. The runtime supplies server-derived assignment,
	operation, life, movement, reload, time, replay, and rate-limit facts. This
	module owns no Player, service, scheduler, remote, combat state, or position.
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
	serverTimestamp: number,
	isDuplicateRequest: boolean,
	isRateLimited: boolean,
}

export type ContinuityFacts = {
	isOperationActive: boolean,
	isActorAlive: boolean,
	movementDistanceStuds: number,
	didReloadBegin: boolean,
	serverTimestamp: number,
}

export type Resolution = {
	didChange: boolean,
	didActivate: boolean,
	rejectionReasonId: string?,
	requestId: string?,
	actionStateAfter: ClassContracts.AuthoritativeClassActionState,
}

local Resolver = {}

local function copyState(
	state: ClassContracts.AuthoritativeClassActionState
): ClassContracts.AuthoritativeClassActionState
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

local function result(
	didChange: boolean,
	didActivate: boolean,
	reasonId: string?,
	requestId: string?,
	state: ClassContracts.AuthoritativeClassActionState
): Resolution
	return table.freeze({
		didChange = didChange,
		didActivate = didActivate,
		rejectionReasonId = reasonId,
		requestId = requestId,
		actionStateAfter = copyState(state),
	})
end

local function rejected(
	state: ClassContracts.AuthoritativeClassActionState,
	reasonId: string,
	requestId: string?
): Resolution
	return result(false, false, reasonId, requestId, state)
end

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function validStartFacts(facts: unknown): boolean
	if type(facts) ~= "table" then
		return false
	end
	local candidate = facts :: any
	return type(candidate.isParticipant) == "boolean"
		and type(candidate.isOperationActive) == "boolean"
		and type(candidate.assignedClassId) == "string"
		and type(candidate.isActorAlive) == "boolean"
		and isFiniteNonnegative(candidate.serverTimestamp)
		and type(candidate.isDuplicateRequest) == "boolean"
		and type(candidate.isRateLimited) == "boolean"
end

local function validContinuityFacts(facts: unknown): boolean
	if type(facts) ~= "table" then
		return false
	end
	local candidate = facts :: any
	return type(candidate.isOperationActive) == "boolean"
		and type(candidate.isActorAlive) == "boolean"
		and isFiniteNonnegative(candidate.movementDistanceStuds)
		and type(candidate.didReloadBegin) == "boolean"
		and isFiniteNonnegative(candidate.serverTimestamp)
end

local function cooldownState(
	state: ClassContracts.AuthoritativeClassActionState,
	serverTimestamp: number,
	reasonId: string
): ClassContracts.AuthoritativeClassActionState
	return table.freeze({
		actionStateId = ActionStateIds.Cooldown,
		actionId = ActionIds.Brace,
		targetOperativeEntityId = nil,
		startedAtServerTimestamp = nil,
		completionServerTimestamp = nil,
		cooldownEndServerTimestamp = serverTimestamp + ClassConfig.Actions.Brace.cooldownSeconds,
		statusReasonId = reasonId,
		revision = state.revision + 1,
	})
end

local function idleState(
	state: ClassContracts.AuthoritativeClassActionState
): ClassContracts.AuthoritativeClassActionState
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

function Resolver.resolveStart(
	currentState: ClassContracts.AuthoritativeClassActionState,
	rawIntent: unknown,
	facts: StartFacts
): Resolution
	if not ClassContracts.validateAuthoritativeClassActionState(currentState) or not validStartFacts(facts) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	if not ClassContracts.validateClassActionIntent(rawIntent) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	local intent = rawIntent :: any
	local requestId = intent.requestId :: string
	if intent.actionId ~= ActionIds.Brace then
		return rejected(currentState, ReasonIds.UnknownAction, requestId)
	end
	if intent.phaseId ~= PhaseIds.Begin or intent.candidateTargetOperativeEntityId ~= nil then
		return rejected(currentState, ReasonIds.InvalidIntent, requestId)
	end
	if not facts.isParticipant then
		return rejected(currentState, ReasonIds.NotParticipant, requestId)
	end
	if not facts.isOperationActive then
		return rejected(currentState, ReasonIds.OperationPhaseInvalid, requestId)
	end
	if facts.assignedClassId ~= ClassIds.CombatSpecialist then
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
	if facts.isDuplicateRequest then
		return rejected(currentState, ReasonIds.DuplicateRequest, requestId)
	end
	if facts.isRateLimited then
		return rejected(currentState, ReasonIds.RateLimited, requestId)
	end
	return result(true, true, nil, requestId, {
		actionStateId = ActionStateIds.Active,
		actionId = ActionIds.Brace,
		targetOperativeEntityId = nil,
		startedAtServerTimestamp = facts.serverTimestamp,
		completionServerTimestamp = facts.serverTimestamp + ClassConfig.Actions.Brace.durationSeconds,
		cooldownEndServerTimestamp = nil,
		statusReasonId = nil,
		revision = currentState.revision + 1,
	})
end

function Resolver.resolveContinuity(
	currentState: ClassContracts.AuthoritativeClassActionState,
	facts: ContinuityFacts
): Resolution
	if not ClassContracts.validateAuthoritativeClassActionState(currentState) or not validContinuityFacts(facts) then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	if currentState.actionStateId == ActionStateIds.Cooldown then
		local cooldownEnd = currentState.cooldownEndServerTimestamp
		if cooldownEnd ~= nil and facts.serverTimestamp >= cooldownEnd then
			return result(true, false, nil, nil, idleState(currentState))
		end
		return result(false, false, nil, nil, currentState)
	end
	if currentState.actionStateId ~= ActionStateIds.Active then
		return result(false, false, nil, nil, currentState)
	end
	if not facts.isOperationActive then
		return result(
			true,
			false,
			ReasonIds.OperationResolved,
			nil,
			cooldownState(currentState, facts.serverTimestamp, ReasonIds.OperationResolved)
		)
	end
	if not facts.isActorAlive then
		return result(
			true,
			false,
			ReasonIds.ActorNotAlive,
			nil,
			cooldownState(currentState, facts.serverTimestamp, ReasonIds.ActorNotAlive)
		)
	end
	if facts.movementDistanceStuds > ClassConfig.Actions.Brace.movementToleranceStuds then
		return result(
			true,
			false,
			ReasonIds.MovementInterrupted,
			nil,
			cooldownState(currentState, facts.serverTimestamp, ReasonIds.MovementInterrupted)
		)
	end
	if facts.didReloadBegin and ClassConfig.Actions.Brace.interruptOnReload then
		return result(
			true,
			false,
			ReasonIds.ReloadInterrupted,
			nil,
			cooldownState(currentState, facts.serverTimestamp, ReasonIds.ReloadInterrupted)
		)
	end
	local completion = currentState.completionServerTimestamp
	if completion ~= nil and facts.serverTimestamp >= completion then
		return result(
			true,
			false,
			ReasonIds.ActionCompleted,
			nil,
			cooldownState(currentState, facts.serverTimestamp, ReasonIds.ActionCompleted)
		)
	end
	return result(false, false, nil, nil, currentState)
end

function Resolver.resolveCancel(
	currentState: ClassContracts.AuthoritativeClassActionState,
	rawIntent: unknown,
	serverTimestamp: number
): Resolution
	if
		not ClassContracts.validateAuthoritativeClassActionState(currentState)
		or not ClassContracts.validateClassActionIntent(rawIntent)
		or not isFiniteNonnegative(serverTimestamp)
	then
		return rejected(currentState, ReasonIds.InvalidIntent, nil)
	end
	local intent = rawIntent :: any
	local requestId = intent.requestId :: string
	if intent.actionId ~= ActionIds.Brace then
		return rejected(currentState, ReasonIds.UnknownAction, requestId)
	end
	if intent.phaseId ~= PhaseIds.Cancel and intent.phaseId ~= PhaseIds.End then
		return rejected(currentState, ReasonIds.InvalidIntent, requestId)
	end
	if currentState.actionStateId ~= ActionStateIds.Active or currentState.actionId ~= ActionIds.Brace then
		return rejected(currentState, ReasonIds.InvalidIntent, requestId)
	end
	return result(
		true,
		false,
		ReasonIds.ActionCancelled,
		requestId,
		cooldownState(currentState, serverTimestamp, ReasonIds.ActionCancelled)
	)
end

return table.freeze(Resolver)
