-- LootService: Server-authoritative randomized item generation with affix rolling, corruption, set items, and loot cascades
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(ReplicatedStorage.Shared.Config.ItemDefinitions)
local AffixDefs = require(ReplicatedStorage.Shared.Config.AffixDefinitions)
local LootTables = require(ReplicatedStorage.Shared.Config.LootTables)
local ItemTypes = require(ReplicatedStorage.Shared.Types.ItemTypes)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)
local NumberUtility = require(ReplicatedStorage.Shared.Utility.NumberUtility)
local RNGEngine = require(ReplicatedStorage.Shared.Utility.RNGEngine)

local LootService = {}

-- Unique item ID counter
local idCounter = 0
local function generateItemId()
	idCounter += 1
	return "item_" .. tostring(os.clock()) .. "_" .. tostring(idCounter)
end

-- Rolls a single affix for an item
local function rollAffix(itemType, affixType, level, rng)
	rng = rng or Random.new()
	local available = AffixDefs.getAffixesForType(itemType, affixType)
	if #available == 0 then return nil end

	local selected = RandomUtility.choice(available, rng)
	local range = selected.maxRoll - selected.minRoll
	local roll = selected.minRoll + rng:NextNumber() * range

	-- Scale by level (affixes get stronger with higher level items)
	roll = roll * (1 + (level - 1) * 0.05)

	return {
		id = selected.id,
		name = selected.name,
		stat = selected.stat,
		value = NumberUtility.round(roll, 2),
	}
end

-- Generates a single item instance from a definition ID, rarity, and level
-- Now with RNG engine integration: corruption, set items, mystery items, luck-based rolling
function LootService.generateItem(defId, rarity, level, rng, luck)
	rng = rng or Random.new()
	luck = luck or 0
	local def = ItemDefinitions[defId]
	if not def then return nil end

	-- If no rarity specified, roll one using the RNG engine
	if not rarity then
		rarity = RNGEngine.rollRarity(luck, level, rng)
	end
	level = level or 1

	local item = {
		id = generateItemId(),
		defId = defId,
		type = def.type,
		name = def.name,
		rarity = rarity,
		level = level,
		stats = {},
		affixes = {},
		slot = def.slot,
		count = 1,
		isCorrupted = false,
		isMystery = false,
		setItem = nil,
	}

	-- Check for mystery item
	if def.type == "Weapon" or def.type == "Armor" then
		if RNGEngine.rollMysteryItem(rng) then
			item.isMystery = true
			item.displayName = "Mysterious " .. def.name
		end
	end

	-- Apply base stats scaled by level and rarity
	local statMult = RNGEngine.getRarityStatMultiplier(rarity)

	if def.type == "Weapon" then
		-- Add damage variance using gaussian distribution
		local baseDmg = (def.baseDamage or 0) * statMult * (1 + (level - 1) * 0.08)
		local variance = baseDmg * 0.1 -- ±10% variance
		item.stats.damage = math.floor(RandomUtility.gaussian(baseDmg, variance, rng) + 0.5)
		item.stats.damage = math.max(1, item.stats.damage)
		item.stats.speed = NumberUtility.round((def.baseSpeed or 1) * (1 + (level - 1) * 0.02), 2)
		item.stats.range = def.range or 8
		item.stats.damageType = def.damageType or "Physical"
	elseif def.type == "Armor" then
		local baseDef = (def.baseDefense or 0) * statMult * (1 + (level - 1) * 0.08)
		local defVariance = baseDef * 0.1
		item.stats.defense = math.floor(RandomUtility.gaussian(baseDef, defVariance, rng) + 0.5)
		item.stats.defense = math.max(0, item.stats.defense)

		local baseHP = (def.baseHealth or 0) * statMult * (1 + (level - 1) * 0.08)
		local hpVariance = baseHP * 0.1
		item.stats.health = math.floor(RandomUtility.gaussian(baseHP, hpVariance, rng) + 0.5)
		item.stats.health = math.max(0, item.stats.health)

		if def.baseSpeed then
			item.stats.moveSpeed = def.baseSpeed
		end
		if def.baseDamage then
			item.stats.damagePct = def.baseDamage
		end
	elseif def.type == "Consumable" then
		item.stats.healAmount = def.healAmount or 0
	elseif def.type == "Material" or def.type == "Currency" then
		item.stackable = true
	end

	-- Roll affixes based on rarity (from RNG engine)
	local affixCounts = RNGEngine.getRarityAffixCounts(rarity)

	for _ = 1, affixCounts.prefix do
		local affix = rollAffix(def.type, "prefix", level, rng)
		if affix then
			table.insert(item.affixes, affix)
			item.stats[affix.stat] = (item.stats[affix.stat] or 0) + affix.value
		end
	end

	for _ = 1, affixCounts.suffix do
		local affix = rollAffix(def.type, "suffix", level, rng)
		if affix then
			table.insert(item.affixes, affix)
			item.stats[affix.stat] = (item.stats[affix.stat] or 0) + affix.value
		end
	end

	-- Handle corrupted items
	if rarity == "Corrupted" then
		item.isCorrupted = true
		local corruptionEffect = RNGEngine.rollCorruptionEffect(rng)
		if corruptionEffect then
			item.stats[corruptionEffect.stat] = (item.stats[corruptionEffect.stat] or 0) + corruptionEffect.value
			item.corruptionEffect = corruptionEffect
		end
	end

	-- Roll for set item
	if def.type == "Armor" and def.slot then
		local setInfo = RNGEngine.rollSetItem(def.slot, rng)
		if setInfo then
			item.setItem = setInfo
		end
	end

	-- Build display name with affixes (skip if mystery)
	if not item.isMystery then
		local prefixName = ""
		local suffixName = ""
		for _, affix in ipairs(item.affixes) do
			local affixDef = AffixDefs.Affixes[affix.id]
			if affixDef and affixDef.type == "prefix" then
				prefixName = prefixName .. affix.name .. " "
			elseif affixDef then
				suffixName = suffixName .. " " .. affix.name
			end
		end

		local baseName = def.name
		if item.isCorrupted and item.corruptionEffect then
			baseName = item.corruptionEffect.name .. " " .. baseName
		end
		if item.setItem then
			baseName = baseName .. " [" .. item.setItem.setName .. "]"
		end
		item.displayName = prefixName .. baseName .. suffixName
	end

	return item
