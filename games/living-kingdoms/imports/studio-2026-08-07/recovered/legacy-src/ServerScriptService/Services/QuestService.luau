-- QuestService: Random quest generation, tracking, and reward distribution
-- Uses RNGEngine for procedural quest generation with unpredictable targets, locations, and rewards

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RNGEngine = require(ReplicatedStorage.Shared.Utility.RNGEngine)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)

local QuestService = {}

-- Dependencies
local playerDataService
local inventoryService
local lootService
local questRemote

-- Active quests per player: [userId] = {quest1, quest2, quest3}
local playerQuests = {}

-- Quest tracking: [userId] = {killCounts = {goblin_scout = 5, ...}, exploreCount = 3, ...}
local questProgress = {}

-- Maximum active quests per player
local MAX_ACTIVE_QUESTS = 3

-- Quest refresh interval (seconds between auto-generated quests)
local QUEST_REFRESH_INTERVAL = 300 -- 5 minutes

function QuestService.setDependencies(pds, inv, loot, remote)
	playerDataService = pds
	inventoryService = inv
	lootService = loot
	questRemote = remote
end

-- Generates a new quest for a player based on their level
local function generateQuestForPlayer(player)
	local level = 1
	local pData = playerDataService and playerDataService.getData(player)
	if pData then level = pData.level end

	local quest = RNGEngine.generateQuest(level)

	-- Add random time limit for bonus rewards (40% chance)
	if RandomUtility.chance(0.40) then
		quest.timeLimit = RandomUtility.int(120, 600) -- 2-10 minutes
		quest.bonusRewardMult = RandomUtility.float(1.5, 2.5)
	end

	-- Add random quest modifier (25% chance)
	if RandomUtility.chance(0.25) then
		local modifiers = {
			{id = "solo_only", name = "Solo Challenge", description = "Complete without dying", bonusMult = 1.5},
			{id = "speed_run", name = "Speed Run", description = "Complete within time limit for bonus", bonusMult = 2.0},
			{id = "no_damage", name = "Flawless", description = "Complete without taking damage", bonusMult = 2.5},
			{id = "chain_bonus", name = "Chain Killer", description = "Kill enemies in quick succession", bonusMult = 1.8},
		}
		quest.modifier = RandomUtility.choice(modifiers)
	end

	return quest
end

-- Gets all active quests for a player
function QuestService.getActiveQuests(player)
	return playerQuests[player.UserId] or {}
end

-- Generates and assigns a new quest to a player
function QuestService.assignQuest(player)
	local quests = playerQuests[player.UserId] or {}
	if #quests >= MAX_ACTIVE_QUESTS then
		return nil, "Maximum active quests reached"
	end

	local quest = generateQuestForPlayer(player)
	table.insert(quests, quest)
	playerQuests[player.UserId] = quests

	-- Initialize progress tracking
	if not questProgress[player.UserId] then
		questProgress[player.UserId] = {killCounts = {}, exploreCount = 0}
	end

	-- Send quest to client
	if questRemote then
		questRemote:FireClient(player, {
			action = "quest_assigned",
			quest = quest,
		})
	end

	return quest
end

-- Abandons a quest
function QuestService.abandonQuest(player, questId)
	local quests = playerQuests[player.UserId] or {}
	for i, quest in ipairs(quests) do
		if quest.id == questId then
			table.remove(quests, i)
			if questRemote then
				questRemote:FireClient(player, {
					action = "quest_abandoned",
					questId = questId,
				})
			end
			return true
		end
	end
	return false
end

-- Updates quest progress when an enemy is killed
function QuestService.onEnemyKilled(player, enemyId)
	local quests = playerQuests[player.UserId]
	if not quests then return end

	local progress = questProgress[player.UserId]
	if not progress then return end

	-- Track kill counts
	progress.killCounts[enemyId] = (progress.killCounts[enemyId] or 0) + 1

	-- Update kill-type quests
	for _, quest in ipairs(quests) do
		if not quest.completed and quest.template == "kill" or quest.template == "elite" or quest.template == "boss" then
			if quest.target == enemyId or quest.template == "boss" then
				quest.currentCount = (quest.currentCount or 0) + 1
				if quest.currentCount >= quest.requiredCount then
					QuestService.completeQuest(player, quest.id)
				end
			end
		end
	end
end

-- Updates quest progress when a resource is gathered
function QuestService.onResourceGathered(player, resourceType)
	local quests = playerQuests[player.UserId]
	if not quests then return end

	for _, quest in ipairs(quests) do
		if not quest.completed and quest.template == "collect" then
			quest.currentCount = (quest.currentCount or 0) + 1
			if quest.currentCount >= quest.requiredCount then
				QuestService.completeQuest(player, quest.id)
			end
		end
	end
