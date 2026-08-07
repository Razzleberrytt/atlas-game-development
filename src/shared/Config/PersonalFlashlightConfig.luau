--!strict

-- LK-0406 prototype tuning. These values define the one approved personal
-- flashlight; they are not an inventory, upgrade, or renderer-truth system.
local PersonalFlashlightConfig = {
	SourceId = "personal-flashlight.v1",
	LightIdPrefix = "personal-flashlight:",
	VisibilityProfileId = "Lit",
	RangeStuds = 48,
	ConeAngleDegrees = 50,
	PresentationRangeStuds = 78,
	PresentationConeAngleDegrees = 64,
	ToggleCooldownSeconds = 0.25,
	PresentationBrightness = 4.2,
	ReducedPresentationIntensityScale = 0.6,
	KeyboardKeyCodeName = "F",
	GamepadKeyCodeName = "ButtonY",
}

return table.freeze(PersonalFlashlightConfig)
