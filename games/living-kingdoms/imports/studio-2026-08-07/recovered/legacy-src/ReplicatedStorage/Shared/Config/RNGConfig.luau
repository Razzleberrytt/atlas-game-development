-- RNGConfig: Central configuration for all RNG systems in LivingKingdoms
-- Controls rarity weights, luck formulas, dungeon modifiers, world events, enemy affixes, boss modifiers

local RNGConfig = {}

-- ===== RARITY WEIGHTS =====
-- Base weights for rolling item rarity. Higher weight = more common.
-- Luck shifts weights toward rarer items.
RNGConfig.BaseRarityWeights = {
	Common = 1000,
	Uncommon = 350,
	Rare = 100,
	Epic = 25,
	Legendary = 5,
	Mythic = 1,
}

-- How much each point of luck increases rare item chances
-- luckMultiplier * luck is added to the weight of each rarity above Common
RNGConfig.LuckMultiplier = 0.5

-- Chance for an item to roll as Corrupted (overrides normal rarity)
-- Corrupted items have powerful stats but a detrimental effect
RNGConfig.CorruptionChance = 0.03 -- 3% base
RNGConfig.CorruptionChancePerLevel = 0.002 -- increases slightly with item level

-- ===== RARITY STAT MULTIPLIERS =====
RNGConfig.RarityStatMultipliers = {
	Common = 1.0,
	Uncommon = 1.25,
	Rare = 1.6,
	Epic = 2.1,
	Legendary = 3.0,
	Mythic = 4.5,
	Corrupted = 3.5,
}

-- ===== RARITY AFFIX COUNTS =====
RNGConfig.RarityAffixCounts = {
	Common = {prefix = 0, suffix = 0},
	Uncommon = {prefix = 1, suffix = 0},
	Rare = {prefix = 1, suffix = 1},
	Epic = {prefix = 2, suffix = 1},
	Legendary = {prefix = 2, suffix = 2},
	Mythic = {prefix = 3, suffix = 2},
	Corrupted = {prefix = 2, suffix = 2},
}

-- ===== CORRUPTION EFFECTS =====
-- Corrupted items get one of these detrimental effects alongside powerful stats
RNGConfig.CorruptionEffects = {
	{id = "health_drain", name = "Draining", stat = "healthPct", value = -0.15, description = "-15% Max Health"},
	{id = "speed_reduction", name = "Heavy", stat = "moveSpeedPct", value = -0.10, description = "-10% Move Speed"},
	{id = "defense_reduction", name = "Fragile", stat = "defensePct", value = -0.15, description = "-15% Defense"},
	{id = "damage_vulnerability", name = "Cursed", stat = "damageTakenPct", value = 0.15, description = "+15% Damage Taken"},
	{id = "life_cost", name = "Bloodied", stat = "lifeStealPct", value = -0.05, description = "-5% Life Steal (can go negative)"},
}

-- ===== DUNGEON MODIFIERS =====
-- Each dungeon instance rolls 0-3 modifiers that change gameplay
RNGConfig.DungeonModifierCount = {min = 1, max = 3}
RNGConfig.DungeonModifierChance = 0.85 -- 85% chance to have at least one modifier

RNGConfig.DungeonModifiers = {
	{id = "fortified", name = "Fortified", description = "Enemies have +25% health", weight = 100,
		effects = {enemyHealthMult = 1.25}},
	{id = "enraged", name = "Enraged", description = "Enemies deal +20% damage", weight = 100,
		effects = {enemyDamageMult = 1.20}},
	{id = "swift", name = "Swift", description = "Enemies move +30% faster", weight = 80,
		effects = {enemySpeedMult = 1.30}},
	{id = "abundant", name = "Abundant", description = "+50% enemy count", weight = 70,
		effects = {enemyCountMult = 1.5}},
	{id = "dim", name = "Dim", description = "Reduced visibility", weight = 60,
		effects = {visibilityMult = 0.6}},
	{id = "treasure", name = "Treasure", description = "+100% gold drops, +1 loot rarity tier", weight = 40,
		effects = {goldMult = 2.0, lootRarityBonus = 1}},
	{id = "volatile", name = "Volatile", description = "Enemies explode on death", weight = 50,
		effects = {volatileEnemies = true}},
	{id = "regenerating", name = "Regenerating", description = "Enemies regenerate health", weight = 45,
		effects = {enemyRegen = true}},
	{id = "shadowed", name = "Shadowed", description = "Enemies have +15% damage reduction", weight = 55,
		effects = {enemyDamageReduction = 0.15}},
	{id = "ancient", name = "Ancient", description = "Boss has +50% health and new attacks", weight = 30,
		effects = {bossHealthMult = 1.5}},
	{id = "cursed", name = "Cursed", description = "Players lose 1 HP per second", weight = 35,
		effects = {playerHpDrain = 1}},
	{id = "lucky", name = "Lucky", description = "+50% experience and +30% loot drop chance", weight = 25,
		effects = {xpMult = 1.5, dropChanceMult = 1.3}},
	{id = "maze", name = "Maze", description = "+50% rooms, more corridors", weight = 40,
		effects = {roomCountMult = 1.5}},
	{id = "elite_guard", name = "Elite Guard", description = "Every room has an elite enemy", weight = 35,
		effects = {eliteInEveryRoom = true}},
}

