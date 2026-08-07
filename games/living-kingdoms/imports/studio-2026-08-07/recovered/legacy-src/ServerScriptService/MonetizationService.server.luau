--[[
	MonetizationService - Server-side handler for GamePasses and Developer Products
	Handles purchase verification, VIP benefits, and product delivery.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShopNetwork = ReplicatedStorage:WaitForChild("ShopNetwork")

-- RNG modules
local RNGEngine
local RandomUtility
local PlayerDataService
local success1, mod1 = pcall(function()
	return require(ReplicatedStorage.Shared.Utility.RNGEngine)
end)
if success1 then RNGEngine = mod1 end
local success2, mod2 = pcall(function()
	return require(ReplicatedStorage.Shared.Utility.RandomUtility)
end)
if success2 then RandomUtility = mod2 end
local success3, mod3 = pcall(function()
	return require(ServerScriptService.Services.PlayerDataService)
end)
if success3 then PlayerDataService = mod3 end

local rng = Random.new()

-- ============================================================
-- CONFIG: Replace these placeholder IDs with your actual IDs
-- ============================================================

local GAMEPASS_IDS = {
	VIP_2X = 0,           -- VIP: 2x Gold & XP
	EXTRA_INVENTORY = 0,  -- Extra Inventory Space
	STARTER_PACK = 0,     -- Starter Pack (bonus items + gold)
}

local PRODUCT_IDS = {
	GOLD_SMALL = 0,    -- 500 Gold
	GOLD_MEDIUM = 0,   -- 1500 Gold
	GOLD_LARGE = 0,    -- 5000 Gold
	POTIONS_10 = 0,    -- 10 Health Potions
	POTIONS_50 = 0,    -- 50 Health Potions
	REVIVE_CRYSTAL = 0, -- Revive Crystal (instant respawn)
	LOOT_BOX_BASIC = 0,    -- Basic Mystery Loot Box
	LOOT_BOX_PREMIUM = 0,  -- Premium Mystery Loot Box
	LOOT_BOX_LEGENDARY = 0, -- Legendary Mystery Loot Box
	LUCK_POTION = 0,       -- Temporary Luck Boost Potion
}

-- Product delivery amounts
local PRODUCT_REWARDS = {
	[PRODUCT_IDS.GOLD_SMALL] = { type = "gold", amount = 500 },
	[PRODUCT_IDS.GOLD_MEDIUM] = { type = "gold", amount = 1500 },
	[PRODUCT_IDS.GOLD_LARGE] = { type = "gold", amount = 5000 },
	[PRODUCT_IDS.POTIONS_10] = { type = "item", item = "Minor Health Potion", amount = 10 },
	[PRODUCT_IDS.POTIONS_50] = { type = "item", item = "Minor Health Potion", amount = 50 },
	[PRODUCT_IDS.REVIVE_CRYSTAL] = { type = "item", item = "Revive Crystal", amount = 1 },
	[PRODUCT_IDS.LOOT_BOX_BASIC] = { type = "loot_box", tier = 1 },
	[PRODUCT_IDS.LOOT_BOX_PREMIUM] = { type = "loot_box", tier = 2 },
	[PRODUCT_IDS.LOOT_BOX_LEGENDARY] = { type = "loot_box", tier = 3 },
	[PRODUCT_IDS.LUCK_POTION] = { type = "luck_potion", amount = 10, duration = 600 },
}

-- ============================================================
-- STATE
-- ============================================================

local VIPPlayers = {}  -- Track VIP status per player

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

local function getPlayerData(player)
	local playerDataService = ServerScriptService:FindFirstChild("Services")
	if playerDataService then
		local playerDataModule = playerDataService:FindFirstChild("PlayerDataService")
		if playerDataModule then
			-- Try to access player data through the service
			local success, result = pcall(function()
				return require(playerDataModule)
			end)
			if success and result and result.GetPlayerData then
				return result:GetPlayerData(player)
			end
		end
	end
	return nil
end

local function grantGold(player, amount)
	if PlayerDataService then
		local total, bonus = PlayerDataService.addCurrency(player, amount)
		return true, bonus
	end
	-- Fallback: try to find gold in player's attributes
	local currentGold = player:GetAttribute("Gold") or 0
	player:SetAttribute("Gold", currentGold + amount)
	return true
end

local function grantItem(player, itemName, amount)
	local data = getPlayerData(player)
	if data and data.Inventory then
		for i = 1, amount do
			table.insert(data.Inventory, {
				Name = itemName,
				Rarity = "Common",
				Type = "Consumable",
			})
		end
		return true
	end
	-- Fallback: set attribute
	local currentCount = player:GetAttribute(itemName .. "_Count") or 0
	player:SetAttribute(itemName .. "_Count", currentCount + amount)
	return true
end

-- Grant loot box contents using RNG
local function grantLootBox(player, tier)
	if not RNGEngine then
		grantGold(player, 500 * tier)
		return {gold = 500 * tier, items = {}}
	end

	local luck = 0
	if PlayerDataService then
		luck = PlayerDataService.getLuck(player)
	end

	local result = RNGEngine.rollLootBox(tier, luck, rng)

	-- Grant gold from the box
	if result.gold > 0 then
		grantGold(player, result.gold)
	end

	-- Track items found
	if PlayerDataService then
		for _, item in ipairs(result.items) do
			PlayerDataService.trackItemFound(player, item)
		end
	end

	return result
end

-- Apply luck potion effect
local function grantLuckPotion(player, amount, duration)
	if PlayerDataService then
		PlayerDataService.applyLuckStreak(player, amount, duration)
		return true
	end
	-- Fallback: set attribute
	player:SetAttribute("LuckStreak", amount)
	player:SetAttribute("LuckStreakExpiry", os.time() + duration)
	return true
end

local function isVIP(player)
	return VIPPlayers[player.UserId] == true
end

local function checkGamePasses(player)
	-- Check VIP gamepass
	if GAMEPASS_IDS.VIP_2X ~= 0 then
		local success, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_IDS.VIP_2X)
			end)
		if success and owns then
			VIPPlayers[player.UserId] = true
			ShopNetwork.UpdateVIP:FireClient(player, true)
		end
	end
