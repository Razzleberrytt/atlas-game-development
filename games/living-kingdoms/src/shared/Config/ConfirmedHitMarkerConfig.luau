--!strict

--[[
	Shooter-specific confirmation for server-authored damage impacts. Pattern-hit
	punctuation changes only fixed client-local marker text, color, radius, and
	scale when the accepted ShotFired disclosure includes bounded secondary
	impacts. It cannot establish targeting, damage, death, ammunition, or rewards.
]]

export type PatternPresentationDefinition = {
	Title: string,
	Color: { number },
}

local PatternPresentationsByModeId: { [string]: PatternPresentationDefinition } = {
	ConeCleave = table.freeze({
		Title = "BREACH CLEAVE",
		Color = table.freeze({ 255, 151, 54 }),
	}),
	LinePierce = table.freeze({
		Title = "LINE PIERCE",
		Color = table.freeze({ 115, 221, 255 }),
	}),
}
PatternPresentationsByModeId = table.freeze(PatternPresentationsByModeId)

local function getPatternPresentation(modeId: unknown): PatternPresentationDefinition?
	return if type(modeId) == "string" then PatternPresentationsByModeId[modeId] else nil
end

local ConfirmedHitMarkerConfig = {
	Version = "HROI-0133-v1-authoritative-pattern-hit-punctuation",
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
	MaximumSecondaryImpacts = 3,
	PatternRadiusBonusPixels = 7,
	PatternPulseScale = 1.17,
	PatternPresentationsByModeId = PatternPresentationsByModeId,
	getPatternPresentation = getPatternPresentation,
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
	ConfirmedHitMarkerConfig.MaximumRadiusPixels + ConfirmedHitMarkerConfig.PatternRadiusBonusPixels <= 36,
	"pattern-hit radius must remain inside the fixed marker budget"
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
	"marker deduplication memory must remain bounded"
)
assert(
	ConfirmedHitMarkerConfig.MaximumSecondaryImpacts == 3,
	"pattern-hit punctuation must match the authoritative secondary-impact cap"
)
assert(
	ConfirmedHitMarkerConfig.PatternPulseScale >= 1.05 and ConfirmedHitMarkerConfig.PatternPulseScale <= 1.25,
	"pattern-hit pulse must remain readable and restrained"
)
assert(getPatternPresentation("ConeCleave") ~= nil, "cone cleave requires pattern punctuation")
assert(getPatternPresentation("LinePierce") ~= nil, "line pierce requires pattern punctuation")
assert(getPatternPresentation("SingleTarget") == nil, "single-target hits must retain ordinary confirmation")

return table.freeze(ConfirmedHitMarkerConfig)
