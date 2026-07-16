--!strict

-- Initial contract limits for recipient-specific remembered observations.
-- These placeholders bound later owners; they are not gameplay tuning.
local PerceptionConfig = {
	MaximumRememberedObservationsPerOperative = 32,
	MaximumObservationAgeSeconds = 30,
	SupportedPerceptionStateIds = table.freeze({
		Unknown = "Unknown",
		Suspected = "Suspected",
		Observed = "Observed",
	}),
	SupportedObservationConfidenceIds = table.freeze({
		Low = "Low",
		Medium = "Medium",
		High = "High",
	}),
}

return table.freeze(PerceptionConfig)
