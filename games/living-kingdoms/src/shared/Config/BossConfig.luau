--!strict

--[[
	P9-0103 shared balance home for The Progenitor boss. Every consequential value
	is server-owned and configuration-driven, mirroring EnemyConfig. These are
	prototype authoring-intent values, not promises: the P12 balance pass confirms
	them against evidence.

	The boss reuses the production enemy owner for identity, health, damage, and
	cleanup (P9-0104). The values here define the phase machine: health thresholds,
	the Slam attack and its post-Slam exposure windows, the Brood add surge, and the
	spore-shroud / Collapse-darkness visibility reductions.
]]

local EnemyConfig = require(script.Parent.EnemyConfig)
local BossContracts = require(script.Parent.Parent.Combat.BossContracts)

local BossConfig = {
	Version = "P9-0103-v1",
	Progenitor = table.freeze({
		ArchetypeId = BossContracts.BossArchetypeIds.Progenitor,
		DisplayName = "The Progenitor",
		-- A substantial pool the squad chips only during exposure windows, so the
		-- fight is paced by rhythm and discipline, not raw damage-per-second.
		MaximumHealth = 900,
		-- Phase thresholds as fractions of maximum health. Strictly ordered.
		BroodHealthFraction = 0.66,
		CollapseHealthFraction = 0.33,
	}),
	Slam = table.freeze({
		-- A heavy telegraphed AoE centred on the boss at the clearing centre.
		RadiusStuds = 22,
		Damage = 26,
	}),
	Brood = table.freeze({
		-- One bounded add surge on entering Brood, within the existing population budget.
		SurgeCount = 8,
	}),
	Visibility = table.freeze({
		-- The Brood spore shroud shrinks operative gameplay visibility. Collapse is
		-- dark only when the P8 extraction floodlights were not repaired.
		ShroudRadiusStuds = 34,
		CollapseDarkRadiusStuds = 44,
	}),
	-- Per-phase Slam cadence and exposure windows. Later phases enrage: shorter
	-- windups, tighter cooldowns, and shorter exposure windows.
	Phases = table.freeze({
		Carapace = table.freeze({
			SlamWindupSeconds = 1.2,
			SlamCooldownSeconds = 6,
			ExposureWindowSeconds = 3,
		}),
		Brood = table.freeze({
			SlamWindupSeconds = 1,
			SlamCooldownSeconds = 5,
			ExposureWindowSeconds = 2.5,
		}),
		Collapse = table.freeze({
			SlamWindupSeconds = 0.8,
			SlamCooldownSeconds = 3.5,
			ExposureWindowSeconds = 2,
		}),
	}),
}

local progenitor = BossConfig.Progenitor
local slam = BossConfig.Slam
local brood = BossConfig.Brood
local visibility = BossConfig.Visibility
local phases = BossConfig.Phases

assert(progenitor.MaximumHealth > 0, "boss health must be positive")
assert(
	progenitor.CollapseHealthFraction > 0
		and progenitor.CollapseHealthFraction < progenitor.BroodHealthFraction
		and progenitor.BroodHealthFraction < 1,
	"phase health thresholds must be strictly ordered inside (0, 1)"
)
assert(slam.RadiusStuds > 0, "the Slam radius must be positive")
assert(slam.Damage > 0 and slam.Damage < 100, "one Slam must never down a full-health operative outright")
assert(
	brood.SurgeCount > 0 and brood.SurgeCount <= EnemyConfig.Population.AbsoluteMaximumConcurrent,
	"the Brood surge must be positive and fit inside the population budget"
)
local normalVisibility = EnemyConfig.Combat.GameplayVisibilityRadiusStuds
assert(
	visibility.ShroudRadiusStuds > 0 and visibility.ShroudRadiusStuds < normalVisibility,
	"the shroud must reduce, not raise, gameplay visibility"
)
assert(
	visibility.CollapseDarkRadiusStuds > 0 and visibility.CollapseDarkRadiusStuds < normalVisibility,
	"Collapse darkness must reduce, not raise, gameplay visibility"
)

local orderedPhases = { "Carapace", "Brood", "Collapse" }
local previousWindup = math.huge
local previousCooldown = math.huge
local previousExposure = math.huge
for _, phaseName in orderedPhases do
	local phase = phases[phaseName]
	assert(phase ~= nil, "every combat phase needs a tuning entry: " .. phaseName)
	assert(
		phase.SlamWindupSeconds >= EnemyConfig.EvaluationIntervalSeconds,
		"the Slam windup must be visible on the enemy evaluation pass: " .. phaseName
	)
	assert(phase.SlamCooldownSeconds > 0, "the Slam cooldown must be positive: " .. phaseName)
	assert(
		phase.SlamWindupSeconds < phase.SlamCooldownSeconds,
		"the Slam windup must be shorter than its cooldown: " .. phaseName
	)
	assert(
		phase.ExposureWindowSeconds > 0 and phase.ExposureWindowSeconds < phase.SlamCooldownSeconds,
		"the exposure window must be positive and close before the next Slam: " .. phaseName
	)
	-- Enrage is monotonic: each later phase is no slower and no more forgiving.
	assert(phase.SlamWindupSeconds <= previousWindup, "later phases must not lengthen the Slam windup: " .. phaseName)
	assert(phase.SlamCooldownSeconds <= previousCooldown, "later phases must not relax the Slam cadence: " .. phaseName)
	assert(
		phase.ExposureWindowSeconds <= previousExposure,
		"later phases must not lengthen the exposure window: " .. phaseName
	)
	previousWindup = phase.SlamWindupSeconds
	previousCooldown = phase.SlamCooldownSeconds
	previousExposure = phase.ExposureWindowSeconds
end

return table.freeze(BossConfig)
