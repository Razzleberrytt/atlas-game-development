-- PlayerDataService: Persistent player data with DataStore, auto-save, and session management
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local InventoryService = require(script.Parent.InventoryService)
local RNGEngine = require(ReplicatedStorage.Shared.Utility.RNGEngine)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)

local PlayerDataService = {}

-- RNG bonus config for currency and XP
local CURRENCY_BONUS_CHANCE = 0.15  -- 15% chance for bonus gold
local CURRENCY_BONUS_MULT = {min = 1.1, max = 1.5}  -- 10-50% bonus
local XP_BONUS_CHANCE = 0.12  -- 12% chance for bonus XP
local XP_BONUS_MULT = {min = 1.15, max = 1.6}  -- 15-60% bonus
local LUCK_PER_LEVEL = 0.5  -- Each level grants 0.5 base luck
local rng = Random.new()

local PLAYER_DATA_KEY = "PlayerData_"
local SAVE_INTERVAL = 60 -- auto-save every 60 seconds
local MAX_RETRIES = 3

local playerDataStore
local sessionData = {}
local saveQueue = {}
local isInitialized = false

-- Remotes (set by ServerBootstrap)
local inventoryRemote

function PlayerDataService.init()
	if isInitialized then return end
	isInitialized = true

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("RPGPlayerData_v1")
	end)
	if ok then
		playerDataStore = store
	else
		warn("[PlayerDataService] Failed to get DataStore - running in session-only mode")
	end

	-- Handle players already in game
	for _, player in Players:GetPlayers() do
		PlayerDataService.loadPlayer(player)
	end

	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.loadPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.savePlayer(player)
		InventoryService.clearPlayerData(player)
		sessionData[player.UserId] = nil
	end)

	-- Auto-save loop
	task.spawn(function()
		while task.wait(SAVE_INTERVAL) do
			for _, player in Players:GetPlayers() do
				PlayerDataService.savePlayer(player)
			end
		end
	end)
end

function PlayerDataService.setInventoryRemote(remote)
	inventoryRemote = remote
end

function PlayerDataService.loadPlayer(player)
	local data = PlayerDataTypes.createDefault()

	if playerDataStore then
		local success, result
		for attempt = 1, MAX_RETRIES do
			success, result = pcall(function()
				return playerDataStore:GetAsync(PLAYER_DATA_KEY .. player.UserId)
			end)
			if success then break end
			task.wait(2)
		end

		if success and result then
			-- Merge saved data with defaults to handle new fields
			for key, value in pairs(result) do
				data[key] = value
			end
		else
			warn("[PlayerDataService] Failed to load data for " .. player.Name)
		end
	end

	-- Ensure inventory is a table
	if type(data.inventory) ~= "table" then data.inventory = {} end

	-- Ensure equipment has all slots
	data.equipment = data.equipment or {}
	for _, slot in {"Primary", "Secondary", "Melee", "Helmet", "Chest", "Boots", "Relic"} do
		if not data.equipment[slot] then data.equipment[slot] = nil end
	end

	-- Give starting items if inventory is empty
	if next(data.inventory) == nil and not data.equipment.Melee then
		local startingHatchet = {
			id = "starting_hatchet_" .. player.UserId,
			defId = "stone_hatchet",
			type = "Weapon",
			name = "Stone Hatchet",
			displayName = "Stone Hatchet",
			rarity = "Common",
			level = 1,
			stats = {damage = 15, speed = 0.9, range = 7, damageType = "Physical"},
			affixes = {},
			slot = "Melee",
			count = 1,
		}
		data.equipment.Melee = startingHatchet

		-- Give 3 health potions
		for i = 1, 3 do
			table.insert(data.inventory, {
				id = "starting_potion_" .. player.UserId .. "_" .. tostring(i),
				defId = "minor_health_potion",
				type = "Consumable",
				name = "Minor Health Potion",
				displayName = "Minor Health Potion",
				rarity = "Common",
				level = 1,
				stats = {healAmount = 40},
				affixes = {},
				count = 1,
			})
		end
	end

	sessionData[player.UserId] = data
	InventoryService.setPlayerData(player, data)

	-- Send initial inventory state to client
	if inventoryRemote then
		local serialized = InventoryService.serializeForClient(player)
		inventoryRemote:FireClient(player, serialized)
	end

	print("[PlayerDataService] Loaded data for " .. player.Name .. " (Level " .. data.level .. ")")
	return data
end

function PlayerDataService.savePlayer(player)
	local data = sessionData[player.UserId]
	if not data then return false end

	if not playerDataStore then return false end

	local success, result
	for attempt = 1, MAX_RETRIES do
		success, result = pcall(function()
			playerDataStore:SetAsync(PLAYER_DATA_KEY .. player.UserId, data)
		end)
		if success then break end
		task.wait(2)
	end

	if not success then
		warn("[PlayerDataService] Failed to save data for " .. player.Name .. ": " .. tostring(result))
	end

	return success
end

function PlayerDataService.getData(player)
	return sessionData[player.UserId]
end

-- Get the player's effective luck (base + temporary streaks)
function PlayerDataService.getLuck(player)
	local data = sessionData[player.UserId]
	if not data then return 0 end
	PlayerDataTypes.decayLuckStreak(data)
	return PlayerDataTypes.getEffectiveLuck(data)
end

