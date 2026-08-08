-- AffixDefinitions: Prefix and suffix affixes for item generation
local AffixDefinitions = {}

-- ===== RARITY CONFIG =====
AffixDefinitions.RarityConfig = {
	Common = {statMultiplier = 1.0, prefixCount = 0, suffixCount = 0},
	Uncommon = {statMultiplier = 1.25, prefixCount = 1, suffixCount = 0},
	Rare = {statMultiplier = 1.6, prefixCount = 1, suffixCount = 1},
	Epic = {statMultiplier = 2.1, prefixCount = 2, suffixCount = 1},
	Legendary = {statMultiplier = 3.0, prefixCount = 2, suffixCount = 2},
	Mythic = {statMultiplier = 4.5, prefixCount = 3, suffixCount = 2},
	Corrupted = {statMultiplier = 3.5, prefixCount = 2, suffixCount = 2},
}

-- ===== AFFIXES =====
AffixDefinitions.Affixes = {
	-- Prefixes (offensive)
	{id = "sharp", name = "Sharp", type = "prefix", stat = "damage", minRoll = 2, maxRoll = 8, itemTypes = {"Weapon"}},
	{id = "deadly", name = "Deadly", type = "prefix", stat = "damage", minRoll = 5, maxRoll = 15, itemTypes = {"Weapon"}},
	{id = "vicious", name = "Vicious", type = "prefix", stat = "damage", minRoll = 8, maxRoll = 25, itemTypes = {"Weapon"}},
	{id = "brutal", name = "Brutal", type = "prefix", stat = "damage", minRoll = 12, maxRoll = 40, itemTypes = {"Weapon"}},
	{id = "fiery", name = "Fiery", type = "prefix", stat = "fireDamage", minRoll = 3, maxRoll = 12, itemTypes = {"Weapon"}},
	{id = "frozen", name = "Frozen", type = "prefix", stat = "frostDamage", minRoll = 3, maxRoll = 12, itemTypes = {"Weapon"}},
	{id = "shocking", name = "Shocking", type = "prefix", stat = "lightningDamage", minRoll = 3, maxRoll = 12, itemTypes = {"Weapon"}},
	{id = "venomous", name = "Venomous", type = "prefix", stat = "poisonDamage", minRoll = 2, maxRoll = 10, itemTypes = {"Weapon"}},
	{id = "shadowed", name = "Shadowed", type = "prefix", stat = "shadowDamage", minRoll = 4, maxRoll = 15, itemTypes = {"Weapon"}},
	{id = "blessed", name = "Blessed", type = "prefix", stat = "holyDamage", minRoll = 4, maxRoll = 15, itemTypes = {"Weapon"}},
	{id = "swift", name = "Swift", type = "prefix", stat = "attackSpeedPct", minRoll = 0.05, maxRoll = 0.20, itemTypes = {"Weapon"}},
	{id = "precise", name = "Precise", type = "prefix", stat = "critChance", minRoll = 0.02, maxRoll = 0.10, itemTypes = {"Weapon", "Armor"}},
	{id = "deadly_strike", name = "Deadly Strike", type = "prefix", stat = "critDamage", minRoll = 0.10, maxRoll = 0.40, itemTypes = {"Weapon"}},
	{id = "vampiric", name = "Vampiric", type = "prefix", stat = "lifeStealPct", minRoll = 0.02, maxRoll = 0.08, itemTypes = {"Weapon"}},
	{id = "powerful", name = "Powerful", type = "prefix", stat = "damagePct", minRoll = 0.05, maxRoll = 0.20, itemTypes = {"Weapon", "Armor"}},
	{id = "fortified", name = "Fortified", type = "prefix", stat = "defense", minRoll = 3, maxRoll = 12, itemTypes = {"Armor"}},
	{id = "sturdy", name = "Sturdy", type = "prefix", stat = "defense", minRoll = 5, maxRoll = 20, itemTypes = {"Armor"}},
	{id = "vigorous", name = "Vigorous", type = "prefix", stat = "health", minRoll = 10, maxRoll = 40, itemTypes = {"Armor"}},
	{id = "robust", name = "Robust", type = "prefix", stat = "health", minRoll = 20, maxRoll = 80, itemTypes = {"Armor"}},
	{id = "nimble", name = "Nimble", type = "prefix", stat = "moveSpeedPct", minRoll = 0.03, maxRoll = 0.12, itemTypes = {"Armor"}},

	-- Suffixes (utility)
	{id = "of_power", name = "of Power", type = "suffix", stat = "damagePct", minRoll = 0.03, maxRoll = 0.15, itemTypes = {"Weapon", "Armor"}},
	{id = "of_wrath", name = "of Wrath", type = "suffix", stat = "damagePct", minRoll = 0.08, maxRoll = 0.25, itemTypes = {"Weapon"}},
	{id = "of_protection", name = "of Protection", type = "suffix", stat = "defensePct", minRoll = 0.05, maxRoll = 0.20, itemTypes = {"Armor"}},
	{id = "of_vitality", name = "of Vitality", type = "suffix", stat = "healthPct", minRoll = 0.05, maxRoll = 0.20, itemTypes = {"Armor"}},
	{id = "of_haste", name = "of Haste", type = "suffix", stat = "attackSpeedPct", minRoll = 0.05, maxRoll = 0.20, itemTypes = {"Weapon"}},
	{id = "of_swiftness", name = "of Swiftness", type = "suffix", stat = "moveSpeedPct", minRoll = 0.05, maxRoll = 0.15, itemTypes = {"Armor"}},
	{id = "of_precision", name = "of Precision", type = "suffix", stat = "critChance", minRoll = 0.03, maxRoll = 0.12, itemTypes = {"Weapon", "Armor"}},
	{id = "of_leeching", name = "of Leeching", type = "suffix", stat = "lifeStealPct", minRoll = 0.02, maxRoll = 0.08, itemTypes = {"Weapon"}},
	{id = "of_the_giant", name = "of the Giant", type = "suffix", stat = "health", minRoll = 15, maxRoll = 60, itemTypes = {"Armor"}},
	{id = "of_the_bulwark", name = "of the Bulwark", type = "suffix", stat = "defense", minRoll = 5, maxRoll = 25, itemTypes = {"Armor"}},
	{id = "of_fire", name = "of Fire", type = "suffix", stat = "fireDamage", minRoll = 2, maxRoll = 10, itemTypes = {"Weapon"}},
	{id = "of_frost", name = "of Frost", type = "suffix", stat = "frostDamage", minRoll = 2, maxRoll = 10, itemTypes = {"Weapon"}},
	{id = "of_storms", name = "of Storms", type = "suffix", stat = "lightningDamage", minRoll = 2, maxRoll = 10, itemTypes = {"Weapon"}},
	{id = "of_venom", name = "of Venom", type = "suffix", stat = "poisonDamage", minRoll = 2, maxRoll = 8, itemTypes = {"Weapon"}},
	{id = "of_shadow", name = "of Shadow", type = "suffix", stat = "shadowDamage", minRoll = 3, maxRoll = 12, itemTypes = {"Weapon"}},
	{id = "of_light", name = "of Light", type = "suffix", stat = "holyDamage", minRoll = 3, maxRoll = 12, itemTypes = {"Weapon"}},
	{id = "of_fury", name = "of Fury", type = "suffix", stat = "critDamage", minRoll = 0.15, maxRoll = 0.50, itemTypes = {"Weapon"}},
	{id = "of_the_warlord", name = "of the Warlord", type = "suffix", stat = "damagePct", minRoll = 0.10, maxRoll = 0.30, itemTypes = {"Weapon", "Armor"}},
	{id = "of_the_guardian", name = "of the Guardian", type = "suffix", stat = "defensePct", minRoll = 0.08, maxRoll = 0.25, itemTypes = {"Armor"}},
	{id = "of_the_titan", name = "of the Titan", type = "suffix", stat = "healthPct", minRoll = 0.08, maxRoll = 0.25, itemTypes = {"Armor"}},
}

-- Gets all affixes available for a given item type and affix type
function AffixDefinitions.getAffixesForType(itemType, affixType)
	local result = {}
	for _, affix in pairs(AffixDefinitions.Affixes) do
		if affix.type == affixType then
			for _, validType in ipairs(affix.itemTypes) do
				if validType == itemType then
					table.insert(result, affix)
					break
				end
			end
		end
	end
	return result
end

return AffixDefinitions