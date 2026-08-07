-- RPGServerBootstrap: Server entry point that initializes all RPG systems, creates remotes, and handles client requests

-- Horizontal distance helper (ignores Y to avoid vertical offset issues)
local function hDist(posA, posB)
	local dx = posA.X - posB.X
	local dz = posA.Z - posB.Z
	return math.sqrt(dx * dx + dz * dz)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require services
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local InventoryService = require(ServerScriptService.Services.InventoryService)
local LootService = require(ServerScriptService.Services.LootService)
local CombatService = require(ServerScriptService.Services.CombatService)
local EnemyService = require(ServerScriptService.Services.EnemyService)
local DungeonService = require(ServerScriptService.Services.DungeonService)
local HubTownService = require(ServerScriptService.Services.HubTownService)

-- RNG modules
local RNGEngine = require(ReplicatedStorage.Shared.Utility.RNGEngine)
local RandomUtility = require(ReplicatedStorage.Shared.Utility.RandomUtility)
local rng = Random.new()
local QuestService = require(ServerScriptService.Services.QuestService)

-- Ensure ReplicatedStorage.Shared exists
local shared = ReplicatedStorage:FindFirstChild("Shared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "Shared"
	shared.Parent = ReplicatedStorage
end

-- Create Remotes folder
local remotes = ReplicatedStorage:FindFirstChild("RPGRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "RPGRemotes"
	remotes.Parent = ReplicatedStorage
end

-- Combat remotes
local combatFolder = remotes:FindFirstChild("Combat")
if not combatFolder then
	combatFolder = Instance.new("Folder")
	combatFolder.Name = "Combat"
	combatFolder.Parent = remotes
end

local combatRemote = combatFolder:FindFirstChild("CombatEvent")
if not combatRemote then
	combatRemote = Instance.new("RemoteEvent")
	combatRemote.Name = "CombatEvent"
	combatRemote.Parent = combatFolder
end

local abilityRemote = combatFolder:FindFirstChild("AbilityEvent")
if not abilityRemote then
	abilityRemote = Instance.new("RemoteEvent")
	abilityRemote.Name = "AbilityEvent"
	abilityRemote.Parent = combatFolder
end

-- Inventory remotes
local invFolder = remotes:FindFirstChild("Inventory")
if not invFolder then
	invFolder = Instance.new("Folder")
	invFolder.Name = "Inventory"
	invFolder.Parent = remotes
end

local inventoryRemote = invFolder:FindFirstChild("InventorySync")
if not inventoryRemote then
	inventoryRemote = Instance.new("RemoteEvent")
	inventoryRemote.Name = "InventorySync"
	inventoryRemote.Parent = invFolder
end

local inventoryActionRemote = invFolder:FindFirstChild("InventoryAction")
if not inventoryActionRemote then
	inventoryActionRemote = Instance.new("RemoteEvent")
	inventoryActionRemote.Name = "InventoryAction"
	inventoryActionRemote.Parent = invFolder
end

local lootNotificationRemote = invFolder:FindFirstChild("LootNotification")
if not lootNotificationRemote then
	lootNotificationRemote = Instance.new("RemoteEvent")
	lootNotificationRemote.Name = "LootNotification"
	lootNotificationRemote.Parent = invFolder
end

-- Dungeon remotes
local dungeonFolder = remotes:FindFirstChild("Dungeon")
if not dungeonFolder then
	dungeonFolder = Instance.new("Folder")
	dungeonFolder.Name = "Dungeon"
	dungeonFolder.Parent = remotes
end

local dungeonRemote = dungeonFolder:FindFirstChild("DungeonEvent")
if not dungeonRemote then
	dungeonRemote = Instance.new("RemoteEvent")
	dungeonRemote.Name = "DungeonEvent"
	dungeonRemote.Parent = dungeonFolder
end

local dungeonStateRemote = dungeonFolder:FindFirstChild("DungeonState")
if not dungeonStateRemote then
	dungeonStateRemote = Instance.new("RemoteEvent")
	dungeonStateRemote.Name = "DungeonState"
	dungeonStateRemote.Parent = dungeonFolder
end

-- Boss remote
local bossRemote = combatFolder:FindFirstChild("BossEvent")
if not bossRemote then
	bossRemote = Instance.new("RemoteEvent")
	bossRemote.Name = "BossEvent"
	bossRemote.Parent = combatFolder
end

-- Results remote
local resultsRemote = remotes:FindFirstChild("ResultsEvent")
if not resultsRemote then
	resultsRemote = Instance.new("RemoteEvent")
	resultsRemote.Name = "ResultsEvent"
	resultsRemote.Parent = remotes
end

-- HubTown remotes
local hubTownFolder = remotes:FindFirstChild("HubTown")
if not hubTownFolder then
	hubTownFolder = Instance.new("Folder")
	hubTownFolder.Name = "HubTown"
	hubTownFolder.Parent = remotes
end

local hubTownRemote = hubTownFolder:FindFirstChild("HubTownEvent")
if not hubTownRemote then
	hubTownRemote = Instance.new("RemoteEvent")
	hubTownRemote.Name = "HubTownEvent"
	hubTownRemote.Parent = hubTownFolder
end

-- Quest remotes
local questFolder = remotes:FindFirstChild("Quest")
if not questFolder then
	questFolder = Instance.new("Folder")
	questFolder.Name = "Quest"
	questFolder.Parent = remotes
end

local questRemote = questFolder:FindFirstChild("QuestEvent")
if not questRemote then
	questRemote = Instance.new("RemoteEvent")
	questRemote.Name = "QuestEvent"
	questRemote.Parent = questFolder
end

-- Create enemy spawn folder
local enemyFolder = workspace:FindFirstChild("RPGEnemies")
if not enemyFolder then
	enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "RPGEnemies"
	enemyFolder.Parent = workspace
end

-- Create dungeon runtime folder
local dungeonRuntimeFolder = workspace:FindFirstChild("DungeonOrigin")
if not dungeonRuntimeFolder then
	dungeonRuntimeFolder = Instance.new("Folder")
	dungeonRuntimeFolder.Name = "DungeonOrigin"
	dungeonRuntimeFolder.Parent = workspace
end

-- Initialize services
PlayerDataService.init()
PlayerDataService.setInventoryRemote(inventoryRemote)

-- Set up dependencies
EnemyService.setSpawnFolder(enemyFolder)
EnemyService.setDependencies(CombatService, LootService, PlayerDataService, InventoryService, combatRemote, lootNotificationRemote)
CombatService.setDependencies(InventoryService, PlayerDataService, EnemyService, combatRemote, LootService)
DungeonService.setDependencies(EnemyService, LootService, CombatService, PlayerDataService, InventoryService)
HubTownService.setDependencies(PlayerDataService, InventoryService, LootService, hubTownRemote)
hubTownRemote.OnServerEvent:Connect(HubTownService.handleRequest)
QuestService.setDependencies(PlayerDataService, InventoryService, LootService, questRemote)

-- Start enemy AI
EnemyService.startAI()

-- Track active dungeon
local activeDungeon = nil

-- ===== PLAYER SPAWN & RESPAWN =====
local PREP_SPAWN = CFrame.new(0, 5, 0)

local function setupCharacter(player, character)
	-- Set max health based on equipment
	local maxHP = CombatService.getMaxHealth(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = maxHP
		humanoid.Health = maxHP

		-- Handle death/respawn
		humanoid.Died:Connect(function()
			task.delay(3, function()
				if player and player.Parent then
					player:LoadCharacter()
				end
			end)
		end)
	end

	-- Teleport to preparation room if not in dungeon, or to dungeon start if dungeon is active
	if activeDungeon and activeDungeon.rooms and activeDungeon.rooms[1] then
		character:PivotTo(CFrame.new(activeDungeon.rooms[1].position + Vector3.new(0, 5, 10)))
	else
		character:PivotTo(PREP_SPAWN)
	end
end

-- Handle existing players and new joins
for _, player in Players:GetPlayers() do
	if player.Character then
		setupCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5) -- wait for character to fully load
		setupCharacter(player, char)
	end)
	QuestService.initPlayer(player)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		setupCharacter(player, char)
	end)
	QuestService.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	QuestService.removePlayer(player)
