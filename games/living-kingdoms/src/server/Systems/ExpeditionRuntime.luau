--!strict

--[[
	VS-0103 authoritative in-memory expedition lifecycle.

	This module owns one expedition run's consequential state. Callers may read
	sanitized snapshots, but phase advancement and terminal outcomes remain
	server-controlled. Room assembly, encounter wiring, rewards, persistence, and
	network transport are intentionally outside this boundary.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local ExpeditionConfig = require(ReplicatedStorage.Shared.Config.ExpeditionConfig)

local OutcomeIds = ExpeditionContracts.OutcomeIds

export type ExpeditionDefinition = ExpeditionContracts.ExpeditionDefinition
export type ExpeditionSnapshot = ExpeditionContracts.ExpeditionSnapshot
export type ExpeditionOutcomeId = ExpeditionContracts.ExpeditionOutcomeId

export type StartParameters = {
	RunId: string,
	Seed: number,
	PartySize: number,
	StartedAtUnix: number,
}

export type AdvanceResult = {
	Accepted: boolean,
	ReasonId: string,
	Snapshot: ExpeditionSnapshot?,
}

export type Runtime = {
	getSnapshot: (self: Runtime) -> ExpeditionSnapshot?,
	advancePhase: (self: Runtime, expectedPhaseId: string, nowUnix: number) -> AdvanceResult,
	finish: (self: Runtime, outcomeId: ExpeditionOutcomeId, expectedPhaseId: string, nowUnix: number) -> AdvanceResult,
	markSecretDiscovered: (self: Runtime) -> boolean,
	destroy: (self: Runtime) -> (),
}

type InternalState = {
	RunId: string,
	Definition: ExpeditionDefinition,
	Seed: number,
	PartySize: number,
	StartedAtUnix: number,
	PhaseStartedAtUnix: number,
	PhaseIndex: number,
	OutcomeId: ExpeditionOutcomeId,
	SecretDiscovered: boolean,
	Destroyed: boolean,
}

local ExpeditionRuntime = {}
ExpeditionRuntime.__index = ExpeditionRuntime

local function isInteger(value: number): boolean
	return value % 1 == 0
end

local function copySnapshot(state: InternalState): ExpeditionSnapshot
	local phase = state.Definition.Phases[state.PhaseIndex]
	return table.freeze({
		RunId = state.RunId,
		DefinitionId = state.Definition.Id,
		DefinitionVersion = state.Definition.Version,
		Seed = state.Seed,
		PhaseId = phase.Id,
		PhaseIndex = state.PhaseIndex,
		OutcomeId = state.OutcomeId,
		StartedAtUnix = state.StartedAtUnix,
		PhaseStartedAtUnix = state.PhaseStartedAtUnix,
		PartySize = state.PartySize,
		SecretDiscovered = state.SecretDiscovered,
	})
end

local function reject(reasonId: string, snapshot: ExpeditionSnapshot?): AdvanceResult
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		Snapshot = snapshot,
	})
end

local function accept(reasonId: string, snapshot: ExpeditionSnapshot): AdvanceResult
	return table.freeze({
		Accepted = true,
		ReasonId = reasonId,
		Snapshot = snapshot,
	})
end

