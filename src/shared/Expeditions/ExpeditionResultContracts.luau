--!strict

--[[
	VS-0108 shared contracts for immutable expedition results and one bounded
	replay decision. These records are presentation-safe summaries; authoritative
	finalization remains server-owned.
]]

local EquipmentRewardContracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)
local ExpeditionContracts = require(script.Parent.ExpeditionContracts)

export type EquipmentReward = EquipmentRewardContracts.EquipmentReward
export type ExpeditionOutcomeId = ExpeditionContracts.ExpeditionOutcomeId
export type ExpeditionPhaseId = ExpeditionContracts.ExpeditionPhaseId

export type ReplayDecisionId = "Undecided" | "Replay" | "ReturnToPreparation"

export type ExpeditionResultSummary = {
	RunId: string,
	DefinitionId: string,
	DefinitionVersion: string,
	OutcomeId: ExpeditionOutcomeId,
	ReachedPhaseId: ExpeditionPhaseId,
	ReachedPhaseIndex: number,
	StartedAtUnix: number,
	FinishedAtUnix: number,
	DurationSeconds: number,
	PartySize: number,
	SecretDiscovered: boolean,
	Rewards: { EquipmentReward },
	ReplayDecisionId: ReplayDecisionId,
}

export type FinalizeResult = {
	Accepted: boolean,
	ReasonId: string,
	Summary: ExpeditionResultSummary?,
}

export type ReplayDecisionResult = {
	Accepted: boolean,
	ReasonId: string,
	Summary: ExpeditionResultSummary?,
}

local ReplayDecisionIds = table.freeze({
	Undecided = "Undecided" :: ReplayDecisionId,
	Replay = "Replay" :: ReplayDecisionId,
	ReturnToPreparation = "ReturnToPreparation" :: ReplayDecisionId,
})

return table.freeze({
	ReplayDecisionIds = ReplayDecisionIds,
})
