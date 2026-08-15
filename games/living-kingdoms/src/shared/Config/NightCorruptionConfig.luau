--!strict

-- A short preparation day followed by a long worsening night. Pressure changes
-- continuously; tiers are readable milestones, never discrete combat waves.
-- LightingController owns the rendered day/night clock; this config owns only
-- corruption gameplay timing and disclosed threat modifiers.
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
	DayClockTime = 7.35,
	NightStartClockTime = 19.5,
	DeepNightClockTime = 2.5,
	MaximumThreatBonus = 48,
	EnemySpeedBonusPerTier = 0.045,
	XpBonusPerTier = 0.08,
	MinimumFogEnd = 170,
}

assert(Config.DaylightSeconds < Config.CycleSeconds, "night cycle requires a longer danger phase")
assert(Config.MaximumTier >= 4, "night corruption requires meaningful escalation")
assert(Config.RuntimeFlagOwner ~= "" and Config.RuntimeReenableGate ~= "", "cycle flag requires explicit ownership")

return table.freeze(Config)
