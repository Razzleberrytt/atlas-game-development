--!strict

--[[
	VS-0108 authoritative expedition result finalization and replay decision flow.
	A result can be finalized once, rewards are copied into one immutable summary,
	and exactly one replay decision may be recorded. This module does not teleport
	players, start a new run, persist inventory, or expose a client grant path.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExpeditionContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionContracts)
local ResultContracts = require(ReplicatedStorage.Shared.Expeditions.ExpeditionResultContracts)

local OutcomeIds = ExpeditionContracts.OutcomeIds
local ReplayDecisionIds = ResultContracts.ReplayDecisionIds

export type ExpeditionSnapshot = ExpeditionContracts.ExpeditionSnapshot
export type EquipmentReward = ResultContracts.EquipmentReward
export type ExpeditionResultSummary = ResultContracts.ExpeditionResultSummary
export type ReplayDecisionId = ResultContracts.ReplayDecisionId
export type FinalizeResult = ResultContracts.FinalizeResult
export type ReplayDecisionResult = ResultContracts.ReplayDecisionResult

export type FinalizeParameters = {
	Snapshot: ExpeditionSnapshot,
	FinishedAtUnix: number,
	Rewards: { EquipmentReward },
}

export type Service = {
	finalize: (self: Service, parameters: FinalizeParameters) -> FinalizeResult,
	getSummary: (self: Service) -> ExpeditionResultSummary?,
	recordReplayDecision: (self: Service, decisionId: ReplayDecisionId) -> ReplayDecisionResult,
	destroy: (self: Service) -> (),
}

local ExpeditionResultService = {}
ExpeditionResultService.__index = ExpeditionResultService

local function copyRewards(rewards: { EquipmentReward }): { EquipmentReward }
	local copied = {}
	for index, reward in rewards do
		assert(type(reward.InstanceId) == "string" and #reward.InstanceId >= 8, "invalid reward instance id")
		copied[index] = reward
	end
	return table.freeze(copied)
end

local function copySummary(summary: ExpeditionResultSummary): ExpeditionResultSummary
	return table.freeze({
		RunId = summary.RunId,
		DefinitionId = summary.DefinitionId,
		DefinitionVersion = summary.DefinitionVersion,
		OutcomeId = summary.OutcomeId,
		ReachedPhaseId = summary.ReachedPhaseId,
		ReachedPhaseIndex = summary.ReachedPhaseIndex,
		StartedAtUnix = summary.StartedAtUnix,
		FinishedAtUnix = summary.FinishedAtUnix,
		DurationSeconds = summary.DurationSeconds,
		PartySize = summary.PartySize,
		SecretDiscovered = summary.SecretDiscovered,
		Rewards = summary.Rewards,
		ReplayDecisionId = summary.ReplayDecisionId,
	})
end

local function result(accepted: boolean, reasonId: string, summary: ExpeditionResultSummary?): any
	return table.freeze({
		Accepted = accepted,
		ReasonId = reasonId,
		Summary = summary,
	})
end

function ExpeditionResultService.new(): Service
	return setmetatable({
		_summary = nil,
		_destroyed = false,
	}, ExpeditionResultService) :: any
end

function ExpeditionResultService:finalize(parameters: FinalizeParameters): FinalizeResult
	if (self :: any)._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end
	if (self :: any)._summary ~= nil then
		return result(false, "ResultAlreadyFinalized", copySummary((self :: any)._summary))
	end

	local snapshot = parameters.Snapshot
	if snapshot.OutcomeId == OutcomeIds.InProgress then
		return result(false, "RunStillInProgress", nil)
	end
	if type(parameters.FinishedAtUnix) ~= "number" or parameters.FinishedAtUnix < snapshot.StartedAtUnix then
		return result(false, "InvalidFinishTimestamp", nil)
	end

	local rewards = copyRewards(parameters.Rewards)
	local seenInstances = {}
	for _, reward in rewards do
		if reward.RunId ~= snapshot.RunId then
			return result(false, "RewardRunMismatch", nil)
		end
		if seenInstances[reward.InstanceId] then
			return result(false, "DuplicateRewardInstance", nil)
		end
		seenInstances[reward.InstanceId] = true
	end

	local summary = table.freeze({
		RunId = snapshot.RunId,
		DefinitionId = snapshot.DefinitionId,
		DefinitionVersion = snapshot.DefinitionVersion,
		OutcomeId = snapshot.OutcomeId,
		ReachedPhaseId = snapshot.PhaseId,
		ReachedPhaseIndex = snapshot.PhaseIndex,
		StartedAtUnix = snapshot.StartedAtUnix,
		FinishedAtUnix = parameters.FinishedAtUnix,
		DurationSeconds = parameters.FinishedAtUnix - snapshot.StartedAtUnix,
		PartySize = snapshot.PartySize,
		SecretDiscovered = snapshot.SecretDiscovered,
		Rewards = rewards,
		ReplayDecisionId = ReplayDecisionIds.Undecided,
	})

	local state = self :: any
	state._summary = summary
	return result(true, "ResultFinalized", copySummary(summary))
end

function ExpeditionResultService:getSummary(): ExpeditionResultSummary?
	if (self :: any)._destroyed or (self :: any)._summary == nil then
		return nil
	end
	return copySummary((self :: any)._summary)
end

function ExpeditionResultService:recordReplayDecision(decisionId: ReplayDecisionId): ReplayDecisionResult
	if (self :: any)._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end

	local summary: ExpeditionResultSummary? = (self :: any)._summary
	if summary == nil then
		return result(false, "ResultNotFinalized", nil)
	end
	if decisionId ~= ReplayDecisionIds.Replay and decisionId ~= ReplayDecisionIds.ReturnToPreparation then
		return result(false, "InvalidReplayDecision", copySummary(summary))
	end
	if summary.ReplayDecisionId ~= ReplayDecisionIds.Undecided then
		return result(false, "ReplayDecisionAlreadyRecorded", copySummary(summary))
	end

	local updated = table.freeze({
		RunId = summary.RunId,
		DefinitionId = summary.DefinitionId,
		DefinitionVersion = summary.DefinitionVersion,
		OutcomeId = summary.OutcomeId,
		ReachedPhaseId = summary.ReachedPhaseId,
		ReachedPhaseIndex = summary.ReachedPhaseIndex,
		StartedAtUnix = summary.StartedAtUnix,
		FinishedAtUnix = summary.FinishedAtUnix,
		DurationSeconds = summary.DurationSeconds,
		PartySize = summary.PartySize,
		SecretDiscovered = summary.SecretDiscovered,
		Rewards = summary.Rewards,
		ReplayDecisionId = decisionId,
	})
	local state = self :: any
	state._summary = updated
	return result(true, "ReplayDecisionRecorded", copySummary(updated))
end

function ExpeditionResultService:destroy()
	if (self :: any)._destroyed then
		return
	end
	(self :: any)._destroyed = true
	(self :: any)._summary = nil
end

return table.freeze(ExpeditionResultService)
