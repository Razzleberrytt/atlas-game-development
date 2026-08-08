-- RNGEngine: Central RNG engine for LivingKingdoms
-- Provides luck-modified rarity rolling, dungeon modifier generation, world events, enemy affixes, boss modifiers, quest generation
-- Used by LootService, DungeonService, EnemyService, CombatService, and RPGServerBootstrap

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RNGConfig = require(ReplicatedStorage.Shared.Config.RNGConfig)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)
local NumberUtility = require(ReplicatedStorage.Shared.Utility.NumberUtility)

local RNGEngine = {}

-- ===== RARITY ROLLING =====

-- Rolls an item rarity based on base weights, modified by luck
-- luck: 0-100+ (higher = better chance for rare items)
-- itemLevel: scales corruption chance
function RNGEngine.rollRarity(luck, itemLevel, rng)
	rng = rng or Random.new()
	luck = luck or 0
	itemLevel = itemLevel or 1

	-- Check for corruption first
	local corruptionChance = RNGConfig.CorruptionChance + (itemLevel - 1) * RNGConfig.CorruptionChancePerLevel
	if RandomUtility.chance(corruptionChance, rng) then
		return "Corrupted"
	end

	-- Build weighted entries with luck modification
	local entries = {}
	local rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"}
	for i, rarity in ipairs(rarities) do
		local weight = RNGConfig.BaseRarityWeights[rarity]
		-- Luck increases weight of rarer items (index > 1)
		if i > 1 then
			weight = weight + (luck * RNGConfig.LuckMultiplier * (i - 1))
		end
		table.insert(entries, {item = rarity, weight = weight})
	end

	return RandomUtility.weighted(entries, rng)
end

-- Gets the stat multiplier for a rarity
function RNGEngine.getRarityStatMultiplier(rarity)
	return RNGConfig.RarityStatMultipliers[rarity] or 1.0
end

-- Gets the affix counts for a rarity
function RNGEngine.getRarityAffixCounts(rarity)
	return RNGConfig.RarityAffixCounts[rarity] or {prefix = 0, suffix = 0}
end

-- ===== CORRUPTION =====

-- Rolls a random corruption effect for a corrupted item
function RNGEngine.rollCorruptionEffect(rng)
	rng = rng or Random.new()
	return RandomUtility.choice(RNGConfig.CorruptionEffects, rng)
end

-- ===== SET ITEMS =====

-- Rolls whether an item should be part of a set, and which set
function RNGEngine.rollSetItem(slot, rng)
	rng = rng or Random.new()
	if not RandomUtility.chance(RNGConfig.SetItemChance, rng) then return nil end

	-- Find sets that include this slot
	local validSets = {}
	for _, set in ipairs(RNGConfig.ItemSets) do
		for _, pieceSlot in ipairs(set.pieces) do
			if pieceSlot == slot then
				table.insert(validSets, set)
				break
			end
		end
	end
	if #validSets == 0 then return nil end

	local selected = RandomUtility.choice(validSets, rng)
	return {
		setId = selected.id,
		setName = selected.name,
	}
end

-- ===== DUNGEON MODIFIERS =====

-- Rolls random modifiers for a dungeon instance
function RNGEngine.rollDungeonModifiers(rng)
	rng = rng or Random.new()

	-- Check if dungeon gets modifiers at all
	if not RandomUtility.chance(RNGConfig.DungeonModifierChance, rng) then
		return {}
	end

	local count = RandomUtility.int(RNGConfig.DungeonModifierCount.min, RNGConfig.DungeonModifierCount.max, rng)
	local selected = {}
	local available = {}
	for _, mod in ipairs(RNGConfig.DungeonModifiers) do
		table.insert(available, mod)
	end

	for _ = 1, count do
		if #available == 0 then break end
		local entries = {}
		for _, mod in ipairs(available) do
			table.insert(entries, {item = mod, weight = mod.weight})
		end
		local chosen = RandomUtility.weighted(entries, rng)
		table.insert(selected, chosen)
		-- Remove from available to prevent duplicates
		for i, mod in ipairs(available) do
			if mod.id == chosen.id then
				table.remove(available, i)
				break
			end
		end
	end

	return selected
end

