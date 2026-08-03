--!strict

-- Prototype limits shared by local movement presentation and server validation.
-- These values define a movement sanity boundary, not production anti-cheat.
return table.freeze({
	WalkingSpeed = 16,
	SprintingSpeed = 24,
	MaximumPrototypeHorizontalSpeed = 26,
	ObservationIntervalSeconds = 0.25,
	HorizontalToleranceStuds = 4,
	WarningCooldownSeconds = 2,
})
