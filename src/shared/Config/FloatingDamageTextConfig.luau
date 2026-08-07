--!strict

--[[
	HROI-0111 presentation-only tuning for shooter-specific floating damage text.
	The client consumes an integer applied by the authoritative server resolver;
	these values can never establish hits, damage, death, rewards, or health state.
]]

local FloatingDamageTextConfig = {
	Version = "HROI-0111-v1-floating-damage-text",
	DisplayOrder = 53,
	DurationSeconds = 0.82,
	FadeStartFraction = 0.48,
	RisePixels = 56,
	MaximumLateralDriftPixels = 16,
	BaseTextSize = 23,
	ImpactScale = 1.28,
	SettledScale = 1,
	EndScale = 0.9,
	HotDamageMultiplier = 1.5,
	BrutalDamageMultiplier = 2.5,
	MaximumActiveEntries = 18,
	MaximumRememberedShotIds = 192,
}

assert(
	FloatingDamageTextConfig.DurationSeconds >= 0.45 and FloatingDamageTextConfig.DurationSeconds <= 1.25,
	"floating damage duration must remain readable and bounded"
)
assert(
	FloatingDamageTextConfig.FadeStartFraction >= 0.3 and FloatingDamageTextConfig.FadeStartFraction <= 0.75,
	"floating damage fade must preserve a crisp initial read"
)
assert(
	FloatingDamageTextConfig.RisePixels >= 24 and FloatingDamageTextConfig.RisePixels <= 96,
	"floating damage rise escaped its screen-space budget"
)
assert(
	FloatingDamageTextConfig.MaximumLateralDriftPixels >= 0 and FloatingDamageTextConfig.MaximumLateralDriftPixels <= 32,
	"floating damage lateral drift escaped its screen-space budget"
)
assert(
	FloatingDamageTextConfig.BaseTextSize >= 16 and FloatingDamageTextConfig.BaseTextSize <= 34,
	"floating damage text size must remain isometric-readable"
)
assert(
	FloatingDamageTextConfig.ImpactScale >= FloatingDamageTextConfig.SettledScale
		and FloatingDamageTextConfig.SettledScale >= FloatingDamageTextConfig.EndScale,
	"floating damage scale must settle monotonically"
)
assert(
	FloatingDamageTextConfig.HotDamageMultiplier > 1
		and FloatingDamageTextConfig.BrutalDamageMultiplier > FloatingDamageTextConfig.HotDamageMultiplier,
	"floating damage escalation thresholds must be monotonic"
)
assert(
	FloatingDamageTextConfig.MaximumActiveEntries >= 8 and FloatingDamageTextConfig.MaximumActiveEntries <= 32,
	"floating damage pool must remain useful and bounded"
)
assert(
	FloatingDamageTextConfig.MaximumRememberedShotIds >= 64 and FloatingDamageTextConfig.MaximumRememberedShotIds <= 256,
	"floating damage deduplication memory must remain bounded"
)

return table.freeze(FloatingDamageTextConfig)