end)

-- Handle combat requests (client swing)
local playerAttackCooldowns = {}
combatRemote.OnServerEvent:Connect(function(player, payload)
	if not payload or type(payload) ~= "table" then return end

	if payload.action == "swing" then
		-- Validate cooldown
		local now = os.clock()
		local cooldown = CombatService.getAttackCooldown(player)
		local lastAttack = playerAttackCooldowns[player.UserId] or 0
		if now - lastAttack < cooldown then return end
		playerAttackCooldowns[player.UserId] = now

		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local range = CombatService.getAttackRange(player)
		local damage, isCrit, isCombo = CombatService.calculatePlayerDamage(player)

		-- Find nearest enemy in range
		local nearestEnemy = nil
		local nearestDist = range
		for model, _ in EnemyService.getActiveEnemies() do
			if model and model.Parent then
				local enemyHrp = model:FindFirstChild("HumanoidRootPart")
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if enemyHrp and humanoid and humanoid.Health > 0 then
					local dist = hDist(hrp.Position, enemyHrp.Position)
					if dist < nearestDist then
						nearestDist = dist
						nearestEnemy = model
					end
				end
			end
		end

		if nearestEnemy then
			CombatService.dealDamageToEnemy(player, nearestEnemy, damage, isCrit, isCombo)
		end
	elseif payload.action == "use_consumable" then
		-- Use a health potion from inventory
		local slot = payload.slot
		local data = PlayerDataService.getData(player)
		if not data then return end
		local item = data.inventory[slot]
		if not item or item.type ~= "Consumable" then return end

		local char = player.Character
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (item.stats.healAmount or 0))

		-- Remove one from stack
		item.count = (item.count or 1) - 1
		if item.count <= 0 then
			data.inventory[slot] = nil
		end
		PlayerDataService.syncInventory(player)
	end
