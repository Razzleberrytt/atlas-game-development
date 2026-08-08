-- InventoryService: Server-authoritative inventory and equipment management
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemTypes = require(ReplicatedStorage.Shared.Types.ItemTypes)
local ItemDefinitions = require(ReplicatedStorage.Shared.Config.ItemDefinitions)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)

local InventoryService = {}

local MAX_INVENTORY_SLOTS = 24

-- RNG dismantling config
local DISMANTLE_CRIT_CHANCE = 0.10  -- 10% chance for critical dismantle (double essence)
local DISMANTLE_BONUS_MAT_CHANCE = 0.15  -- 15% chance for bonus rare material
local DISMANTLE_LUCK_SCALING = 0.002  -- Each luck point adds 0.2% to crit chance
local rng = Random.new()

-- Rare bonus materials that can drop from dismantling
local RARE_BONUS_MATERIALS = {
	{id = "arcane_shard", name = "Arcane Shard", rarity = "Rare", weight = 30},
	{id = "crystallized_essence", name = "Crystallized Essence", rarity = "Epic", weight = 15},
	{id = "ancient_fragment", name = "Ancient Fragment", rarity = "Legendary", weight = 5},
	{id = "refined_ore", name = "Refined Ore", rarity = "Uncommon", weight = 50},
}

-- In-memory player data (loaded by PlayerDataService, cached here)
local playerData = {}

-- Sets the player data reference (called by PlayerDataService on load)
function InventoryService.setPlayerData(player, data)
	playerData[player.UserId] = data
end

function InventoryService.getPlayerData(player)
	return playerData[player.UserId]
end

function InventoryService.clearPlayerData(player)
	playerData[player.UserId] = nil
end

-- Adds an item to the player's inventory
-- Returns true if successful, false if inventory is full
function InventoryService.addItem(player, item)
	local data = playerData[player.UserId]
	if not data then return false end

	-- Check if stackable
	local def = ItemDefinitions[item.defId]
	if def and def.stackable and item.count then
		-- Try to find an existing stack
		for slot, existing in ipairs(data.inventory) do
			if existing and existing.defId == item.defId then
				local maxStack = def.maxStack or 99
				if existing.count < maxStack then
					existing.count = math.min(existing.count + item.count, maxStack)
					return true, slot
				end
			end
		end
	end

	-- Find an empty slot
	for i = 1, MAX_INVENTORY_SLOTS do
		if not data.inventory[i] then
			data.inventory[i] = item
			return true, i
		
		end
	end

	return false -- inventory full
end

-- Removes an item from a specific slot
function InventoryService.removeItem(player, slot)
	local data = playerData[player.UserId]
	if not data then return false end
	local item = data.inventory[slot]
	if not item then return false end
	data.inventory[slot] = nil
	return true, item
end

-- Removes a quantity of a material from inventory
function InventoryService.removeMaterial(player, defId, count)
	local data = playerData[player.UserId]
	if not data then return false end

	local remaining = count
	for slot, item in ipairs(data.inventory) do
		if item and item.defId == defId then
			if item.count <= remaining then
				remaining -= item.count
				data.inventory[slot] = nil
			else
				item.count -= remaining
				remaining = 0
			end
			if remaining <= 0 then break end
		end
	end

	return remaining <= 0
end

-- Gets the count of a specific material in inventory
function InventoryService.getItemCount(player, defId)
	local data = playerData[player.UserId]
	if not data then return 0 end

	local count = 0
	for _, item in ipairs(data.inventory) do
		if item and item.defId == defId then
			count += item.count or 1
		end
	end
	return count
end

-- Equips an item from inventory to equipment slot
function InventoryService.equipItem(player, slot)
	local data = playerData[player.UserId]
	if not data then return false, "No player data" end

	local item = data.inventory[slot]
	if not item then return false, "No item in slot" end

	local equipSlot = item.slot
	if not equipSlot then return false, "Item is not equippable" end

	-- Swap: put current equipment back in inventory
	local current = data.equipment[equipSlot]
	data.equipment[equipSlot] = item
	data.inventory[slot] = current

	return true, equipSlot
end

-- Unequips an item from equipment slot back to inventory
function InventoryService.unequipItem(player, equipSlot)
	local data = playerData[player.UserId]
	if not data then return false, "No player data" end

	local item = data.equipment[equipSlot]
	if not item then return false, "No item equipped" end

	-- Find empty inventory slot
	for i = 1, MAX_INVENTORY_SLOTS do
		if not data.inventory[i] then
			data.inventory[i] = item
			data.equipment[equipSlot] = nil
			return true, i
		
		end
	end

	return false, "Inventory full"
end

