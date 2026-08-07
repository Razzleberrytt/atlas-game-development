--!strict

-- A short preparation day followed by a long worsening night. Pressure changes
-- continuously; tiers are readable milestones, never discrete combat waves.
local Config = {
	CycleSeconds = 720,
	DaylightSeconds = 120,
	NightTierSeconds = 100,
	MaximumTier = 6,
	DayClockTime = 14.5,
	NightStartClockTime = 19.5,
	DeepNightClockTime = 2.5,
	MaximumThreatBonus = 48,
	EnemySpeedBonusPerTier = 0.045,
	XpBonusPerTier = 0.08,
	MinimumFogEnd = 170,
}

assert(Config.DaylightSeconds < Config.CycleSeconds, "night cycle requires a longer danger phase")
assert(Config.MaximumTier >= 4, "night corruption requires meaningful escalation")

return table.freeze(Config)