-- Aggregates dungeon modifier effects into a single effects table
function RNGEngine.aggregateDungeonEffects(modifiers)
	local effects = {}
	for _, mod in ipairs(modifiers) do
		for key, value in pairs(mod.effects) do
			if type(value) == "number" then
				if effects[key] then
					effects[key] = effects[key] * value -- multiplicative stacking
				else
					effects[key] = value
				end
			else
				effects[key] = value
			end
		end
	end
	return effects
end

-- ===== WORLD EVENTS =====

-- Rolls a random world event
function RNGEngine.rollWorldEvent(rng)
	rng = rng or Random.new()
	if not RandomUtility.chance(RNGConfig.WorldEventChance, rng) then return nil end

	local entries = {}
	for _, event in ipairs(RNGConfig.WorldEvents) do
		table.insert(entries, {item = event, weight = 1})
	end
	return RandomUtility.weighted(entries, rng)
end

-- Gets the next world event check interval
function RNGEngine.getNextEventInterval(rng)
	rng = rng or Random.new()
	return RandomUtility.int(RNGConfig.WorldEventInterval.min, RNGConfig.WorldEventInterval.max, rng)
end

-- ===== ENEMY AFFIXES =====

-- Rolls whether a normal enemy gets an affix, and which one
-- dungeonDepth: how deep in the dungeon (0 for overworld)
function RNGEngine.rollEnemyAffix(dungeonDepth, rng)
	rng = rng or Random.new()
	dungeonDepth = dungeonDepth or 0

	local chance = RNGConfig.EnemyAffixChance + (dungeonDepth * RNGConfig.EnemyAffixChancePerDungeonDepth)
	if not RandomUtility.chance(chance, rng) then return nil end

	return RandomUtility.choice(RNGConfig.EnemyAffixes, rng)
end

-- ===== BOSS MODIFIERS =====

-- Rolls 1-2 modifiers for a boss
function RNGEngine.rollBossModifiers(rng)
	rng = rng or Random.new()
	local count = RandomUtility.int(RNGConfig.BossModifierCount.min, RNGConfig.BossModifierCount.max, rng)
	local selected = {}
	local available = {}
	for _, mod in ipairs(RNGConfig.BossModifiers) do
		table.insert(available, mod)
	end

	for _ = 1, count do
		if #available == 0 then break end
		local entries = {}
		for _, mod in ipairs(available) do
			table.insert(entries, {item = mod, weight = mod.weight})
		end
		local chosen = RandomUtility.weighted(entries, rng)
		table.insert(selected, chosen)
		for i, mod in ipairs(available) do
			if mod.id == chosen.id then
				table.remove(available, i)
				break
			end
		end
	end

	return selected
end

-- ===== QUEST GENERATION =====

-- Generates a random quest
function RNGEngine.generateQuest(playerLevel, rng)
	rng = rng or Random.new()

	-- Pick a template
	local template = RandomUtility.choice(RNGConfig.QuestTemplates, rng)
	local target = RandomUtility.choice(RNGConfig.QuestTargets, rng)
	local location = RandomUtility.choice(RNGConfig.QuestLocations, rng)

	-- Roll objective count
	local count
	if template.objectives.count == 1 then
		count = 1
	else
		count = RandomUtility.int(template.objectives.count.min, template.objectives.count.max, rng)
	end

	-- Build quest name and description
	local name = string.format(template.nameTemplate, target)
	local description = string.format(template.descriptionTemplate, count, target, location)

	-- Roll rewards
	local rewards = {}
	local rewardEntries = {}
	for _, rewardType in ipairs(RNGConfig.QuestRewardTypes) do
		table.insert(rewardEntries, {item = rewardType, weight = rewardType.weight})
	end
	local selectedReward = RandomUtility.weighted(rewardEntries, rng)

	if selectedReward.id == "gold" then
		rewards.gold = math.floor(RandomUtility.float(selectedReward.minAmount, selectedReward.maxAmount, rng) * template.rewardMult)
	elseif selectedReward.id == "experience" then
		rewards.experience = math.floor(RandomUtility.float(selectedReward.minAmount, selectedReward.maxAmount, rng) * template.rewardMult)
	elseif selectedReward.id == "item" then
		rewards.itemRarityBonus = selectedReward.rarityBoost or 1
	elseif selectedReward.id == "material" then
		rewards.materials = RandomUtility.int(selectedReward.minAmount, selectedReward.maxAmount, rng)
	end

	return {
		id = "quest_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
		template = template.id,
		name = name,
		description = description,
		target = target,
		location = location,
		requiredCount = count,
		currentCount = 0,
		rewards = rewards,
		level = playerLevel or 1,
		completed = false,
	}
