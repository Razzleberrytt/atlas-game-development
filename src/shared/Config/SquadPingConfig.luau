--!strict

-- LK-0407's single frozen tuning home. Location is the only production
-- category in this bounded slice; other safe categories remain reserved.
return table.freeze({
	LifetimeSeconds = 6,
	CooldownSeconds = 1.5,
	MaximumActivePerSender = 1,
	MaximumActivePerSquad = 4,
	MaximumDistanceStuds = 120,
	QuantizationStuds = 4,
	ProductionSquadId = "operation:primary",
	KeyboardKeyCodeName = "G",
	GamepadKeyCodeName = "DPadUp",
	DefaultForwardDistanceStuds = 48,
})
