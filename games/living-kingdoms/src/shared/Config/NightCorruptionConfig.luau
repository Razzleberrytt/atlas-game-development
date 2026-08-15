--!strict

-- A short preparation phase followed by a long worsening corruption phase.
-- This config owns gameplay pressure only; EnvironmentVisualConfig owns every
-- rendered day/night value so gameplay state cannot fight global Lighting.
local Config = {
	-- MVP 0.1 gameplay gate. NightCorruptionService publishes tier-zero state
	-- until the daytime biome and enemy-readability Studio acceptance is complete.
	RuntimeEnabled = false,
	RuntimeFlagOwner = "MVP 0.1 environment baseline",
	RuntimeReenableGate = "daytime biome visual and combat-readability Studio acceptance",
	CycleSeconds = 720,
	DaylightSeconds = 120,
	NightTierSeconds = 100,
	MaximumTier = 6,
	MaximumThreatBonus = 48,
	EnemySpeedBonusPerTier = 0.045,
	XpBonusPerTier = 0.08,
}

assert(Config.DaylightSeconds < Config.CycleSeconds, "night cycle requires a longer danger phase")
assert(Config.MaximumTier >= 4, "night corruption requires meaningful escalation")
assert(Config.RuntimeFlagOwner ~= "" and Config.RuntimeReenableGate ~= "", "cycle flag requires explicit ownership")

return table.freeze(Config)