-- ===== WORLD EVENTS =====
-- Random events that can trigger in the overworld
RNGConfig.WorldEventInterval = {min = 120, max = 300} -- seconds between event checks
RNGConfig.WorldEventChance = 0.4 -- 40% chance to trigger when interval passes

RNGConfig.WorldEvents = {
	{id = "blood_moon", name = "Blood Moon", description = "Enemies are stronger but drop better loot", duration = 180,
		effects = {enemyDamageMult = 1.3, enemyHealthMult = 1.3, lootRarityBonus = 1, goldMult = 1.5}},
	{id = "golden_hour", name = "Golden Hour", description = "All gold drops doubled", duration = 120,
		effects = {goldMult = 2.0}},
	{id = "frost_storm", name = "Frost Storm", description = "Enemies move slower but have frost damage", duration = 150,
		effects = {enemySpeedMult = 0.7, enemyDamageType = "Frost"}},
	{id = "harvest", name = "Harvest", description = "Resource nodes yield double materials", duration = 120,
		effects = {gatherMult = 2.0}},
	{id = "frenzy", name = "Frenzy", description = "All players gain +20% attack speed", duration = 100,
		effects = {playerAttackSpeedMult = 1.2}},
	{id = "invasion", name = "Invasion", description = "Extra enemies spawn in the overworld", duration = 180,
		effects = {extraSpawns = true}},
	{id = "thick_fog", name = "Thick Fog", description = "Visibility reduced, but stealth enemies are revealed", duration = 150,
		effects = {visibilityMult = 0.5}},
	{id = "lucky_stars", name = "Lucky Stars", description = "All players gain +50 luck", duration = 120,
		effects = {luckBonus = 50}},
}

-- ===== ENEMY AFFIXES (random modifiers on normal enemies) =====
-- 10% chance for a normal enemy to spawn with an affix
RNGConfig.EnemyAffixChance = 0.10
RNGConfig.EnemyAffixChancePerDungeonDepth = 0.02 -- increases deeper in dungeons

RNGConfig.EnemyAffixes = {
	{id = "swift", name = "Swift", color = Color3.fromRGB(100, 200, 255),
		effects = {speedMult = 1.4, healthMult = 0.8}},
	{id = "tanky", name = "Tanky", color = Color3.fromRGB(150, 150, 200),
		effects = {healthMult = 1.8, speedMult = 0.8}},
	{id = "berserker", name = "Berserker", color = Color3.fromRGB(255, 80, 80),
		effects = {damageMult = 1.5, healthMult = 0.7}},
	{id = "vampiric", name = "Vampiric", color = Color3.fromRGB(200, 50, 200),
		effects = {lifeSteal = 0.3}},
	{id = "explosive", name = "Explosive", color = Color3.fromRGB(255, 150, 50),
		effects = {explodeOnDeath = true, explosionRadius = 8, explosionDamage = 20}},
	{id = "shielded", name = "Shielded", color = Color3.fromRGB(100, 150, 255),
		effects = {damageReduction = 0.3}},
	{id = "frenzied", name = "Frenzied", color = Color3.fromRGB(255, 200, 50),
		effects = {attackSpeedMult = 1.5, damageMult = 0.8}},
	{id = "phantom", name = "Phantom", color = Color3.fromRGB(150, 150, 150),
		effects = {transparency = 0.5, damageMult = 1.2}},
	{id = "toxic", name = "Toxic", color = Color3.fromRGB(100, 255, 100),
		effects = {poisonDamage = 5, poisonDuration = 3}},
	{id = "giant", name = "Giant", color = Color3.fromRGB(200, 150, 100),
		effects = {scaleMult = 1.8, healthMult = 2.0, speedMult = 0.7}},
}

