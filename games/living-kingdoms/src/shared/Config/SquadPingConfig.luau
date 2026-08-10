--!strict

-- LK-0407's single frozen tuning home. Location is the only client-requestable
-- category in this bounded slice; server-earned Rally identity, marker
-- capacity, and persistent marker lifetime remain server-derived.
return table.freeze({
	LifetimeSeconds = 6,
	PersistentMarkerLifetimeSeconds = 9,
	CooldownSeconds = 1.5,
	MaximumActivePerSender = 1,
	DualTacticalMaximumActivePerSender = 2,
	MaximumActivePerSquad = 4,
	MaximumDistanceStuds = 120,
	QuantizationStuds = 4,
	ProductionSquadId = "operation:primary",
	KeyboardKeyCodeName = "G",
	GamepadKeyCodeName = "DPadUp",
	DefaultForwardDistanceStuds = 48,
})