end

-- ============================================================
-- DEVELOPER PRODUCT PROCESSING
-- ============================================================

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left the game; don't complete purchase
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId
	local reward = PRODUCT_REWARDS[productId]

	if reward then
		local bonusMessage = ""

		-- RNG: Roll for purchase bonus
		local purchaseBonus = nil
		if RNGEngine then
			purchaseBonus = RNGEngine.rollPurchaseBonus(rng)
		end

		if reward.type == "gold" then
			local goldAmount = reward.amount
			if purchaseBonus and purchaseBonus.type == "gold_mult" then
				goldAmount = math.floor(goldAmount * purchaseBonus.multiplier)
			elseif purchaseBonus and purchaseBonus.type == "double_rewards" then
				goldAmount = goldAmount * 2
			end
			grantGold(player, goldAmount)
			bonusMessage = goldAmount > reward.amount and string.format(" (BONUS: %d Gold!)", goldAmount) or ""

		elseif reward.type == "item" then
			local itemCount = reward.amount
			if purchaseBonus and purchaseBonus.type == "extra_items" then
				itemCount = itemCount + purchaseBonus.count
			elseif purchaseBonus and purchaseBonus.type == "double_rewards" then
				itemCount = itemCount * 2
			end
			grantItem(player, reward.item, itemCount)
			bonusMessage = itemCount > reward.amount and string.format(" (BONUS: %d extra!)", itemCount - reward.amount) or ""

		elseif reward.type == "loot_box" then
			local boxResult = grantLootBox(player, reward.tier)
			local itemSummary = #boxResult.items .. " items"
			if boxResult.gold > 0 then
				itemSummary = itemSummary .. " + " .. boxResult.gold .. " Gold"
			end
			bonusMessage = " - Opened: " .. itemSummary

		elseif reward.type == "luck_potion" then
			local amount = reward.amount
			if purchaseBonus and purchaseBonus.type == "double_rewards" then
				amount = amount * 2
			end
			grantLuckPotion(player, amount, reward.duration)
			bonusMessage = string.format(" +%d Luck for %d minutes!", amount, reward.duration / 60)
		end

		-- Apply luck streak bonus from purchase bonus
		if purchaseBonus and purchaseBonus.type == "luck_streak" then
			grantLuckPotion(player, purchaseBonus.amount, purchaseBonus.duration)
			bonusMessage = bonusMessage .. string.format(" (LUCKY: +%d Luck streak!)", purchaseBonus.amount)
		end

		-- Notify client of successful purchase
		ShopNetwork.ShopResult:FireClient(player, {
			success = true,
			message = "Purchase successful!" .. bonusMessage,
		})

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Unknown product
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt

