-- ItemDefinitions: Definitions for all RPG items (weapons, armor, consumables, materials)
local ItemDefinitions = {}

-- ===== WEAPONS =====
ItemDefinitions.rusty_sword = {
	id = "rusty_sword",
	name = "Rusty Sword",
	type = "Weapon",
	slot = "Melee",
	baseDamage = 12,
	baseSpeed = 1.0,
	range = 7,
	damageType = "Physical",
	tier = 1,
}

ItemDefinitions.iron_sword = {
	id = "iron_sword",
	name = "Iron Sword",
	type = "Weapon",
	slot = "Melee",
	baseDamage = 20,
	baseSpeed = 1.0,
	range = 7,
	damageType = "Physical",
	tier = 2,
}

ItemDefinitions.steel_greatsword = {
	id = "steel_greatsword",
	name = "Steel Greatsword",
	type = "Weapon",
	slot = "Primary",
	baseDamage = 35,
	baseSpeed = 0.8,
	range = 8,
	damageType = "Physical",
	tier = 3,
}

ItemDefinitions.dagger = {
	id = "dagger",
	name = "Dagger",
	type = "Weapon",
	slot = "Secondary",
	baseDamage = 8,
	baseSpeed = 1.5,
	range = 5,
	damageType = "Physical",
	tier = 1,
}

ItemDefinitions.war_hammer = {
	id = "war_hammer",
	name = "War Hammer",
	type = "Weapon",
	slot = "Primary",
	baseDamage = 45,
	baseSpeed = 0.6,
	range = 7,
	damageType = "Physical",
	tier = 4,
}

ItemDefinitions.flaming_axe = {
	id = "flaming_axe",
	name = "Flaming Axe",
	type = "Weapon",
	slot = "Primary",
	baseDamage = 30,
	baseSpeed = 0.9,
	range = 7,
	damageType = "Fire",
	tier = 3,
}

ItemDefinitions.frost_spear = {
	id = "frost_spear",
	name = "Frost Spear",
	type = "Weapon",
	slot = "Primary",
	baseDamage = 28,
	baseSpeed = 1.1,
	range = 9,
	damageType = "Frost",
	tier = 3,
}

ItemDefinitions.shadow_blade = {
	id = "shadow_blade",
	name = "Shadow Blade",
	type = "Weapon",
	slot = "Melee",
	baseDamage = 40,
	baseSpeed = 1.2,
	range = 7,
	damageType = "Shadow",
	tier = 4,
}

ItemDefinitions.lightning_rod = {
	id = "lightning_rod",
	name = "Lightning Rod",
	type = "Weapon",
	slot = "Primary",
	baseDamage = 25,
	baseSpeed = 1.3,
	range = 10,
	damageType = "Lightning",
	tier = 3,
}

ItemDefinitions.holy_mace = {
	id = "holy_mace",
	name = "Holy Mace",
	type = "Weapon",
	slot = "Primary",
	baseDamage = 32,
	baseSpeed = 0.95,
	range = 7,
	damageType = "Holy",
	tier = 3,
}

-- ===== ARMOR =====
ItemDefinitions.leather_helmet = {
	id = "leather_helmet",
	name = "Leather Helmet",
	type = "Armor",
	slot = "Helmet",
	baseDefense = 5,
	baseHealth = 10,
	tier = 1,
}

ItemDefinitions.leather_chest = {
	id = "leather_chest",
	name = "Leather Chestplate",
	type = "Armor",
	slot = "Chest",
	baseDefense = 10,
	baseHealth = 20,
	tier = 1,
}

ItemDefinitions.leather_legs = {
	id = "leather_legs",
	name = "Leather Leggings",
	type = "Armor",
	slot = "Legs",
	baseDefense = 7,
	baseHealth = 15,
	tier = 1,
}

ItemDefinitions.leather_boots = {
	id = "leather_boots",
	name = "Leather Boots",
	type = "Armor",
	slot = "Boots",
	baseDefense = 3,
	baseHealth = 5,
	baseSpeed = 1.05,
	tier = 1,
}

ItemDefinitions.leather_gloves = {
	id = "leather_gloves",
	name = "Leather Gloves",
	type = "Armor",
	slot = "Gloves",
	baseDefense = 3,
	baseHealth = 5,
	baseDamage = 0.05,
	tier = 1,
}

