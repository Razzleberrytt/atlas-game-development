--!strict

--[[
	VS-0102 shared contracts for the first replayable expedition.
	These definitions are deliberately small: they establish stable phase IDs,
	terminal outcomes, and sanitized snapshot shapes without assigning runtime
	ownership to the client or coupling the expedition to a specific map.
]]

export type ExpeditionPhaseId =
	"Preparation"
	| "Approach"
	| "Dungeon"
	| "Elite"
	| "Boss"
	| "Rewards"
	| "Results"

export type ExpeditionOutcomeId = "InProgress" | "Completed" | "Failed" | "Abandoned"

export type ExpeditionPhaseDefinition = {
	Id: ExpeditionPhaseId,
	Order: number,
	DisplayName: string,
	MinimumDurationSeconds: number,
	MaximumDurationSeconds: number,
	AllowsLateJoin: boolean,
}

export type ExpeditionDefinition = {
	Id: string,
	Version: string,
	DisplayName: string,
	MinimumPlayers: number,
	MaximumPlayers: number,
	TargetDurationSeconds: number,
	Phases: { ExpeditionPhaseDefinition },
}

export type ExpeditionSnapshot = {
	RunId: string,
	DefinitionId: string,
	DefinitionVersion: string,
	Seed: number,
	PhaseId: ExpeditionPhaseId,
	PhaseIndex: number,
	OutcomeId: ExpeditionOutcomeId,
	StartedAtUnix: number,
	PhaseStartedAtUnix: number,
	PartySize: number,
	SecretDiscovered: boolean,
}

local PhaseIds = table.freeze({
	Preparation = "Preparation" :: ExpeditionPhaseId,
	Approach = "Approach" :: ExpeditionPhaseId,
	Dungeon = "Dungeon" :: ExpeditionPhaseId,
	Elite = "Elite" :: ExpeditionPhaseId,
	Boss = "Boss" :: ExpeditionPhaseId,
	Rewards = "Rewards" :: ExpeditionPhaseId,
	Results = "Results" :: ExpeditionPhaseId,
})

local OutcomeIds = table.freeze({
	InProgress = "InProgress" :: ExpeditionOutcomeId,
	Completed = "Completed" :: ExpeditionOutcomeId,
	Failed = "Failed" :: ExpeditionOutcomeId,
	Abandoned = "Abandoned" :: ExpeditionOutcomeId,
})

local ExpeditionContracts = {
	PhaseIds = PhaseIds,
	OutcomeIds = OutcomeIds,
}

return table.freeze(ExpeditionContracts)
