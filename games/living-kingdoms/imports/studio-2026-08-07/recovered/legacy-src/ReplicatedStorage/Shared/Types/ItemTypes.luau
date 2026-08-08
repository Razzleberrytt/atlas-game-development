-- ItemTypes: Shared type definitions for items, equipment, and rarities
local ItemTypes = {}

ItemTypes.ItemRarity = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythic = "Mythic",
	Corrupted = "Corrupted",
}

ItemTypes.EquipmentSlot = {
	Primary = "Primary",
	Secondary = "Secondary",
	Melee = "Melee",
	Helmet = "Helmet",
	Chest = "Chest",
	Legs = "Legs",
	Boots = "Boots",
	Gloves = "Gloves",
	Accessory = "Accessory",
}

ItemTypes.ItemType = {
	Weapon = "Weapon",
	Armor = "Armor",
	Consumable = "Consumable",
	Material = "Material",
	Currency = "Currency",
	Quest = "Quest",
	Key = "Key",
}

ItemTypes.DamageType = {
	Physical = "Physical",
	Fire = "Fire",
	Frost = "Frost",
	Lightning = "Lightning",
	Poison = "Poison",
	Shadow = "Shadow",
	Holy = "Holy",
}

return ItemTypes