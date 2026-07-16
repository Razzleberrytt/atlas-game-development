--!strict

--[[
	Canonical shared declarations for recipient-specific perception, disclosure,
	and remembered knowledge. These records contain no Roblox objects, renderer
	state, spatial facts, targeting state, or line-of-sight results. The server
	owns every accepted record and the timestamp used to evaluate its age.
]]

local PerceptionContracts = {}

export type PerceptionStateId = "Unknown" | "Suspected" | "Observed"

export type DisclosureStateId = "Hidden" | "Disclosed"

export type MemoryStateId = "None" | "Remembered"

export type ObservationConfidenceId = "Low" | "Medium" | "High"

export type ObservationSourceId = "DirectSight" | "TeammateInformation" | "AuthoredObjective"

export type ObservationRecord = {
	observedEntityId: string,
	observationSourceId: ObservationSourceId,
	disclosureStateId: DisclosureStateId,
	perceptionStateId: PerceptionStateId,
	memoryStateId: MemoryStateId,
	confidenceId: ObservationConfidenceId,
	observedAtServerTimestamp: number,
}

export type PerceptionRejectionReasonId =
	"InvalidRecord"
	| "InvalidEntity"
	| "InvalidSource"
	| "InvalidDisclosure"
	| "InvalidPerception"
	| "InvalidMemory"
	| "InvalidConfidence"
	| "InvalidStateCombination"
	| "InvalidTimestamp"
	| "StaleObservation"

export type PerceptionEvaluation = {
	isValid: boolean,
	rejectionReasonId: PerceptionRejectionReasonId?,
}

PerceptionContracts.PerceptionStateIds = table.freeze({
	Unknown = "Unknown",
	Suspected = "Suspected",
	Observed = "Observed",
})

PerceptionContracts.DisclosureStateIds = table.freeze({
	Hidden = "Hidden",
	Disclosed = "Disclosed",
})

PerceptionContracts.MemoryStateIds = table.freeze({
	None = "None",
	Remembered = "Remembered",
})

PerceptionContracts.ObservationConfidenceIds = table.freeze({
	Low = "Low",
	Medium = "Medium",
	High = "High",
})

PerceptionContracts.ObservationSourceIds = table.freeze({
	DirectSight = "DirectSight",
	TeammateInformation = "TeammateInformation",
	AuthoredObjective = "AuthoredObjective",
})

PerceptionContracts.PerceptionRejectionReasonIds = table.freeze({
	InvalidRecord = "InvalidRecord",
	InvalidEntity = "InvalidEntity",
	InvalidSource = "InvalidSource",
	InvalidDisclosure = "InvalidDisclosure",
	InvalidPerception = "InvalidPerception",
	InvalidMemory = "InvalidMemory",
	InvalidConfidence = "InvalidConfidence",
	InvalidStateCombination = "InvalidStateCombination",
	InvalidTimestamp = "InvalidTimestamp",
	StaleObservation = "StaleObservation",
})

return table.freeze(PerceptionContracts)
