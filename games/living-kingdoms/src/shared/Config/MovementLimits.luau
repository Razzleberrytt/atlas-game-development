--!strict

-- Prototype limits shared by local movement presentation and server validation.
-- These values define a movement sanity boundary, not production anti-cheat.
return table.freeze({
	MaximumPrototypeHorizontalSpeed = 16,
	ObservationIntervalSeconds = 0.25,
	HorizontalToleranceStuds = 4,
	WarningCooldownSeconds = 2,
})
