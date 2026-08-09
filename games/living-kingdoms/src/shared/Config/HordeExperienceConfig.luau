--!strict

--[[
	Configuration for the horde-horror vertical slice pressure runtime. This
	module owns only horde pacing: spawn pressure, role assignment, threat, the
	non-rewarding massacre-streak window, and special-enemy effects.

	Field XP, levels, upgrades, and their tuning live in RunProgressionConfig.
	Ammunition loot lives in EnemyLootConfig. HordeExperienceService reads none
	of those rewards from this module.

	The v2 curve deliberately lets the canonical EnemyDirector create the first
	contact before the additional horde injector comes online. A solo operative
	should have time to secure the four confirmed kills required for the first
	run upgrade before pressure reaches its likely-wipe phase, while successful
	kill throughput accelerates later escalation.
]]

local HordeExperienceConfig = {
	Version = "HORDE-VS-001-v3-predator-pressure",
	Pressure = table.freeze({
		-- EnemyDirector already begins baseline contact at roughly nine seconds.
		-- Delay the additive horde injector so both pressure owners do not front-load
		-- nine enemies into the opening seconds of a solo run.
		WarmupSeconds = 45,
		EvaluationIntervalSeconds = 0.1,
		StatePublishIntervalSeconds = 0.5,
		BaseSpawnIntervalSeconds = 20,
		MinimumSpawnIntervalSeconds = 12,
		BaseSpawnCount = 1,
		MaximumSpawnCount = 3,
		SpawnRingMinimumStuds = 68,
		SpawnRingMaximumStuds = 112,
		ThreatPerMinute = 9,
		ThreatPerLivingEnemy = 0.4,
		-- Strong play should eventually summon harder waves instead of leaving the
		-- curve driven almost entirely by elapsed time and existing population.
		ThreatPerKill = 0.3,
		ThreatMaximum = 100,
	}),
	Roles = table.freeze({
		Basic = table.freeze({
			Id = "horde.role.infected",
			DisplayName = "Exclusion Stalker",
			Weight = 48,
			Xp = 20,
			SpeedFloor = 12,
			Threat = 1,
			HighlightFill = table.freeze({ 105, 18, 20 }),
			HighlightOutline = table.freeze({ 215, 64, 50 }),
		}),
		Runner = table.freeze({
			Id = "horde.role.runner",
			DisplayName = "Rushing Stalker",
			Weight = 22,
			Xp = 20,
			SpeedFloor = 19,
			Threat = 2,
			HighlightFill = table.freeze({ 132, 32, 16 }),
			HighlightOutline = table.freeze({ 255, 128, 42 }),
		}),
		Crawler = table.freeze({
			Id = "horde.role.crawler",
			DisplayName = "Low Stalker",
			Weight = 13,
			Xp = 20,
			SpeedFloor = 16,
			Threat = 2,
			HighlightFill = table.freeze({ 59, 21, 74 }),
			HighlightOutline = table.freeze({ 171, 79, 218 }),
		}),
		Screamer = table.freeze({
			Id = "horde.role.screamer",
			DisplayName = "Choir Screamer",
			Weight = 8,
			Xp = 20,
			SpeedFloor = 10,
			Threat = 5,
			SpecialIntervalSeconds = 12,
			ReinforcementCount = 1,
			HighlightFill = table.freeze({ 95, 75, 7 }),
			HighlightOutline = table.freeze({ 255, 224, 64 }),
		}),
		Bloater = table.freeze({
			Id = "horde.role.bloater",
			DisplayName = "Rot Bloater",
			Weight = 6,
			Xp = 20,
			SpeedFloor = 9,
			Threat = 6,
			DeathBurstRadiusStuds = 20,
			DeathBurstDamage = 18,
			HighlightFill = table.freeze({ 38, 83, 27 }),
			HighlightOutline = table.freeze({ 121, 225, 78 }),
		}),
		Brute = table.freeze({
			Id = "horde.role.brute",
			DisplayName = "Grief Brute",
			Weight = 3,
			Xp = 20,
			SpeedFloor = 8,
			Threat = 10,
			SecondPhase = true,
			HighlightFill = table.freeze({ 55, 11, 11 }),
			HighlightOutline = table.freeze({ 255, 42, 42 }),
		}),
	}),
	Streak = table.freeze({
		-- Consecutive kills inside this window advance the non-rewarding massacre
		-- display. It grants no XP, loot, healing, or combat bonus of any kind.
		KillStreakWindowSeconds = 4,
	}),
	Feedback = table.freeze({
		BloodBurstParticles = 16,
		BloodLifetimeSeconds = 4,
		EventFeedSeconds = 3.5,
	}),
}

assert(
	HordeExperienceConfig.Pressure.WarmupSeconds >= 30 and HordeExperienceConfig.Pressure.WarmupSeconds <= 60,
	"the additive horde injector must preserve a bounded first-upgrade window"
)
assert(
	HordeExperienceConfig.Pressure.BaseSpawnCount > 0 and HordeExperienceConfig.Pressure.BaseSpawnCount <= 4,
	"opening horde injections must remain threatening without front-loading the solo wipe"
)
assert(HordeExperienceConfig.Pressure.MinimumSpawnIntervalSeconds >= 10, "minimum horde cadence must remain readable")
assert(
	HordeExperienceConfig.Pressure.BaseSpawnIntervalSeconds > HordeExperienceConfig.Pressure.MinimumSpawnIntervalSeconds,
	"threat escalation must shorten horde cadence from a slower baseline"
)
assert(
	HordeExperienceConfig.Pressure.MaximumSpawnCount >= HordeExperienceConfig.Pressure.BaseSpawnCount
		and HordeExperienceConfig.Pressure.MaximumSpawnCount <= 12,
	"horde burst size requires a strict vertical-slice ceiling"
)
assert(
	HordeExperienceConfig.Pressure.SpawnRingMaximumStuds > HordeExperienceConfig.Pressure.SpawnRingMinimumStuds,
	"spawn ring must have positive width"
)
assert(HordeExperienceConfig.Streak.KillStreakWindowSeconds > 0, "massacre streak window must be positive")

return table.freeze(HordeExperienceConfig)