function ExpeditionRuntime.new(definition: ExpeditionDefinition, parameters: StartParameters): Runtime
	assert(type(parameters.RunId) == "string" and #parameters.RunId >= 8 and #parameters.RunId <= 96, "invalid run id")
	assert(isInteger(parameters.Seed), "expedition seed must be an integer")
	assert(
		parameters.Seed >= ExpeditionConfig.RuntimeLimits.MinimumSeed
			and parameters.Seed <= ExpeditionConfig.RuntimeLimits.MaximumSeed,
		"expedition seed is outside configured bounds"
	)
	assert(isInteger(parameters.PartySize), "party size must be an integer")
	assert(
		parameters.PartySize >= definition.MinimumPlayers and parameters.PartySize <= definition.MaximumPlayers,
		"party size is outside expedition bounds"
	)
	assert(type(parameters.StartedAtUnix) == "number" and parameters.StartedAtUnix >= 0, "invalid start timestamp")
	assert(#definition.Phases >= 2, "an expedition requires at least two phases")

	local state: InternalState = {
		RunId = parameters.RunId,
		Definition = definition,
		Seed = parameters.Seed,
		PartySize = parameters.PartySize,
		StartedAtUnix = parameters.StartedAtUnix,
		PhaseStartedAtUnix = parameters.StartedAtUnix,
		PhaseIndex = 1,
		OutcomeId = OutcomeIds.InProgress,
		SecretDiscovered = false,
		Destroyed = false,
	}

	return setmetatable({ _state = state }, ExpeditionRuntime) :: any
end

function ExpeditionRuntime:getSnapshot(): ExpeditionSnapshot?
	local state: InternalState = (self :: any)._state
	if state.Destroyed then
		return nil
	end
	return copySnapshot(state)
end

function ExpeditionRuntime:advancePhase(expectedPhaseId: string, nowUnix: number): AdvanceResult
	local state: InternalState = (self :: any)._state
	if state.Destroyed then
		return reject("RunDestroyed", nil)
	end

	local snapshot = copySnapshot(state)
	if state.OutcomeId ~= OutcomeIds.InProgress then
		return reject("RunTerminal", snapshot)
	end

	local currentPhase = state.Definition.Phases[state.PhaseIndex]
	if expectedPhaseId ~= currentPhase.Id then
		return reject("StalePhase", snapshot)
	end
	if type(nowUnix) ~= "number" or nowUnix < state.PhaseStartedAtUnix then
		return reject("InvalidTimestamp", snapshot)
	end
	if nowUnix - state.StartedAtUnix > ExpeditionConfig.RuntimeLimits.MaximumRunLifetimeSeconds then
		return reject("RunLifetimeExceeded", snapshot)
	end
	if nowUnix - state.PhaseStartedAtUnix < currentPhase.MinimumDurationSeconds then
		return reject("PhaseMinimumDuration", snapshot)
	end
	if state.PhaseIndex >= #state.Definition.Phases then
		return reject("FinalPhaseRequiresOutcome", snapshot)
	end

	state.PhaseIndex += 1
	state.PhaseStartedAtUnix = nowUnix
	return accept("PhaseAdvanced", copySnapshot(state))
end

function ExpeditionRuntime:finish(
	outcomeId: ExpeditionOutcomeId,
	expectedPhaseId: string,
	nowUnix: number
): AdvanceResult
	local state: InternalState = (self :: any)._state
	if state.Destroyed then
		return reject("RunDestroyed", nil)
	end

	local snapshot = copySnapshot(state)
	if state.OutcomeId ~= OutcomeIds.InProgress then
		return reject("RunTerminal", snapshot)
	end
	if outcomeId == OutcomeIds.InProgress then
		return reject("InvalidOutcome", snapshot)
	end

	local currentPhase = state.Definition.Phases[state.PhaseIndex]
	if expectedPhaseId ~= currentPhase.Id then
		return reject("StalePhase", snapshot)
	end
	if type(nowUnix) ~= "number" or nowUnix < state.PhaseStartedAtUnix then
		return reject("InvalidTimestamp", snapshot)
	end
	if nowUnix - state.StartedAtUnix > ExpeditionConfig.RuntimeLimits.MaximumRunLifetimeSeconds then
		return reject("RunLifetimeExceeded", snapshot)
	end
	if outcomeId == OutcomeIds.Completed and state.PhaseIndex ~= #state.Definition.Phases then
		return reject("CompletionBeforeFinalPhase", snapshot)
	end

	state.OutcomeId = outcomeId
	return accept("RunFinished", copySnapshot(state))
end

function ExpeditionRuntime:markSecretDiscovered(): boolean
	local state: InternalState = (self :: any)._state
	if state.Destroyed or state.OutcomeId ~= OutcomeIds.InProgress or state.SecretDiscovered then
		return false
	end
	state.SecretDiscovered = true
	return true
end

function ExpeditionRuntime:destroy()
	local state: InternalState = (self :: any)._state
	if state.Destroyed then
		return
	end
	state.Destroyed = true
end

return table.freeze(ExpeditionRuntime)