end)

-- Handle inventory actions
inventoryActionRemote.OnServerEvent:Connect(function(player, payload)
	if not payload or type(payload) ~= "table" then return end

	local action = payload.action

	if action == "equip" then
		local success, result = InventoryService.equipItem(player, payload.slot)
		PlayerDataService.syncInventory(player)
		inventoryActionRemote:FireClient(player, {action = "equip_result", success = success, slot = result})
	elseif action == "unequip" then
		local success, result = InventoryService.unequipItem(player, payload.slot)
		PlayerDataService.syncInventory(player)
		inventoryActionRemote:FireClient(player, {action = "unequip_result", success = success, slot = result})
	elseif action == "dismantle" then
		local success, result = InventoryService.dismantleItem(player, payload.slot)
		PlayerDataService.syncInventory(player)
		inventoryActionRemote:FireClient(player, {action = "dismantle_result", success = success, result = result})
	elseif action == "use_item" then
		-- Use consumable directly
		local slot = payload.slot
		local data = PlayerDataService.getData(player)
		if not data then return end
		local item = data.inventory[slot]
		if not item or item.type ~= "Consumable" then return end

		local char = player.Character
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (item.stats.healAmount or 0))
		item.count = (item.count or 1) - 1
		if item.count <= 0 then
			data.inventory[slot] = nil
		end
		PlayerDataService.syncInventory(player)
	end
end)

-- Handle ability requests
abilityRemote.OnServerEvent:Connect(function(player, payload)
	if not payload or type(payload) ~= "table" then return end

	if payload.action == "activate" then
		local abilityId = payload.abilityId
		if not abilityId then return end

		-- Handle heal
		if abilityId == "heal" then
			local char = player.Character
			if not char then return end
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 40)

		-- Handle ground_slam
		elseif abilityId == "ground_slam" then
			local char = player.Character
			if not char then return end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			-- Damage all enemies in radius
			for model, _ in EnemyService.getActiveEnemies() do
				if model and model.Parent then
					local enemyHrp = model:FindFirstChild("HumanoidRootPart")
					local humanoid = model:FindFirstChildOfClass("Humanoid")
					if enemyHrp and humanoid and humanoid.Health > 0 then
						if hDist(hrp.Position, enemyHrp.Position) <= 12 then
							CombatService.dealDamageToEnemy(player, model, 30, false)
						end
					end
				end
			end

		-- Handle rage
		elseif abilityId == "rage" then
			-- Temporary damage boost (client-side visual, server tracks via attribute)
			player:SetAttribute("RageActive", true)
			task.delay(5, function()
				player:SetAttribute("RageActive", false)
			end)

		-- Handle dash
		elseif abilityId == "dash" then
			-- Movement is handled client-side, just acknowledge
		end
	end
end)

-- Spawn outdoor enemies on the combat path
local outdoorSpawnPoints = {
	Vector3.new(0, 3, 45),
	Vector3.new(4, 3, 75),
	Vector3.new(-3, 3, 105),
	Vector3.new(2, 3, 135),
}

