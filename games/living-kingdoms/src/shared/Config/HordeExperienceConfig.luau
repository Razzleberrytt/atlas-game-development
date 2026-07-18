--!strict

--[[
	Configuration for the horde-horror vertical slice. The server owns every
	consequential value derived from this module: pressure, role assignment,
	XP, upgrade eligibility, loot, healing, ammunition grants, and special
	enemy effects. Values are intentionally aggressive so the existing authored
	operation can be evaluated as an intense 8–12 minute combat loop.
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
			Xp = 10,
			SpeedFloor = 12,
			Threat = 1,
			HighlightFill = table.freeze({ 105, 18, 20 }),
			HighlightOutline = table.freeze({ 215, 64, 50 }),
		}),
		Runner = table.freeze({
			Id = "horde.role.runner",
			DisplayName = "Razor Runner",
			Weight = 22,
			Xp = 14,
			SpeedFloor = 19,
			Threat = 2,
			HighlightFill = table.freeze({ 132, 32, 16 }),
			HighlightOutline = table.freeze({ 255, 128, 42 }),
		}),
		Crawler = table.freeze({
			Id = "horde.role.crawler",
			DisplayName = "Grave Crawler",
			Weight = 13,
			Xp = 16,
			SpeedFloor = 16,
			Threat = 2,
			HighlightFill = table.freeze({ 59, 21, 74 }),
			HighlightOutline = table.freeze({ 171, 79, 218 }),
		}),
		Screamer = table.freeze({
			Id = "horde.role.screamer",
			DisplayName = "Choir Screamer",
			Weight = 8,
			Xp = 28,
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
			Xp = 34,
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
			Xp = 60,
			SpeedFloor = 8,
			Threat = 10,
			SecondPhase = true,
			HighlightFill = table.freeze({ 55, 11, 11 }),
			HighlightOutline = table.freeze({ 255, 42, 42 }),
		}),
	}),
	Progression = table.freeze({
		BaseXpToLevel = 80,
		XpGrowthPerLevel = 1.28,
		MaximumLevel = 30,
		KillStreakWindowSeconds = 4,
		MaximumStreakMultiplier = 2,
		StreakMultiplierStep = 0.05,
		UpgradeChoicesPerLevel = 3,
	}),
	Upgrades = table.freeze({
		table.freeze({
			Id = "upgrade.bloodlust",
			Name = "Bloodlust",
			Description = "Every 8 shared kills restores 6 health.",
			MaximumStacks = 4,
		}),
		table.freeze({
			Id = "upgrade.scavenger",
			Name = "Scavenger Instinct",
			Description = "Loot drops become 12% more likely per stack.",
			MaximumStacks = 4,
		}),
		table.freeze({
			Id = "upgrade.ammo_scrounger",
			Name = "Ammo Scrounger",
			Description = "Every 10 shared kills grants reserve ammunition.",
			MaximumStacks = 4,
		}),
		table.freeze({
			Id = "upgrade.trauma_kit",
			Name = "Trauma Kit",
			Description = "Immediately restore 20 health and improve future med loot.",
			MaximumStacks = 3,
		}),
		table.freeze({
			Id = "upgrade.second_wind",
			Name = "Second Wind",
			Description = "Gain one emergency self-recovery charge.",
			MaximumStacks = 2,
		}),
		table.freeze({
			Id = "upgrade.executioner",
			Name = "Executioner",
			Description = "Special enemies award 25% more XP per stack.",
			MaximumStacks = 4,
		}),
	}),
	Loot = table.freeze({
		BaseDropChance = 0.2,
		MaximumWorldDrops = 32,
		LifetimeSeconds = 28,
		InteractionDistanceStuds = 12,
		Kinds = table.freeze({
			Ammo = table.freeze({ Id = "loot.ammo", DisplayName = "Rifle Ammunition", Weight = 44, Amount = 20 }),
			Medical = table.freeze({ Id = "loot.medical", DisplayName = "Trauma Gel", Weight = 28, Amount = 18 }),
			Surge = table.freeze({
				Id = "loot.surge",
				DisplayName = "Adrenal Surge",
				Weight = 18,
				DurationSeconds = 18,
			}),
			Weapon = table.freeze({ Id = "loot.weapon", DisplayName = "Weapon Overcharge", Weight = 10, Amount = 1 }),
		}),
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
assert(HordeExperienceConfig.Progression.UpgradeChoicesPerLevel == 3, "vertical slice expects three choices")
assert(HordeExperienceConfig.Loot.MaximumWorldDrops > 0, "loot cap must be positive")

return table.freeze(HordeExperienceConfig)