end

-- Updates quest progress when a location is discovered
function QuestService.onLocationDiscovered(player, locationName)
	local quests = playerQuests[player.UserId]
	if not quests then return end

	for _, quest in ipairs(quests) do
		if not quest.completed and quest.template == "explore" then
			if not quest.discoveredLocations then
				quest.discoveredLocations = {}
			end
			if not quest.discoveredLocations[locationName] then
				quest.discoveredLocations[locationName] = true
				quest.currentCount = (quest.currentCount or 0) + 1
				if quest.currentCount >= quest.requiredCount then
					QuestService.completeQuest(player, quest.id)
				end
			end
		end
	end
end

-- Completes a quest and awards rewards
function QuestService.completeQuest(player, questId)
	local quests = playerQuests[player.UserId]
	if not quests then return false end

	for i, quest in ipairs(quests) do
		if quest.id == questId and not quest.completed then
			quest.completed = true

			-- Calculate reward multiplier from modifier
			local rewardMult = 1.0
			if quest.modifier then
				rewardMult = quest.modifier.bonusMult or 1.0
			end
			if quest.bonusRewardMult then
				rewardMult = rewardMult * quest.bonusRewardMult
			end

			-- Award rewards
			local rewards = quest.rewards or {}
			local awarded = {}

			if rewards.gold and playerDataService then
				local gold = math.floor(rewards.gold * rewardMult)
				playerDataService.addCurrency(player, gold)
				awarded.gold = gold
			end

			if rewards.experience and playerDataService then
				local xp = math.floor(rewards.experience * rewardMult)
				playerDataService.addExperience(player, xp)
				awarded.experience = xp
			end

			if rewards.materials and inventoryService then
				local matCount = math.floor(rewards.materials * rewardMult)
				local matItem = {
					id = "quest_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
					defId = "quest_material",
					type = "Material",
					name = "Quest Materials",
					rarity = "Uncommon",
					level = quest.level or 1,
					stats = {},
					affixes = {},
					count = matCount,
				}
				inventoryService.addItem(player, matItem)
				awarded.materials = matCount
			end

			if rewards.itemRarityBonus and lootService then
				-- Roll a loot item with rarity bonus (luck influences reward quality)
				local pLuck = 0
				if playerDataService then
					pLuck = playerDataService.getLuck(player)
				end
				local loot = lootService.rollLoot("quest_reward", quest.level or 1, nil, pLuck)
				if loot and #loot.items > 0 and inventoryService then
					for _, item in ipairs(loot.items) do
						inventoryService.addItem(player, item)
						if playerDataService then
							playerDataService.trackItemFound(player, item)
						end
					end
					awarded.items = #loot.items
				end
				if loot and loot.gold then
					if playerDataService then
						playerDataService.addCurrency(player, loot.gold)
					end
					awarded.gold = (awarded.gold or 0) + loot.gold
				end
			end

			-- Sync inventory
			if playerDataService then
				playerDataService.syncInventory(player)
			end

			-- Notify client
			if questRemote then
				questRemote:FireClient(player, {
					action = "quest_completed",
					questId = quest.id,
					questName = quest.name,
					rewards = awarded,
				})
			end

			-- Remove from active list
			table.remove(quests, i)

			-- Auto-generate a new quest after a short delay
			task.delay(5, function()
				if player and player.Parent then
					QuestService.assignQuest(player)
				end
			end)

			return true
		end
	end
	return false
end

-- Syncs all quests to a player (e.g., on join or respawn)
function QuestService.syncQuests(player)
	local quests = playerQuests[player.UserId] or {}
	if questRemote then
		questRemote:FireClient(player, {
			action = "quest_sync",
			quests = quests,
		})
	end
end

-- Initialize quest system for a player
function QuestService.initPlayer(player)
	if not playerQuests[player.UserId] then
		playerQuests[player.UserId] = {}
		questProgress[player.UserId] = {killCounts = {}, exploreCount = 0}

		-- Generate initial quests (1-2 starting quests)
		local initialCount = RandomUtility.int(1, 2)
		for _ = 1, initialCount do
			QuestService.assignQuest(player)
		end
	end
end

-- Clean up when a player leaves
function QuestService.removePlayer(player)
	playerQuests[player.UserId] = nil
	questProgress[player.UserId] = nil
end

-- Auto-refresh: periodically offer new quests to players with free slots
task.spawn(function()
	while task.wait(QUEST_REFRESH_INTERVAL) do
		for _, player in Players:GetPlayers() do
			local quests = playerQuests[player.UserId] or {}
			if #quests < MAX_ACTIVE_QUESTS then
				QuestService.assignQuest(player)
			end
		end
	end
end)

return QuestService