-- Apply a temporary luck streak (from events, consumables, weather, etc.)
function PlayerDataService.applyLuckStreak(player, amount, durationSeconds)
	local data = sessionData[player.UserId]
	if not data then return end
	PlayerDataTypes.applyLuckStreak(data, amount, durationSeconds)
	print(string.format("[PlayerDataService] %s gained +%d luck for %d seconds", player.Name, amount, durationSeconds or 300))
end

-- Permanently increase base luck (from achievements, quests, etc.)
function PlayerDataService.addBaseLuck(player, amount)
	local data = sessionData[player.UserId]
	if not data then return end
	data.luck = (data.luck or 0) + amount
	print(string.format("[PlayerDataService] %s gained +%d permanent luck (total: %d)", player.Name, amount, data.luck))
	return data.luck
end

-- Alias for addBaseLuck (used by trackQuestCompleted and trackDungeonCompleted)
PlayerDataService.addLuck = PlayerDataService.addBaseLuck

function PlayerDataService.addCurrency(player, amount)
	local data = sessionData[player.UserId]
	if not data then return 0 end

	-- RNG: chance for bonus gold
	local finalAmount = amount
	local bonusApplied = false
	if RandomUtility.chance(CURRENCY_BONUS_CHANCE, rng) then
		local mult = RandomUtility.float(CURRENCY_BONUS_MULT.min, CURRENCY_BONUS_MULT.max, rng)
		-- Luck slightly increases the bonus multiplier
		local luck = PlayerDataTypes.getEffectiveLuck(data)
		mult = mult + (luck * 0.001) -- Small scaling
		finalAmount = math.floor(amount * mult + 0.5)
		bonusApplied = true
	end

	data.currency = (data.currency or 0) + finalAmount
	if bonusApplied then
		print(string.format("[PlayerDataService] %s gained %d gold (BONUS! %.0f%%) (total: %d)", player.Name, finalAmount, (finalAmount / amount) * 100, data.currency))
	else
		print(string.format("[PlayerDataService] %s gained %d gold (total: %d)", player.Name, finalAmount, data.currency))
	end
	return data.currency, bonusApplied
end

function PlayerDataService.addExperience(player, amount)
	local data = sessionData[player.UserId]
	if not data then return 0, 1 end

	-- RNG: chance for bonus XP
	local finalAmount = amount
	local bonusApplied = false
	if RandomUtility.chance(XP_BONUS_CHANCE, rng) then
		local mult = RandomUtility.float(XP_BONUS_MULT.min, XP_BONUS_MULT.max, rng)
		local luck = PlayerDataTypes.getEffectiveLuck(data)
		mult = mult + (luck * 0.001)
		finalAmount = math.floor(amount * mult + 0.5)
		bonusApplied = true
	end

	data.experience = (data.experience or 0) + finalAmount
	local level, expInLevel = PlayerDataTypes.levelFromExp(data.experience)

	local leveledUp = false
	while level > data.level do
		data.level += 1
		leveledUp = true
		-- Each level grants base luck
		data.luck = (data.luck or 0) + LUCK_PER_LEVEL
		print("[PlayerDataService] " .. player.Name .. " leveled up to " .. data.level .. " (Luck: " .. data.luck .. ")")
	end

	-- Decay expired luck streaks on XP gain
	PlayerDataTypes.decayLuckStreak(data)

	return data.experience, data.level, leveledUp, bonusApplied
end

-- Track RNG-based stats (called when items are found)
function PlayerDataService.trackItemFound(player, item)
	local data = sessionData[player.UserId]
	if not data then return end
	data.totalItemsFound = (data.totalItemsFound or 0) + 1
	if item.rarity == "Corrupted" then
		data.corruptedItemsFound = (data.corruptedItemsFound or 0) + 1
	end
	if item.setId then
		data.setItemsFound = (data.setItemsFound or 0) + 1
	end
	if item.mystery then
		data.mysteryItemsFound = (data.mysteryItemsFound or 0) + 1
	end
	PlayerDataTypes.updateBestRarity(data, item.rarity)
end

-- Track quest completion
function PlayerDataService.trackQuestCompleted(player)
	local data = sessionData[player.UserId]
	if not data then return end
	data.completedQuests = (data.completedQuests or 0) + 1
	-- Every 5 quests completed, grant permanent luck
	if data.completedQuests % 5 == 0 then
		PlayerDataService.addLuck(player, 1)
		print("[PlayerDataService] " .. player.Name .. " completed 5 quests! +1 permanent luck")
	end
end

-- Track dungeon completion
function PlayerDataService.trackDungeonCompleted(player)
	local data = sessionData[player.UserId]
	if not data then return end
	data.dungeonRuns = (data.dungeonRuns or 0) + 1
	-- Every 3 dungeons, grant permanent luck
	if data.dungeonRuns % 3 == 0 then
		PlayerDataService.addLuck(player, 2)
		print("[PlayerDataService] " .. player.Name .. " completed 3 dungeons! +2 permanent luck")
	end
end

-- Track enemy kills
function PlayerDataService.trackEnemyKill(player)
	local data = sessionData[player.UserId]
	if not data then return end
	data.enemiesKilled = (data.enemiesKilled or 0) + 1
end

function PlayerDataService.syncInventory(player)
	if inventoryRemote then
		local serialized = InventoryService.serializeForClient(player)
		inventoryRemote:FireClient(player, serialized)
	end
end

-- Force-save all players (e.g., on server shutdown)
function PlayerDataService.saveAll()
	for _, player in Players:GetPlayers() do
		PlayerDataService.savePlayer(player)
	end
end

return PlayerDataService