end

-- ===== COMBAT RNG =====

-- Rolls damage variance for a hit
function RNGEngine.rollDamageVariance(baseDamage, rng)
	rng = rng or Random.new()
	if not RandomUtility.chance(RNGConfig.CombatRNG.damageVarianceChance, rng) then
		return baseDamage, false
	end
	local variance = RNGConfig.CombatRNG.damageVarianceRange
	local multiplier = 1.0 + RandomUtility.float(-variance, variance, rng)
	return math.floor(baseDamage * multiplier + 0.5), true
end

-- Rolls critical hit damage multiplier
function RNGEngine.rollCritDamage(rng)
	rng = rng or Random.new()
	return RandomUtility.float(RNGConfig.CombatRNG.critDamageMult.min, RNGConfig.CombatRNG.critDamageMult.max, rng)
end

-- Rolls whether a combo hit occurs (extra hit)
function RNGEngine.rollCombo(rng)
	rng = rng or Random.new()
	if RandomUtility.chance(RNGConfig.CombatRNG.comboChance, rng) then
		return RNGConfig.CombatRNG.comboDamageMult
	end
	return nil
end

-- Rolls execute bonus damage (when enemy is below threshold)
function RNGEngine.rollExecute(enemyHpPct, rng)
	rng = rng or Random.new()
	if enemyHpPct <= RNGConfig.CombatRNG.executeThreshold then
		return RNGConfig.CombatRNG.executeDamageMult
	end
	return 1.0
end

-- Rolls a random elemental proc
function RNGEngine.rollElementalProc(rng)
	rng = rng or Random.new()
	if not RandomUtility.chance(RNGConfig.CombatRNG.elementalProcChance, rng) then return nil end
	local elements = {"Fire", "Frost", "Lightning", "Poison", "Shadow", "Holy"}
	local element = RandomUtility.choice(elements, rng)
	local damage = RandomUtility.int(5, 20, rng)
	return {element = element, damage = damage}
end

-- ===== LOOT CASCADE =====

-- Checks if a loot roll should cascade to a better table
function RNGEngine.rollCascade(depth, rng)
	rng = rng or Random.new()
	depth = depth or 0
	if depth >= RNGConfig.CascadeMaxDepth then return false end
	return RandomUtility.chance(RNGConfig.CascadeChance, rng)
end

-- ===== MYSTERY ITEMS =====

function RNGEngine.rollMysteryItem(rng)
	rng = rng or Random.new()
	return RandomUtility.chance(RNGConfig.MysteryItemChance, rng)
end

-- ===== MONETIZATION RNG =====

-- Rolls a lucky bonus for purchases (sometimes players get extra rewards)
function RNGEngine.rollPurchaseBonus(rng)
	rng = rng or Random.new()
	if not RandomUtility.chance(0.20, rng) then return nil end -- 20% chance

	local bonusTypes = {
		{type = "gold_mult", minMult = 1.2, maxMult = 2.0, weight = 30},
		{type = "extra_items", minCount = 1, maxCount = 3, weight = 25},
		{type = "luck_streak", minAmount = 5, maxAmount = 20, duration = 600, weight = 20},
		{type = "rare_item", weight = 15},
		{type = "double_rewards", weight = 10}, -- Everything doubled
	}

	local entries = {}
	for _, bonus in ipairs(bonusTypes) do
		table.insert(entries, {item = bonus, weight = bonus.weight})
	end
	local selected = RandomUtility.weighted(entries, rng)

	local result = {type = selected.type}
	if selected.type == "gold_mult" then
		result.multiplier = RandomUtility.float(selected.minMult, selected.maxMult, rng)
	elseif selected.type == "extra_items" then
		result.count = RandomUtility.int(selected.minCount, selected.maxCount, rng)
	elseif selected.type == "luck_streak" then
		result.amount = RandomUtility.int(selected.minAmount, selected.maxAmount, rng)
		result.duration = selected.duration
	end

	return result