-- Dismantles an item for materials (with RNG bonuses)
function InventoryService.dismantleItem(player, slot)
	local data = playerData[player.UserId]
	if not data then return false end

	local item = data.inventory[slot]
	if not item then return false end

	-- Give essence based on rarity
	local essenceMap = {
		Common = 1, Uncommon = 2, Rare = 4, Epic = 8, Legendary = 15, Mythic = 25, Corrupted = 40,
	}
	local essenceCount = essenceMap[item.rarity] or 1

	-- RNG: Critical dismantle (double essence)
	local luck = PlayerDataTypes.getEffectiveLuck(data)
	local critChance = DISMANTLE_CRIT_CHANCE + (luck * DISMANTLE_LUCK_SCALING)
	local isCrit = RandomUtility.chance(critChance, rng)
	if isCrit then
		essenceCount = essenceCount * 2
	end

	-- RNG: Bonus rare material
	local bonusMaterial = nil
	local bonusMatChance = DISMANTLE_BONUS_MAT_CHANCE + (luck * 0.001)
	-- Higher rarity items have better chance for bonus materials
	local rarityBonus = {Common = 0, Uncommon = 0.05, Rare = 0.10, Epic = 0.15, Legendary = 0.25, Mythic = 0.35, Corrupted = 0.50}
	bonusMatChance = bonusMatChance + (rarityBonus[item.rarity] or 0)

	if RandomUtility.chance(bonusMatChance, rng) then
		local entries = {}
		for _, mat in ipairs(RARE_BONUS_MATERIALS) do
			table.insert(entries, {item = mat, weight = mat.weight})
		end
		bonusMaterial = RandomUtility.weighted(entries, rng)
	end

	-- Remove item
	data.inventory[slot] = nil

	-- Add essence
	local essenceItem = {
		id = "dismantle_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
		defId = "enemy_essence",
		type = "Material",
		name = "Enemy Essence",
		rarity = "Common",
		level = 1,
		stats = {},
		affixes = {},
		count = essenceCount,
	}
	InventoryService.addItem(player, essenceItem)

	-- Add bonus material if rolled
	if bonusMaterial then
		local bonusItem = {
			id = "bonus_dismantle_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
			defId = bonusMaterial.id,
			type = "Material",
			name = bonusMaterial.name,
			rarity = bonusMaterial.rarity,
			level = 1,
			stats = {},
		affixes = {},
			count = 1,
		}
		InventoryService.addItem(player, bonusItem)
	end

	local result = {
		essence = essenceCount,
		isCrit = isCrit,
		bonusMaterial = bonusMaterial and bonusMaterial.name or nil,
	}
	return true, result
end

-- Calculates total stats from all equipped items
function InventoryService.getEquipmentStats(player)
	local data = playerData[player.UserId]
	if not data then return {} end

	local stats = {
		damage = 0,
		speed = 0,
		range = 0,
		defense = 0,
		health = 0,
		damagePct = 0,
		defensePct = 0,
		healthPct = 0,
		moveSpeed = 0,
		attackSpeedPct = 0,
		lifeSteal = 0,
		critChance = 0,
		xpBonus = 0,
		goldFind = 0,
		fireDamage = 0,
		frostDamage = 0,
	}

	for _, item in pairs(data.equipment) do
		if item and item.stats then
			for stat, value in pairs(item.stats) do
				if type(value) == "number" then
					stats[stat] = (stats[stat] or 0) + value
				end
			end
		end
	end

	return stats
end

-- Serializes the full inventory + equipment for client sync
function InventoryService.serializeForClient(player)
	local data = playerData[player.UserId]
	if not data then return nil end

	local serialized = {
		inventory = {},
		equipment = {},
		currency = data.currency,
		level = data.level,
		experience = data.experience,
		luck = PlayerDataTypes.getEffectiveLuck(data),
		bestRarityFound = data.bestRarityFound or "Common",
		completedQuests = data.completedQuests or 0,
		dungeonRuns = data.dungeonRuns or 0,
		enemiesKilled = data.enemiesKilled or 0,
	}

	for i = 1, MAX_INVENTORY_SLOTS do
		local item = data.inventory[i]
		if item then
			serialized.inventory[i] = {
				id = item.id,
				defId = item.defId,
				name = item.name,
				displayName = item.displayName or item.name,
				rarity = item.rarity,
				level = item.level,
				type = item.type,
				slot = item.slot,
				count = item.count,
				stats = item.stats,
				affixes = item.affixes,
			}
		
		end
	end

	for slot, item in pairs(data.equipment) do
		if item then
			serialized.equipment[slot] = {
				id = item.id,
				defId = item.defId,
				name = item.name,
				displayName = item.displayName or item.name,
				rarity = item.rarity,
				level = item.level,
				type = item.type,
				slot = item.slot,
				count = item.count,
				stats = item.stats,
				affixes = item.affixes,
			}
		
		end
	end

	return serialized
end

return InventoryService