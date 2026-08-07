--!strict

-- Canonical initial P4 gameplay-light contract bounds and profile targets.
-- These are validation and performance budgets, not renderer or tool tuning.
local GameplayLightingConfig = {
	SupportedVisibilityProfileIds = table.freeze({
		Dark = "Dark",
		Dim = "Dim",
		Lit = "Lit",
	}),
	MaximumActiveGameplayLocalizedLightsPerClientView = 8,
	MaximumShadowCastingDynamicLightsPerClientView = 2,
	MaximumCosmeticDynamicLightsPerClientView = 24,
	MaximumTemporaryLightParticlesPerClientView = 40,
	MaximumConsequentialLineOfSightChecksPerOperativePerSecond = 10,
	GlobalFourOperativeLineOfSightChecksPerSecond = 40,
	MinimumTemporaryLightLifetimeSeconds = 1,
	MaximumTemporaryLightLifetimeSeconds = 60,
	MinimumCoverageRadiusStuds = 0.1,
	MaximumCoverageRadiusStuds = 64,
	MinimumConeRangeStuds = 0.1,
	MaximumConeRangeStuds = 64,
	MinimumConeAngleDegrees = 1,
	MaximumConeAngleDegrees = 120,
}

assert(
	GameplayLightingConfig.GlobalFourOperativeLineOfSightChecksPerSecond
		== GameplayLightingConfig.MaximumConsequentialLineOfSightChecksPerOperativePerSecond * 4,
	"global line-of-sight profile target must equal the four-operative target"
)
assert(
	GameplayLightingConfig.MinimumTemporaryLightLifetimeSeconds
		<= GameplayLightingConfig.MaximumTemporaryLightLifetimeSeconds,
	"temporary-light lifetime bounds must be ordered"
)
assert(
	GameplayLightingConfig.MinimumCoverageRadiusStuds < GameplayLightingConfig.MaximumCoverageRadiusStuds,
	"radius bounds must be ordered"
)
assert(
	GameplayLightingConfig.MinimumConeRangeStuds < GameplayLightingConfig.MaximumConeRangeStuds,
	"cone range bounds must be ordered"
)
assert(
	GameplayLightingConfig.MinimumConeAngleDegrees < GameplayLightingConfig.MaximumConeAngleDegrees,
	"cone angle bounds must be ordered"
)

return table.freeze(GameplayLightingConfig)
