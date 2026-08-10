--!strict

-- LK-0406 prototype tuning. These values define the one approved personal
-- flashlight; they are not an inventory, upgrade, or renderer-truth system.
--
-- Patch 0.4 adds one authored coverage profile per durable unlock state. The
-- server picks the profile from the operative's durable rank; nothing here is
-- selectable by a client. Focused coverage must stay inside the canonical
-- GameplayLightingConfig cone bounds (64 studs / 120 degrees), which the
-- PersonalFlashlightService fixture asserts against the real lighting config.
local PersonalFlashlightConfig = {
	SourceId = "personal-flashlight.v1",
	LightIdPrefix = "personal-flashlight:",
	VisibilityProfileId = "Lit",
	RangeStuds = 48,
	ConeAngleDegrees = 50,
	PresentationRangeStuds = 78,
	PresentationConeAngleDegrees = 64,
	FocusedRangeStuds = 60,
	FocusedConeAngleDegrees = 58,
	FocusedPresentationRangeStuds = 92,
	FocusedPresentationConeAngleDegrees = 72,
	ToggleCooldownSeconds = 0.25,
	PresentationBrightness = 4.2,
	ReducedPresentationIntensityScale = 0.6,
	KeyboardKeyCodeName = "F",
	GamepadKeyCodeName = "ButtonY",
}

assert(
	PersonalFlashlightConfig.FocusedRangeStuds > PersonalFlashlightConfig.RangeStuds
		and PersonalFlashlightConfig.FocusedConeAngleDegrees > PersonalFlashlightConfig.ConeAngleDegrees,
	"the focused coverage profile must be a strict improvement over the standard profile"
)
assert(
	PersonalFlashlightConfig.FocusedRangeStuds <= 64 and PersonalFlashlightConfig.FocusedConeAngleDegrees <= 120,
	"focused coverage must stay inside the canonical gameplay-light cone bounds"
)
assert(
	PersonalFlashlightConfig.FocusedPresentationRangeStuds > PersonalFlashlightConfig.PresentationRangeStuds
		and PersonalFlashlightConfig.FocusedPresentationConeAngleDegrees
			> PersonalFlashlightConfig.PresentationConeAngleDegrees,
	"focused presentation must read as an improvement to the owning player"
)
assert(
	PersonalFlashlightConfig.FocusedPresentationRangeStuds > PersonalFlashlightConfig.FocusedRangeStuds
		and PersonalFlashlightConfig.FocusedPresentationConeAngleDegrees
			> PersonalFlashlightConfig.FocusedConeAngleDegrees,
	"presentation must remain more generous than gameplay coverage so light never implies visibility"
)

return table.freeze(PersonalFlashlightConfig)
