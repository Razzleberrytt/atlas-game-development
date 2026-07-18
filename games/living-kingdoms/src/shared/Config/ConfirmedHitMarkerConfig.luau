--!strict

--[[
	HROI-0110 presentation-only tuning for shooter-specific confirmed hit markers.
	The controller consumes existing server-authored ShotFired disclosures and can
	never establish targeting, ammunition spend, hits, damage, death, or rewards.
]]

local ConfirmedHitMarkerConfig = {
	Version = "HROI-0110-v1-confirmed-hit-marker",
	DisplayOrder = 52,
	MarkerDurationSeconds = 0.34,
	ChainWindowSeconds = 0.72,
	MinimumRadiusPixels = 9,
	MaximumRadiusPixels = 25,
	ArmLengthPixels = 18,
	ArmThicknessPixels = 3,
	FadeStartFraction = 0.42,
	HotChainThreshold = 4,
	BrutalChainThreshold = 8,
	MaximumRememberedShotIds = 128,
}

assert(
	ConfirmedHitMarkerConfig.MarkerDurationSeconds >= 0.18 and ConfirmedHitMarkerConfig.MarkerDurationSeconds <= 0.6,
	"confirmed hit marker duration must remain immediate and bounded"
)
assert(
	ConfirmedHitMarkerConfig.ChainWindowSeconds >= 0.35 and ConfirmedHitMarkerConfig.ChainWindowSeconds <= 1.25,
	"confirmed hit chain window must reward automatic-fire rhythm without becoming sticky"
)
assert(
	ConfirmedHitMarkerConfig.MinimumRadiusPixels >= 4
		and ConfirmedHitMarkerConfig.MaximumRadiusPixels <= 36
		and ConfirmedHitMarkerConfig.MinimumRadiusPixels < ConfirmedHitMarkerConfig.MaximumRadiusPixels,
	"confirmed hit marker radius bounds drifted"
)
assert(
	ConfirmedHitMarkerConfig.ArmLengthPixels >= 10
		and ConfirmedHitMarkerConfig.ArmLengthPixels <= 28
		and ConfirmedHitMarkerConfig.ArmThicknessPixels >= 2
		and ConfirmedHitMarkerConfig.ArmThicknessPixels <= 5,
	"confirmed hit marker geometry must remain readable and bounded"
)
assert(
	ConfirmedHitMarkerConfig.FadeStartFraction >= 0.2 and ConfirmedHitMarkerConfig.FadeStartFraction <= 0.7,
	"confirmed hit marker fade must preserve a crisp initial confirmation"
)
assert(
	ConfirmedHitMarkerConfig.HotChainThreshold >= 3
		and ConfirmedHitMarkerConfig.BrutalChainThreshold > ConfirmedHitMarkerConfig.HotChainThreshold,
	"confirmed hit marker chain thresholds must escalate monotonically"
)
assert(
	ConfirmedHitMarkerConfig.MaximumRememberedShotIds >= 32 and ConfirmedHitMarkerConfig.MaximumRememberedShotIds <= 256,
	"confirmed hit marker deduplication memory must remain bounded"
)

return table.freeze(ConfirmedHitMarkerConfig)