ItemDefinitions.iron_helmet = {
	id = "iron_helmet",
	name = "Iron Helmet",
	type = "Armor",
	slot = "Helmet",
	baseDefense = 12,
	baseHealth = 25,
	tier = 2,
}

ItemDefinitions.iron_chest = {
	id = "iron_chest",
	name = "Iron Chestplate",
	type = "Armor",
	slot = "Chest",
	baseDefense = 22,
	baseHealth = 45,
	tier = 2,
}

ItemDefinitions.iron_legs = {
	id = "iron_legs",
	name = "Iron Leggings",
	type = "Armor",
	slot = "Legs",
	baseDefense = 16,
	baseHealth = 30,
	tier = 2,
}

ItemDefinitions.iron_boots = {
	id = "iron_boots",
	name = "Iron Boots",
	type = "Armor",
	slot = "Boots",
	baseDefense = 8,
	baseHealth = 15,
	baseSpeed = 1.03,
	tier = 2,
}

ItemDefinitions.iron_gloves = {
	id = "iron_gloves",
	name = "Iron Gloves",
	type = "Armor",
	slot = "Gloves",
	baseDefense = 8,
	baseHealth = 15,
	baseDamage = 0.08,
	tier = 2,
}

ItemDefinitions.steel_helmet = {
	id = "steel_helmet",
	name = "Steel Helmet",
	type = "Armor",
	slot = "Helmet",
	baseDefense = 20,
	baseHealth = 40,
	tier = 3,
}

ItemDefinitions.steel_chest = {
	id = "steel_chest",
	name = "Steel Chestplate",
	type = "Armor",
	slot = "Chest",
	baseDefense = 35,
	baseHealth = 70,
	tier = 3,
}

ItemDefinitions.steel_legs = {
	id = "steel_legs",
	name = "Steel Leggings",
	type = "Armor",
	slot = "Legs",
	baseDefense = 28,
	baseHealth = 50,
	tier = 3,
}

ItemDefinitions.steel_boots = {
	id = "steel_boots",
	name = "Steel Boots",
	type = "Armor",
	slot = "Boots",
	baseDefense = 15,
	baseHealth = 25,
	baseSpeed = 1.02,
	tier = 3,
}

ItemDefinitions.steel_gloves = {
	id = "steel_gloves",
	name = "Steel Gloves",
	type = "Armor",
	slot = "Gloves",
	baseDefense = 15,
	baseHealth = 25,
	baseDamage = 0.10,
	tier = 3,
}

ItemDefinitions.ring_of_power = {
	id = "ring_of_power",
	name = "Ring of Power",
	type = "Armor",
	slot = "Accessory",
	baseDefense = 0,
	baseHealth = 0,
	baseDamage = 0.15,
	tier = 3,
}

ItemDefinitions.amulet_of_vitality = {
	id = "amulet_of_vitality",
	name = "Amulet of Vitality",
	type = "Armor",
	slot = "Accessory",
	baseDefense = 5,
	baseHealth = 50,
	tier = 3,
}

-- ===== CONSUMABLES =====
ItemDefinitions.health_potion = {
	id = "health_potion",
	name = "Health Potion",
	type = "Consumable",
	slot = nil,
	healAmount = 50,
	tier = 1,
}

ItemDefinitions.greater_health_potion = {
	id = "greater_health_potion",
	name = "Greater Health Potion",
	type = "Consumable",
	slot = nil,
	healAmount = 120,
	tier = 2,
}

ItemDefinitions.elixir_of_rage = {
	id = "elixir_of_rage",
	name = "Elixir of Rage",
	type = "Consumable",
	slot = nil,
	healAmount = 0,
	tier = 2,
}

-- ===== MATERIALS =====
ItemDefinitions.wood = {id = "wood", name = "Wood", type = "Material", slot = nil, tier = 1}
ItemDefinitions.stone = {id = "stone", name = "Stone", type = "Material", slot = nil, tier = 1}
ItemDefinitions.iron_ore = {id = "iron_ore", name = "Iron Ore", type = "Material", slot = nil, tier = 1}
ItemDefinitions.enemy_essence = {id = "enemy_essence", name = "Enemy Essence", type = "Material", slot = nil, tier = 2}
ItemDefinitions.crystal_shard = {id = "crystal_shard", name = "Crystal Shard", type = "Material", slot = nil, tier = 3}
ItemDefinitions.shadow_essence = {id = "shadow_essence", name = "Shadow Essence", type = "Material", slot = nil, tier = 4}

return ItemDefinitions