end

-- Generates loot drops from a loot table
-- Now with loot cascade system and luck integration
function LootService.rollLoot(lootTableId, level, rng, luck, cascadeDepth)
	rng = rng or Random.new()
	luck = luck or 0
	cascadeDepth = cascadeDepth or 0
	local lootTable = LootTables[lootTableId]
	if not lootTable then return nil end

	local result = {
		items = {},
		materials = {},
		gold = 0,
	}

	-- Gold (with variance)
	local baseGold = RandomUtility.int(lootTable.goldRange[1], lootTable.goldRange[2], rng)
	result.gold = math.floor(baseGold * (1 + luck * 0.01) + 0.5)

	-- Materials
	if RandomUtility.chance(lootTable.materialChance, rng) then
		local matEntries = {}
		for _, mat in ipairs(lootTable.materials) do
			table.insert(matEntries, {item = mat, weight = mat.weight})
		end
		local selected = RandomUtility.weighted(matEntries, rng)
		local count = RandomUtility.int(selected.countRange[1], selected.countRange[2], rng)
		table.insert(result.materials, {
			defId = selected.item,
			count = count,
		})
	end

	-- Items
	local guaranteedDrops = lootTable.guaranteedDrops or 0
	local itemEntries = {}
	for _, entry in ipairs(lootTable.items) do
		table.insert(itemEntries, {item = entry, weight = entry.weight})
	end

	-- Roll for guaranteed drops (using RNG engine for rarity rolling)
	for _ = 1, guaranteedDrops do
		local selected = RandomUtility.weighted(itemEntries, rng)
		-- Use RNG engine to potentially upgrade rarity beyond the base
		local item = LootService.generateItem(selected.item, selected.rarity, level, rng, luck)
		if item then table.insert(result.items, item) end
	end

	-- Roll for chance-based drops (with luck modifier)
	local effectiveDropChance = lootTable.dropChance or 0
	if lootTable.dropChance then
		effectiveDropChance = effectiveDropChance * (1 + luck * 0.005)
	end
	if lootTable.dropChance and RandomUtility.chance(effectiveDropChance, rng) then
		local selected = RandomUtility.weighted(itemEntries, rng)
		local item = LootService.generateItem(selected.item, selected.rarity, level, rng, luck)
		if item then table.insert(result.items, item) end

		-- Check for loot cascade (chance to roll again on a better table)
		if RNGEngine.rollCascade(cascadeDepth, rng) then
			local cascadeResult = LootService.rollLoot(lootTableId, level, rng, luck + 20, cascadeDepth + 1)
			if cascadeResult then
				for _, item in ipairs(cascadeResult.items) do
					table.insert(result.items, item)
				end
				for _, mat in ipairs(cascadeResult.materials) do
					table.insert(result.materials, mat)
				end
				result.gold = result.gold + cascadeResult.gold
			end
		end
	end

	return result
end

-- Compresses an item for network transmission
function LootService.serializeItem(item)
	if not item then return nil end
	return {
		id = item.id,
		defId = item.defId,
		type = item.type,
		name = item.name,
		displayName = item.displayName or item.name,
		rarity = item.rarity,
		level = item.level,
		stats = item.stats,
		affixes = item.affixes,
		slot = item.slot,
		count = item.count,
		isCorrupted = item.isCorrupted or false,
		isMystery = item.isMystery or false,
		setItem = item.setItem or nil,
		corruptionEffect = item.corruptionEffect or nil,
	}
end

return LootService