-- ============================================================
-- GAMEPASS PURCHASE HANDLING
-- ============================================================

ShopNetwork.BuyGamePass.OnServerEvent:Connect(function(player, gamepassKey)
	local gamepassId = GAMEPASS_IDS[gamepassKey]
	if not gamepassId or gamepassId == 0 then
		ShopNetwork.ShopResult:FireClient(player, {
			success = false,
			message = "This GamePass is not yet available.",
		})
		return
	end

	-- Prompt purchase on the client side (MarketplaceService:PromptGamePassPurchase)
	-- The client will handle the prompt; we just validate here
	-- Actually, we need to prompt from server or client
	-- MarketplaceService:PromptGamePassPurchase must be called from server in some contexts
	MarketplaceService:PromptGamePassPurchase(player, gamepassId)
end)

-- Handle GamePass purchase finished
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, isPurchased)
	if isPurchased then
		if gamepassId == GAMEPASS_IDS.VIP_2X then
			VIPPlayers[player.UserId] = true
			ShopNetwork.UpdateVIP:FireClient(player, true)
			ShopNetwork.ShopResult:FireClient(player, {
				success = true,
				message = "VIP activated! You now earn 2x Gold and XP!",
			})
		elseif gamepassId == GAMEPASS_IDS.EXTRA_INVENTORY then
			player:SetAttribute("ExtraInventory", true)
			ShopNetwork.ShopResult:FireClient(player, {
				success = true,
				message = "Extra Inventory unlocked!",
			})
		elseif gamepassId == GAMEPASS_IDS.STARTER_PACK then
			grantGold(player, 1000)
			grantItem(player, "Minor Health Potion", 5)
			ShopNetwork.ShopResult:FireClient(player, {
				success = true,
				message = "Starter Pack claimed! +1000 Gold, +5 Health Potions",
			})
		end
	else
		ShopNetwork.ShopResult:FireClient(player, {
			success = false,
			message = "Purchase cancelled.",
		})
	end
end)

-- ============================================================
-- DEVELOPER PRODUCT PURCHASE HANDLING
-- ============================================================

ShopNetwork.BuyProduct.OnServerEvent:Connect(function(player, productKey)
	local productId = PRODUCT_IDS[productKey]
	if not productId or productId == 0 then
		ShopNetwork.ShopResult:FireClient(player, {
			success = false,
			message = "This product is not yet available.",
		})
		return
	end

	MarketplaceService:PromptProductPurchase(player, productId)
end)

-- ============================================================
-- MERCHANT PROXIMITY PROMPT HANDLING
-- ============================================================

local function setupMerchantPrompt()
	local hub = workspace:FindFirstChild("HubTown")
	if not hub then return end
	local merchant = hub:FindFirstChild("merchant")
	if not merchant then return end
	local npc = merchant:FindFirstChild("NPC")
	if not npc then return end
	local torso = npc:FindFirstChild("Torso")
	if not torso then return end
	local prompt = torso:FindFirstChild("ShopPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		ShopNetwork.OpenShop:FireClient(player)
	end)
end

setupMerchantPrompt()

-- Re-setup if merchant is added later
workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "ShopPrompt" and descendant:IsA("ProximityPrompt") then
		descendant.Triggered:Connect(function(player)
			ShopNetwork.OpenShop:FireClient(player)
		end)
	end
end)

-- ============================================================
-- PLAYER CONNECTIONS
-- ============================================================

local function onPlayerAdded(player)
	-- Check existing gamepass ownership
	task.defer(function()
		checkGamePasses(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	VIPPlayers[player.UserId] = nil
end)

-- ============================================================
-- PUBLIC API (for other server scripts)
-- ============================================================

-- Export VIP check function via attribute/module
_G.MonetizationService = {
	IsVIP = isVIP,
	GetGoldMultiplier = function(player)
		return isVIP(player) and 2 or 1
	end,
	GetXPMultiplier = function(player)
		return isVIP(player) and 2 or 1
	end,
	GetLuckBonus = function(player)
		return isVIP(player) and 5 or 0 -- VIP gets +5 base luck
	end,
	RollLootBox = function(player, tier)
		return grantLootBox(player, tier)
	end,
}

print("[MonetizationService] Initialized successfully with RNG rewards")