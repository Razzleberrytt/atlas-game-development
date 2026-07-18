--!strict

--[[
	Configuration for the horde-horror vertical slice pressure runtime. This
	module owns only horde pacing: spawn pressure, role assignment, threat, the
	non-rewarding massacre-streak window, and special-enemy effects.

	Field XP, levels, upgrades, and their tuning live in RunProgressionConfig.
	Ammunition loot lives in EnemyLootConfig. HordeExperienceService reads none
	of those rewards from this module. Values are intentionally aggressive so the
	authored operation can be evaluated as an intense 8–12 minute combat loop.
]]

local HordeExperienceConfig = {
	Version = "HORDE-VS-001-v1",
	Pressure = table.freeze({
		WarmupSeconds = 8,
		EvaluationIntervalSeconds = 0.1,
		StatePublishIntervalSeconds = 0.5,
		BaseSpawnIntervalSeconds = 7,
		MinimumSpawnIntervalSeconds = 2.4,
		BaseSpawnCount = 5,
		MaximumSpawnCount = 16,
		SpawnRingMinimumStuds = 68,
		SpawnRingMaximumStuds = 112,
		ThreatPerMinute = 11,
		ThreatPerLivingEnemy = 0.55,
		ThreatPerKill = 0.08,
		ThreatMaximum = 100,
	}),
	Roles = table.freeze({
		Basic = table.freeze({
			Id = "horde.role.infected",
			DisplayName = "Hollow Infected",
			Weight = 48,
			Xp = 20,
			SpeedFloor = 12,
			Threat = 1,
			HighlightFill = table.freeze({ 105, 18, 20 }),
			HighlightOutline = table.freeze({ 215, 64, 50 }),
		}),
		Runner = table.freeze({
			Id = "horde.role.runner",
			DisplayName = "Razor Runner",
			Weight = 22,
			Xp = 20,
			SpeedFloor = 19,
			Threat = 2,
			HighlightFill = table.freeze({ 132, 32, 16 }),
			HighlightOutline = table.freeze({ 255, 128, 42 }),
		}),
		Crawler = table.freeze({
			Id = "horde.role.crawler",
			DisplayName = "Grave Crawler",
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
			ReinforcementCount = 5,
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

assert(HordeExperienceConfig.Pressure.MinimumSpawnIntervalSeconds > 0, "spawn interval must be positive")
assert(
	HordeExperienceConfig.Pressure.SpawnRingMaximumStuds > HordeExperienceConfig.Pressure.SpawnRingMinimumStuds,
	"spawn ring must have positive width"
)
assert(HordeExperienceConfig.Streak.KillStreakWindowSeconds > 0, "massacre streak window must be positive")

return table.freeze(HordeExperienceConfig)