-- ===== BOSS MODIFIERS =====
-- Bosses roll 1-2 modifiers that change their behavior
RNGConfig.BossModifierCount = {min = 1, max = 2}

RNGConfig.BossModifiers = {
	{id = "extra_phases", name = "Endless", description = "Boss has an additional phase", weight = 30,
		effects = {extraPhases = 1}},
	{id = "twin_boss", name = "Twin", description = "Two weaker bosses instead of one", weight = 20,
		effects = {twinBoss = true, healthMult = 0.6}},
	{id = "enraged", name = "Enraged", description = "Boss deals +40% damage", weight = 50,
		effects = {damageMult = 1.4}},
	{id = "armored", name = "Armored", description = "Boss has +30% damage reduction", weight = 40,
		effects = {damageReduction = 0.3}},
	{id = "healing", name = "Regenerating", description = "Boss heals over time", weight = 35,
		effects = {regen = 5}},
	{id = "minion_summoner", name = "Summoner", description = "Boss summons minions", weight = 45,
		effects = {summonsMinions = true}},
	{id = "frenzied", name = "Frenzied", description = "Boss attacks +50% faster", weight = 40,
		effects = {attackSpeedMult = 1.5}},
	{id = "giant", name = "Colossal", description = "Boss is +50% larger with +80% health", weight = 30,
		effects = {scaleMult = 1.5, healthMult = 1.8}},
	{id = "elemental", name = "Elemental", description = "Boss deals random elemental damage", weight = 50,
		effects = {randomElemental = true}},
	{id = "berserk", name = "Berserk", description = "Boss gains +100% damage below 25% health", weight = 35,
		effects = {berserkThreshold = 0.25, berserkDamageMult = 2.0}},
}

-- ===== QUEST GENERATION =====
RNGConfig.QuestTemplates = {
	{id = "kill", nameTemplate = "Slay the %s", descriptionTemplate = "Defeat %d %s in the %s", 
		objectives = {count = {min = 3, max = 10}}, rewardMult = 1.0},
	{id = "collect", nameTemplate = "Gather %s", descriptionTemplate = "Collect %d %s from the %s",
		objectives = {count = {min = 2, max = 8}}, rewardMult = 0.8},
	{id = "boss", nameTemplate = "Hunt: %s", descriptionTemplate = "Defeat the %s lurking in the %s",
		objectives = {count = 1}, rewardMult = 2.5},
	{id = "explore", nameTemplate = "Explore the %s", descriptionTemplate = "Discover %d locations in the %s",
		objectives = {count = {min = 2, max = 5}}, rewardMult = 1.2},
	{id = "elite", nameTemplate = "Elite Hunt: %s", descriptionTemplate = "Defeat %d elite %s",
		objectives = {count = {min = 1, max = 3}}, rewardMult = 2.0},
}

RNGConfig.QuestTargets = {
	"goblin_scout", "skeleton_archer", "wolf", "ancient_guardian", "elite_brute",
}

RNGConfig.QuestLocations = {
	"overworld", "prototype_dungeon", "combat_path", "hidden_cave",
}

RNGConfig.QuestRewardTypes = {
	{id = "gold", weight = 40, minAmount = 50, maxAmount = 500},
	{id = "experience", weight = 30, minAmount = 100, maxAmount = 1000},
	{id = "item", weight = 20, rarityBoost = 1},
	{id = "material", weight = 10, minAmount = 3, maxAmount = 15},
}

-- ===== COMBAT RNG =====
RNGConfig.CombatRNG = {
	-- Critical hit damage variance
	critDamageMult = {min = 1.3, max = 2.0},
	-- Chance for normal hits to have damage variance (±15%)
	damageVarianceChance = 0.7,
	damageVarianceRange = 0.15,
	-- Chance for elemental procs
	elementalProcChance = 0.15,
	-- Chance for combo hits (hitting twice)
	comboChance = 0.08,
	comboDamageMult = 0.5,
	-- Chance for finishing blow bonus damage
	executeThreshold = 0.15, -- below 15% health
	executeDamageMult = 1.5,
}

-- ===== LOOT CASCADE =====
-- When rolling loot, there's a chance for a "cascade" - rolling again on a better table
RNGConfig.CascadeChance = 0.15 -- 15% chance to cascade to a better table
RNGConfig.CascadeMaxDepth = 2 -- max cascade depth

-- ===== MYSTERY ITEMS =====
-- Chance for loot to be a "mystery item" that reveals its stats when identified
RNGConfig.MysteryItemChance = 0.05

-- ===== SET ITEMS =====
-- Chance for an item to be part of a random set
RNGConfig.SetItemChance = 0.08