local outdoorEnemyTypes = {"goblin_scout", "skeleton_archer", "wolf", "goblin_scout"}

task.delay(3, function()
	for i, pos in outdoorSpawnPoints do
		EnemyService.spawnEnemy(outdoorEnemyTypes[i], pos)
	end
	print("[RPGServer] Spawned " .. #outdoorSpawnPoints .. " outdoor enemies")
end)

-- Handle dungeon events
dungeonRemote.OnServerEvent:Connect(function(player, payload)
	if not payload or type(payload) ~= "table" then return end

	if payload.action == "enter_dungeon" then
		-- Generate and build dungeon
		if activeDungeon then
			DungeonService.cleanupDungeon(activeDungeon)
		end

		local level = 1
		local pData = PlayerDataService.getData(player)
		if pData then level = pData.level end

		activeDungeon = DungeonService.generateDungeon("prototype_dungeon", nil, Vector3.new(0, 0, -200))
		DungeonService.buildDungeon(activeDungeon, dungeonRuntimeFolder)

		-- Spawn first room enemies
		if activeDungeon.rooms[1] then
			DungeonService.spawnRoomEnemies(activeDungeon, activeDungeon.rooms[1], level)
		end

		-- Spawn chests for loot rooms
		for _, room in activeDungeon.rooms do
			if room.roomType == "loot" or room.roomType == "secret" or room.roomType == "boss" then
				DungeonService.spawnChest(activeDungeon, room, level)
			end
		end

		-- Notify all clients
		dungeonStateRemote:FireAllClients({
			action = "dungeon_started",
			name = activeDungeon.name,
			roomCount = #activeDungeon.rooms,
			startPosition = activeDungeon.rooms[1].position + Vector3.new(0, 5, 10),
		})

		print("[RPGServer] Dungeon generated: " .. activeDungeon.name .. " (" .. #activeDungeon.rooms .. " rooms)")

	elseif payload.action == "open_chest" then
		-- Find chest by position
		local chestPart = payload.chest
		if not chestPart then return end

		-- Validate chest exists and is unopened
		local chest = nil
		if activeDungeon and activeDungeon.folder then
			for _, part in activeDungeon.folder:GetDescendants() do
				if part:GetAttribute("IsChest") and not part:GetAttribute("IsOpened") then
					local playerChar = player.Character
					if playerChar then
						local hrp = playerChar:FindFirstChild("HumanoidRootPart")
						if hrp and hDist(part.Position, hrp.Position) < 15 then
							chest = part
							break
						end
					end
				end
			end
		end

		if not chest then return end
		chest:SetAttribute("IsOpened", true)
		chest.Color = Color3.fromRGB(80, 60, 30)

		-- Roll loot (with player's luck stat)
		local lootTable = chest:GetAttribute("LootTable") or "dungeon_chest"
		local level = 1
		local luck = 0
		local pData = PlayerDataService.getData(player)
		if pData then level = pData.level end
		luck = PlayerDataService.getLuck(player)

		local loot = LootService.rollLoot(lootTable, level, rng, luck)
		if loot then
			PlayerDataService.addCurrency(player, loot.gold)
			for _, item in loot.items do
				InventoryService.addItem(player, item)
				PlayerDataService.trackItemFound(player, item)
			end
			for _, mat in loot.materials do
				local matItem = {
					id = "chest_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999)),
					defId = mat.defId,
					type = "Material",
					name = mat.defId,
					rarity = "Common",
					level = 1,
					stats = {},
					affixes = {},
					count = mat.count,
				}
				InventoryService.addItem(player, matItem)
			end
			PlayerDataService.syncInventory(player)

			-- Send loot notification
			local serialized = {}
			for _, item in loot.items do
				table.insert(serialized, LootService.serializeItem(item))
			end
			lootNotificationRemote:FireClient(player, {
				items = serialized,
				gold = loot.gold,
				source = "Treasure Chest",
			})
		end

	elseif payload.action == "exit_dungeon" then
		if activeDungeon then
			DungeonService.cleanupDungeon(activeDungeon)
			activeDungeon = nil
			dungeonStateRemote:FireAllClients({action = "dungeon_cleared"})
		end
	end
end)

-- Handle game close
game:BindToClose(function()
	PlayerDataService.saveAll()
end)

-- ===== DUNGEON ROOM PROGRESSION & BOSS MONITORING =====
task.spawn(function()
	while task.wait(1) do
		if not activeDungeon then continue end

		-- Find any player in the dungeon
		local anyPlayer = nil
		for _, p in Players:GetPlayers() do
			if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				anyPlayer = p
				break
			end
		end
		if not anyPlayer then continue end

		local playerLevel = 1
		local pData = PlayerDataService.getData(anyPlayer)
		if pData then playerLevel = pData.level end

		-- Check which room the nearest player is in and spawn enemies if needed
		local playerHrp = anyPlayer.Character.HumanoidRootPart
		for _, room in activeDungeon.rooms do
			if not room.enemiesSpawned then
				local dist = hDist(playerHrp.Position, room.position)
				if dist < (room.size.X / 2 + 10) then
					DungeonService.spawnRoomEnemies(activeDungeon, room, playerLevel)
				end
			end
		end

		-- Check if boss has been spawned and is now dead
		local bossAlive = false
		for model, data in EnemyService.getActiveEnemies() do
			if data.isBoss then
				bossAlive = true
				break
			end
		end

		-- Track if boss was ever spawned
		if bossAlive then
			activeDungeon.bossWasSpawned = true
		end

		-- Only trigger victory if boss was spawned and is now dead
		if activeDungeon and activeDungeon.bossWasSpawned and not activeDungeon.bossDefeated and not bossAlive then
			for _, room in activeDungeon.rooms do
				if room.roomType == "boss" then
					activeDungeon.bossDefeated = true

					-- Track dungeon completion for all players
					for _, p in Players:GetPlayers() do
						PlayerDataService.trackDungeonCompleted(p)
					end

					-- Spawn exit portal
					local exitPortal = Instance.new("Part")
					exitPortal.Name = "DungeonExit"
					exitPortal.Size = Vector3.new(8, 12, 2)
					exitPortal.Position = room.position + Vector3.new(0, 3, room.size.Z / 4)
					exitPortal.Anchored = true
					exitPortal.CanCollide = false
					exitPortal.Color = Color3.fromRGB(100, 200, 255)
					exitPortal.Material = Enum.Material.Neon
					exitPortal.Transparency = 0.3
					exitPortal.Parent = activeDungeon.folder

					-- Fire results to all players
					resultsRemote:FireAllClients({
						action = "expedition_complete",
						dungeonName = activeDungeon.name,
					})

					print("[RPGServer] Boss defeated! Exit portal spawned.")
					break
				end
			end
		end
	end
end)

-- Hook quest progress into enemy kills
local originalOnEnemyKilled = EnemyService.onEnemyKilled
EnemyService.onEnemyKilled = function(player, model)
	originalOnEnemyKilled(player, model)
	-- Track enemy kill
	PlayerDataService.trackEnemyKill(player)
	-- Update quest progress
	local enemyId = model:GetAttribute("EnemyId")
	if enemyId then
		QuestService.onEnemyKilled(player, enemyId)
	end
end

-- Handle quest remote events
questRemote.OnServerEvent:Connect(function(player, payload)
	if not payload or type(payload) ~= "table" then return end

	if payload.action == "request_quest" then
		QuestService.assignQuest(player)
	elseif payload.action == "abandon_quest" then
		QuestService.abandonQuest(player, payload.questId)
	elseif payload.action == "sync" then
		QuestService.syncQuests(player)
	end
end)

print("[RPGServerBootstrap] All RPG services initialized")

-- ===== WORLD EVENT SYSTEM =====
-- Random weather, wandering NPCs, and overworld events that make the world feel alive and unpredictable

local currentWeather = nil
local weatherEffects = {}
local worldEventRemote = remotes:FindFirstChild("WorldEvent")
if not worldEventRemote then
	worldEventRemote = Instance.new("RemoteEvent")
	worldEventRemote.Name = "WorldEvent"
	worldEventRemote.Parent = remotes
end

-- Apply weather effects to all players
local function applyWeatherEffects(weather)
	currentWeather = weather
	weatherEffects = weather.effects or {}

	-- Notify all clients
	worldEventRemote:FireAllClients({
		type = "weather_change",
		weather = weather,
	})

	print("[WorldEvent] Weather changed to: " .. weather.name)

	-- Apply luck bonus to all players if present
	if weatherEffects.luckBonus then
		for _, player in Players:GetPlayers() do
			PlayerDataService.applyLuckStreak(player, weatherEffects.luckBonus, 120) -- 2 min streak
		end
	end
end

-- Roll and apply new weather
local function rollWeather()
	local weather = RNGEngine.rollWeather(rng)
	if weather then
		applyWeatherEffects(weather)
	end
end

-- Spawn a wandering NPC near the hub town
local function spawnWanderingNPC()
	local npc = RNGEngine.rollWanderingNPC(rng)
	if not npc then return end

	-- Pick a random position near the hub town entrance
	local angle = RandomUtility.float(0, math.pi * 2, rng)
	local distance = RandomUtility.int(30, 80, rng)
	local spawnPos = Vector3.new(math.cos(angle) * distance, 3, math.sin(angle) * distance)

	-- Create a simple NPC marker
	local marker = Instance.new("Part")
	marker.Name = "WanderingNPC_" .. npc.id
	marker.Size = Vector3.new(4, 8, 4)
	marker.Position = spawnPos
	marker.Anchored = true
	marker.CanCollide = false
	marker.Color = Color3.fromRGB(150, 200, 255)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.3
	marker:SetAttribute("NPCType", npc.type)
	marker:SetAttribute("NPCName", npc.name)
	marker:SetAttribute("NPCId", npc.id)

	-- Add a proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "InteractPrompt"
	prompt.ActionText = "Talk to " .. npc.name
	prompt.ObjectText = npc.name
	prompt.MaxActivationDistance = 10
	prompt.Parent = marker

	marker.Parent = workspace

	-- Notify clients
	worldEventRemote:FireAllClients({
		type = "wandering_npc",
		npc = npc,
		position = spawnPos,
	})

	print("[WorldEvent] Wandering NPC spawned: " .. npc.name .. " (" .. npc.type .. ")")

	-- Remove after 5 minutes
	task.delay(300, function()
		if marker and marker.Parent then
			marker.Parent = nil
		end
	end)
end

-- Roll a random overworld event
local function rollOverworldEvent()
	local event = RNGEngine.rollOverworldEvent(rng)
	if not event then return end

	-- Notify all clients
	worldEventRemote:FireAllClients({
		type = "overworld_event",
		event = event,
	})

	print("[WorldEvent] Overworld event: " .. event.name .. " (" .. event.effect .. ")")

	-- Apply event effects
	if event.effect == "luck_buff" then
		for _, player in Players:GetPlayers() do
			PlayerDataService.applyLuckStreak(player, 15, 300) -- +15 luck for 5 min
		end
	elseif event.effect == "xp_boost" then
		for _, player in Players:GetPlayers() do
			player:SetAttribute("XPBoost", true)
			task.delay(300, function()
				player:SetAttribute("XPBoost", false)
			end)
		end
	elseif event.effect == "heal_all" then
		for _, player in Players:GetPlayers() do
			local char = player.Character
			if char then
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = humanoid.MaxHealth
				end
			end
		end
	elseif event.effect == "free_loot" then
		-- Give all players a small loot drop
		for _, player in Players:GetPlayers() do
			local level = 1
			local pData = PlayerDataService.getData(player)
			if pData then level = pData.level end
			local pLuck = PlayerDataService.getLuck(player)
			local loot = LootService.rollLoot("dungeon_chest", level, rng, pLuck)
			if loot then
				PlayerDataService.addCurrency(player, loot.gold)
				for _, item in loot.items do
					InventoryService.addItem(player, item)
					PlayerDataService.trackItemFound(player, item)
				end
				PlayerDataService.syncInventory(player)
			end
		end
	end
end

-- World event loop: runs every 2-5 minutes
task.spawn(function()
	task.wait(10) -- Initial delay
	while true do
		-- Roll weather every 3-7 minutes
		local weatherInterval = RandomUtility.int(180, 420, rng)
		task.wait(weatherInterval)
		rollWeather()

		-- Roll wandering NPC (separate timing)
		task.spawn(function()
			task.wait(RandomUtility.int(60, 180, rng))
			spawnWanderingNPC()
		end)

		-- Roll overworld event (separate timing)
		task.spawn(function()
			task.wait(RandomUtility.int(120, 300, rng))
			rollOverworldEvent()
		end)
	end
end)

-- Initial weather roll
task.delay(5, function()
	rollWeather()
end)

print("[WorldEvent] System initialized")