end

-- Rolls contents for a mystery loot box purchase
function RNGEngine.rollLootBox(boxTier, luck, rng)
	rng = rng or Random.new()
	luck = luck or 0

	local itemCount = RandomUtility.int(2, 5, rng)
	local items = {}

	for i = 1, itemCount do
		local rarity = RNGEngine.rollRarity(luck + (boxTier * 5), boxTier * 5, rng)
		local isMystery = RNGEngine.rollMysteryItem(rng)
		table.insert(items, {
			rarity = rarity,
			mystery = isMystery,
			tier = boxTier,
		})
	end

	-- Chance for bonus gold in the box
	local goldBonus = 0
	if RandomUtility.chance(0.30, rng) then
		goldBonus = RandomUtility.int(100 * boxTier, 500 * boxTier, rng)
	end

	return {items = items, gold = goldBonus}
end

-- ===== WORLD EVENTS =====

-- Rolls a random weather effect for the overworld
function RNGEngine.rollWeather(rng)
	rng = rng or Random.new()
	local weathers = {
		{id = "clear", name = "Clear Skies", weight = 40, effects = {}},
		{id = "rain", name = "Rain", weight = 20, effects = {gatherMult = 1.2}},
		{id = "fog", name = "Heavy Fog", weight = 15, effects = {enemySpawnMult = 1.3, visibility = 0.5}},
		{id = "storm", name = "Thunderstorm", weight = 10, effects = {enemyDamageMult = 1.2, gatherMult = 1.5}},
		{id = "blood_moon", name = "Blood Moon", weight = 5, effects = {enemyDamageMult = 1.5, enemySpawnMult = 2.0, lootLuckBonus = 15}},
		{id = "lucky_wind", name = "Lucky Wind", weight = 10, effects = {luckBonus = 10, gatherMult = 1.3}},
	}

	local entries = {}
	for _, w in ipairs(weathers) do
		table.insert(entries, {item = w, weight = w.weight})
	end
	return RandomUtility.weighted(entries, rng)
end

-- Rolls a random wandering NPC encounter
function RNGEngine.rollWanderingNPC(rng)
	rng = rng or Random.new()
	if not RandomUtility.chance(0.25, rng) then return nil end -- 25% chance

	local npcs = {
		{id = "wandering_merchant", name = "Wandering Merchant", type = "merchant", weight = 30},
		{id = "mysterious_traveler", name = "Mysterious Traveler", type = "quest_giver", weight = 25},
		{id = "injured_adventurer", name = "Injured Adventurer", type = "rescue", weight = 20},
		{id = "treasure_hunter", name = "Treasure Hunter", type = "trade", weight = 15},
		{id = "lost_child", name = "Lost Child", type = "escort", weight = 10},
	}

	local entries = {}
	for _, npc in ipairs(npcs) do
		table.insert(entries, {item = npc, weight = npc.weight})
	end
	return RandomUtility.weighted(entries, rng)
end

-- Rolls a random overworld event (ambient)
function RNGEngine.rollOverworldEvent(rng)
	rng = rng or Random.new()
	if not RandomUtility.chance(0.15, rng) then return nil end

	local events = {
		{id = "meteor_shower", name = "Meteor Shower", effect = "rare_materials", weight = 20},
		{id = "fairy_circle", name = "Fairy Circle", effect = "heal_all", weight = 15},
		{id = "ancient_shrine", name = "Ancient Shrine", effect = "luck_buff", weight = 15},
		{id = "treasure_goblin", name = "Treasure Goblin Sighting", effect = "chase_event", weight = 10},
		{id = "double_rainbow", name = "Double Rainbow", effect = "xp_boost", weight = 20},
		{id = "mysterious_portal", name = "Mysterious Portal", effect = "bonus_dungeon", weight = 10},
		{id = "golden_chest", name = "Golden Chest", effect = "free_loot", weight = 10},
	}

	local entries = {}
	for _, e in ipairs(events) do
		table.insert(entries, {item = e, weight = e.weight})
	end
	return RandomUtility.weighted(entries, rng)
end

return RNGEngine