RNGConfig.ItemSets = {
	{id = "warrior", name = "Warrior's Resolve", pieces = {"Helmet", "Chest", "Legs", "Boots", "Gloves"},
		bonuses = {
			[2] = {stat = "defense", value = 10, name = "+10 Defense"},
			[3] = {stat = "health", value = 50, name = "+50 Health"},
			[5] = {stat = "damagePct", value = 0.15, name = "+15% Damage"},
		}},
	{id = "mage", name = "Arcane Focus", pieces = {"Helmet", "Chest", "Legs", "Boots", "Accessory"},
		bonuses = {
			[2] = {stat = "critChance", value = 0.05, name = "+5% Crit Chance"},
			[3] = {stat = "fireDamage", value = 15, name = "+15 Fire Damage"},
			[5] = {stat = "damagePct", value = 0.25, name = "+25% Damage"},
		}},
	{id = "rogue", name = "Shadow's Embrace", pieces = {"Helmet", "Chest", "Legs", "Boots", "Gloves"},
		bonuses = {
			[2] = {stat = "moveSpeedPct", value = 0.10, name = "+10% Move Speed"},
			[3] = {stat = "attackSpeedPct", value = 0.15, name = "+15% Attack Speed"},
			[5] = {stat = "critChance", value = 0.15, name = "+15% Crit Chance"},
		}},
	{id = "guardian", name = "Guardian's Oath", pieces = {"Helmet", "Chest", "Legs", "Boots", "Gloves"},
		bonuses = {
			[2] = {stat = "defensePct", value = 0.10, name = "+10% Defense"},
			[3] = {stat = "healthPct", value = 0.15, name = "+15% Health"},
			[5] = {stat = "lifeStealPct", value = 0.05, name = "+5% Life Steal"},
		}},
}

-- ===== WEATHER SYSTEM =====
RNGConfig.WeatherTypes = {
	{id = "clear", name = "Clear Skies", description = "Perfect weather for adventure", weight = 200,
		effects = {}},
	{id = "rain", name = "Rain", description = "Light rain falls across the land", weight = 100,
		effects = {visibilityMult = 0.85}},
	{id = "storm", name = "Thunderstorm", description = "A fierce storm rolls in", weight = 50,
		effects = {visibilityMult = 0.7, enemyDamageMult = 1.1}},
	{id = "fog", name = "Heavy Fog", description = "Thick fog obscures vision", weight = 60,
		effects = {visibilityMult = 0.5}},
	{id = "blood_moon", name = "Blood Moon", description = "Enemies are stronger but drop better loot", weight = 20,
		effects = {enemyDamageMult = 1.3, enemyHealthMult = 1.3, lootRarityBonus = 1, goldMult = 1.5}},
	{id = "golden_hour", name = "Golden Hour", description = "All gold drops doubled", weight = 25,
		effects = {goldMult = 2.0}},
	{id = "lucky_stars", name = "Lucky Stars", description = "All players gain +50 luck", weight = 15,
		effects = {luckBonus = 50}},
	{id = "frost", name = "Frost", description = "Enemies move slower but hit harder", weight = 40,
		effects = {enemySpeedMult = 0.8, enemyDamageMult = 1.15}},
	{id = "harvest", name = "Harvest Moon", description = "Resource nodes yield double materials", weight = 30,
		effects = {gatherMult = 2.0}},
}

-- ===== WANDERING NPCs =====
RNGConfig.WanderingNPCs = {
	{id = "traveling_merchant", name = "Traveling Merchant", type = "merchant",
		description = "A merchant with rare wares at discount prices",
		effects = {discountMult = 0.7, rareItems = true}},
	{id = "wandering_sage", name = "Wandering Sage", type = "buff",
		description = "A sage who can bless you with temporary luck",
		effects = {luckBonus = 30, duration = 300}},
	{id = "mysterious_stranger", name = "Mysterious Stranger", type = "quest",
		description = "A stranger with a special quest offer",
		effects = {specialQuest = true}},
	{id = "lost_traveler", name = "Lost Traveler", type = "reward",
		description = "A lost traveler who rewards those who help them",
		effects = {freeLoot = true, goldReward = 100}},
	{id = "dark_merchant", name = "Shady Dealer", type = "merchant",
		description = "A dealer of exotic and cursed items",
		effects = {cursedItems = true, discountMult = 0.5}},
	{id = "fortune_teller", name = "Fortune Teller", type = "buff",
		description = "Reveals your fortune and grants a luck boost",
		effects = {luckBonus = 50, duration = 180}},
}

return RNGConfig