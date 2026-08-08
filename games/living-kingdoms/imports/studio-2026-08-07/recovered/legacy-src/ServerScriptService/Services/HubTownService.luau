--!strict

--[[
	HubTownService: Server-authoritative hub town management.

	Handles NPC interactions, shop transactions, and portal usage.
	Uses dependency injection to access PlayerDataService, InventoryService, and LootService.
]]

local HubTownService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubTownConfig = require(ReplicatedStorage.Shared.Config.HubTownConfig)
local HubTownContracts = require(ReplicatedStorage.Shared.RPG.HubTownContracts)
local RNGEngine = require(ReplicatedStorage.Shared.Utility.RNGEngine)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)

local _playerDataService
local _inventoryService
local _lootService
local _hubTownRemote

function HubTownService.setDependencies(pds, inv, loot, remote)
	_playerDataService = pds
	_inventoryService = inv
	_lootService = loot
	_hubTownRemote = remote
end

-- ===== ROTATING STOCK SYSTEM =====
-- Vendor stock refreshes periodically with random selection and daily deals
local STOCK_REFRESH_INTERVAL = 600 -- 10 minutes
local rotatingStock = {} -- [vendorId] = {items = {...}, lastRefresh = 0}

local function refreshVendorStock(vendorId)
	local fullCatalog = HubTownConfig.VendorCatalog[vendorId]
	if not fullCatalog then return end

	-- Select random subset of items (60-100% of catalog)
	local available = {}
	for _, item in ipairs(fullCatalog) do
		table.insert(available, item)
	end
	RandomUtility.shuffle(available)

	local stockCount = math.floor(#available * RandomUtility.float(0.6, 1.0))
	local selectedItems = {}

	for i = 1, stockCount do
		local item = available[i]
		local stockItem = table.clone(item)

		-- 20% chance for a daily deal (discounted price)
		if RandomUtility.chance(0.20) then
			local discount = RandomUtility.float(0.15, 0.40)
			stockItem.originalCost = stockItem.cost
			stockItem.cost = math.floor(stockItem.cost * (1 - discount))
			stockItem.isDailyDeal = true
			stockItem.discountPct = math.floor(discount * 100)
		end

		-- 5% chance for a "rare find" - upgraded rarity
		if RandomUtility.chance(0.05) then
			local rarityOrder = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}
			local currentIdx = table.find(rarityOrder, stockItem.rarity) or 1
			if currentIdx < #rarityOrder then
				stockItem.rarity = rarityOrder[currentIdx + 1]
				stockItem.isRareFind = true
				-- Upgrade stats slightly
				if stockItem.stats then
					stockItem.stats = table.clone(stockItem.stats)
					for stat, value in pairs(stockItem.stats) do
						if type(value) == "number" then
							stockItem.stats[stat] = value * 1.3
						end
					end
				end
			end
		end

		table.insert(selectedItems, stockItem)
	end

	rotatingStock[vendorId] = {
		items = selectedItems,
		lastRefresh = os.clock(),
	}
end

local function getVendorStock(vendorId)
	local stock = rotatingStock[vendorId]
	if not stock or (os.clock() - stock.lastRefresh) >= STOCK_REFRESH_INTERVAL then
		refreshVendorStock(vendorId)
		stock = rotatingStock[vendorId]
	end
	return stock and stock.items or HubTownConfig.VendorCatalog[vendorId]
end

-- Initialize and auto-refresh all vendor stocks
task.spawn(function()
	while task.wait(5) do
		for vendorId, _ in HubTownConfig.VendorCatalog do
			local stock = rotatingStock[vendorId]
			if not stock or (os.clock() - stock.lastRefresh) >= STOCK_REFRESH_INTERVAL then
				refreshVendorStock(vendorId)
			end
		end
	end
end)

-- Calculate the sell price for an item based on its rarity and level
local function calculateSellPrice(item)
	local baseValue = HubTownConfig.RARITY_BASE_VALUE[item.rarity] or 10
	local levelMult = 1 + ((item.level or 1) - 1) * 0.08 -- 8% per level above 1
	return math.floor(baseValue * levelMult * HubTownConfig.SELL_PRICE_MULTIPLIER)
end

function HubTownService.handleRequest(player: Player, payload: any)
	if not payload or type(payload) ~= "table" then return end
	
	local action = payload.action
	
	if action == "buy" then
		local vendorId = payload.vendorId
		local defId = payload.defId
		
		local catalog = getVendorStock(vendorId)
		if not catalog then return end
		
		local itemDef = nil
		for _, item in catalog do
			if item.defId == defId then
				itemDef = item
				break
			end
		end
		
		if not itemDef then return end
		
		local data = _playerDataService.getData(player)
		if data.currency >= itemDef.cost then
			_playerDataService.addCurrency(player, -itemDef.cost)
			
			-- Clone stats and apply random affixes for unpredictability
			local finalStats = itemDef.stats or {}
			if type(finalStats) == "table" then
				finalStats = table.clone(finalStats)
			end
			local finalName = itemDef.name
			local finalRarity = itemDef.rarity

			-- 15% chance to get a random bonus stat on purchased items
			if RandomUtility.chance(0.15) then
				local bonusStats = {"damage", "defense", "health", "speed", "critChance"}
				local bonusStat = RandomUtility.choice(bonusStats)
				local bonusValue = RandomUtility.float(0.05, 0.15)
				if bonusStat == "damage" or bonusStat == "defense" or bonusStat == "health" then
					bonusValue = RandomUtility.int(3, 12)
				end
				finalStats[bonusStat] = (finalStats[bonusStat] or 0) + bonusValue
				finalName = "Lucky " .. finalName
			end

			local newItem = {
				id = "shop_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
				defId = itemDef.defId,
				name = finalName,
				type = itemDef.type,
				slot = itemDef.slot,
				rarity = finalRarity,
				level = itemDef.level,
				stats = finalStats,
				count = 1,
			}
			
			_inventoryService.addItem(player, newItem)
			_playerDataService.syncInventory(player)
			
			_hubTownRemote:FireClient(player, {
				action = "purchase_result",
				success = true,
				item = newItem,
			})
		else
			_hubTownRemote:FireClient(player, {
				action = "purchase_result",
				success = false,
				reason = "Insufficient gold",
			})
		end
		
	elseif action == "interact" then
		local npcId = payload.npcId
		local npc = nil
		for _, n in HubTownConfig.NPCs do
			if n.id == npcId then
				npc = n
				break
			end
		end
		
		if npc and HubTownConfig.VendorCatalog[npcId] then
			_hubTownRemote:FireClient(player, {
				action = "vendor_open",
				vendorId = npcId,
				items = getVendorStock(npcId),
				greeting = npc.greeting,
			})
		end
	end
end

return HubTownService