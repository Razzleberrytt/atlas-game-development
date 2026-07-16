--!strict

-- Initial contract limits for recipient-specific perception. Visibility ranges
-- are explicitly prototype values pending P4 playtesting; they are not firearm
-- ranges and do not authorize a target or a line-of-sight query.
local PerceptionConfig = {
	MaximumRememberedObservationsPerOperative = 32,
	MaximumObservationAgeSeconds = 30,
	PrototypeForwardVisibilityRangeStuds = table.freeze({
		Dark = 24,
		Dim = 32,
		Lit = 64,
	}),
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
