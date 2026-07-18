--!strict

--[[
	HROI-0109 client-only critical-condition presentation values. These settings
	control only a bounded screen-edge warning derived from server-replicated P3
	life attributes. They never establish health, life state, damage, or recovery.
]]

local CriticalConditionConfig = {
	Version = "HROI-0109-v1-critical-condition-urgency",
	CriticalHealthFraction = 0.25,
	MortalHealthFraction = 0.1,
	PulseRadiansPerSecond = 4.8,
	MortalPulseSpeedMultiplier = 1.35,
	EdgeThicknessPixels = 118,
	EdgeMinimumTransparency = 0.18,
	EdgeMaximumTransparency = 0.58,
	PulseTransparencyAmplitude = 0.16,
	WarningMinimumTransparency = 0.04,
	WarningMaximumTransparency = 0.3,
}

assert(
	CriticalConditionConfig.CriticalHealthFraction >= 0.15
		and CriticalConditionConfig.CriticalHealthFraction <= 0.35,
	"critical condition must begin late enough to preserve readability and early enough to create urgency"
)
assert(
	CriticalConditionConfig.MortalHealthFraction > 0
		and CriticalConditionConfig.MortalHealthFraction < CriticalConditionConfig.CriticalHealthFraction,
	"mortal condition must be a stricter subset of critical health"
)
assert(
	CriticalConditionConfig.PulseRadiansPerSecond >= 2 and CriticalConditionConfig.PulseRadiansPerSecond <= 8,
	"critical pulse speed must remain noticeable but bounded"
)
assert(
	CriticalConditionConfig.MortalPulseSpeedMultiplier >= 1
		and CriticalConditionConfig.MortalPulseSpeedMultiplier <= 1.75,
	"mortal pulse escalation must remain bounded"
)
assert(
	CriticalConditionConfig.EdgeThicknessPixels >= 72 and CriticalConditionConfig.EdgeThicknessPixels <= 160,
	"critical screen edges must remain visible without consuming the combat view"
)
assert(
	CriticalConditionConfig.EdgeMinimumTransparency >= 0.1
		and CriticalConditionConfig.EdgeMaximumTransparency <= 0.75
		and CriticalConditionConfig.EdgeMinimumTransparency < CriticalConditionConfig.EdgeMaximumTransparency,
	"critical edge transparency bounds drifted"
)
assert(
	CriticalConditionConfig.PulseTransparencyAmplitude > 0
		and CriticalConditionConfig.PulseTransparencyAmplitude <= 0.25,
	"critical pulse amplitude must remain bounded"
)

return table.freeze(CriticalConditionConfig)
