-- LootTables: Weighted loot tables for different drop sources
local LootTables = {}

-- ===== ENEMY LOOT TABLES =====
LootTables.goblin = {
	goldRange = {5, 20},
	materialChance = 0.30,
	materials = {
		{id = "wood", weight = 50, countRange = {1, 3}},
		{id = "stone", weight = 30, countRange = {1, 2}},
		{id = "enemy_essence", weight = 20, countRange = {1, 1}},
	},
	items = {
		{id = "rusty_sword", weight = 30, rarity = "Common"},
		{id = "dagger", weight = 25, rarity = "Common"},
		{id = "leather_helmet", weight = 20, rarity = "Common"},
		{id = "leather_boots", weight = 15, rarity = "Common"},
		{id = "health_potion", weight = 10, rarity = "Common"},
	},
	guaranteedDrops = 0,
	dropChance = 0.15,
}

LootTables.skeleton = {
	goldRange = {10, 30},
	materialChance = 0.35,
	materials = {
		{id = "stone", weight = 40, countRange = {1, 3}},
		{id = "enemy_essence", weight = 35, countRange = {1, 2}},
		{id = "iron_ore", weight = 25, countRange = {1, 2}},
	},
	items = {
		{id = "iron_sword", weight = 25, rarity = "Uncommon"},
		{id = "dagger", weight = 20, rarity = "Common"},
		{id = "leather_chest", weight = 20, rarity = "Common"},
		{id = "leather_legs", weight = 15, rarity = "Common"},
		{id = "health_potion", weight = 20, rarity = "Common"},
	},
	guaranteedDrops = 0,
	dropChance = 0.20,
}

LootTables.wolf = {
	goldRange = {3, 15},
	materialChance = 0.25,
	materials = {
		{id = "enemy_essence", weight = 60, countRange = {1, 2}},
		{id = "wood", weight = 40, countRange = {1, 2}},
	},
	items = {
		{id = "leather_gloves", weight = 30, rarity = "Common"},
		{id = "leather_boots", weight = 25, rarity = "Common"},
		{id = "health_potion", weight = 20, rarity = "Common"},
		{id = "dagger", weight = 25, rarity = "Common"},
	},
	guaranteedDrops = 0,
	dropChance = 0.12,
}

LootTables.elite = {
	goldRange = {30, 80},
	materialChance = 0.60,
	materials = {
		{id = "enemy_essence", weight = 40, countRange = {2, 5}},
		{id = "iron_ore", weight = 30, countRange = {2, 4}},
		{id = "crystal_shard", weight = 20, countRange = {1, 2}},
		{id = "shadow_essence", weight = 10, countRange = {1, 1}},
	},
	items = {
		{id = "steel_greatsword", weight = 15, rarity = "Rare"},
		{id = "flaming_axe", weight = 15, rarity = "Rare"},
		{id = "frost_spear", weight = 15, rarity = "Rare"},
		{id = "iron_chest", weight = 20, rarity = "Uncommon"},
		{id = "iron_helmet", weight = 15, rarity = "Uncommon"},
		{id = "ring_of_power", weight = 10, rarity = "Rare"},
		{id = "greater_health_potion", weight = 10, rarity = "Uncommon"},
	},
	guaranteedDrops = 1,
	dropChance = 0.40,
}

LootTables.boss = {
	goldRange = {100, 300},
	materialChance = 0.90,
	materials = {
		{id = "enemy_essence", weight = 30, countRange = {5, 15}},
		{id = "crystal_shard", weight = 30, countRange = {3, 8}},
		{id = "shadow_essence", weight = 25, countRange = {2, 5}},
		{id = "iron_ore", weight = 15, countRange = {5, 10}},
	},
	items = {
		{id = "war_hammer", weight = 15, rarity = "Epic"},
		{id = "shadow_blade", weight = 15, rarity = "Epic"},
		{id = "steel_chest", weight = 15, rarity = "Rare"},
		{id = "steel_legs", weight = 15, rarity = "Rare"},
		{id = "amulet_of_vitality", weight = 10, rarity = "Rare"},
		{id = "ring_of_power", weight = 10, rarity = "Rare"},
		{id = "greater_health_potion", weight = 10, rarity = "Uncommon"},
		{id = "elixir_of_rage", weight = 10, rarity = "Rare"},
	},
	guaranteedDrops = 2,
	dropChance = 0.80,
}

-- ===== DUNGEON CHEST TABLES =====
LootTables.dungeon_chest = {
	goldRange = {20, 60},
	materialChance = 0.50,
	materials = {
		{id = "iron_ore", weight = 35, countRange = {2, 5}},
		{id = "enemy_essence", weight = 35, countRange = {2, 4}},
		{id = "crystal_shard", weight = 20, countRange = {1, 2}},
		{id = "wood", weight = 10, countRange = {3, 6}},
	},
	items = {
		{id = "iron_sword", weight = 20, rarity = "Uncommon"},
		{id = "iron_helmet", weight = 15, rarity = "Uncommon"},
		{id = "iron_boots", weight = 15, rarity = "Uncommon"},
		{id = "health_potion", weight = 20, rarity = "Common"},
		{id = "dagger", weight = 15, rarity = "Common"},
		{id = "leather_chest", weight = 15, rarity = "Common"},
	},
	guaranteedDrops = 1,
	dropChance = 0.30,
}

LootTables.secret_area = {
	goldRange = {50, 150},
	materialChance = 0.70,
	materials = {
		{id = "crystal_shard", weight = 40, countRange = {2, 5}},
		{id = "shadow_essence", weight = 30, countRange = {1, 3}},
		{id = "enemy_essence", weight = 30, countRange = {3, 8}},
	},
	items = {
		{id = "flaming_axe", weight = 20, rarity = "Rare"},
		{id = "frost_spear", weight = 20, rarity = "Rare"},
		{id = "lightning_rod", weight = 15, rarity = "Rare"},
		{id = "holy_mace", weight = 15, rarity = "Rare"},
		{id = "steel_helmet", weight = 15, rarity = "Uncommon"},
		{id = "amulet_of_vitality", weight = 15, rarity = "Rare"},
	},
	guaranteedDrops = 1,
	dropChance = 0.50,
}

return LootTables