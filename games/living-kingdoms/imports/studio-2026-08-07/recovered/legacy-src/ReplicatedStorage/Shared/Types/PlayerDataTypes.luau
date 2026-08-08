-- PlayerDataTypes: Type definitions and helpers for player data in LivingKingdoms
-- Provides default data creation, leveling formulas, and luck stat management

local PlayerDataTypes = {}

-- XP required for a given level (exponential curve)
function PlayerDataTypes.expForLevel(level)
	level = level or 1
	if level <= 1 then return 100 end
	return math.floor(100 * (level ^ 1.5) + (level - 1) * 50)
end

-- Convert total XP into (level, expInCurrentLevel)
function PlayerDataTypes.levelFromExp(totalExp)
	totalExp = totalExp or 0
	local level = 1
	local remaining = totalExp
	local needed = PlayerDataTypes.expForLevel(1)

	while remaining >= needed do
		remaining = remaining - needed
		level = level + 1
		needed = PlayerDataTypes.expForLevel(level)
	end

	return level, remaining
end

-- Create default player data with RNG-friendly fields
function PlayerDataTypes.createDefault()
	return {
		level = 1,
		experience = 0,
		currency = 0,           -- Gold
		essence = 0,           -- Dismantling currency
		luck = 0,              -- RNG luck stat (feeds into all RNG systems)
		inventory = {},        -- Array of item tables
		equipment = {},        -- {Primary, Secondary, Melee, Helmet, Chest, Boots, Relic}
		completedQuests = 0,   -- Total quests completed
		activeQuests = {},     -- Currently active quests
		dungeonRuns = 0,       -- Total dungeon runs completed
		enemiesKilled = 0,     -- Total enemies killed
		-- RNG tracking stats
		bestRarityFound = "Common",
		totalItemsFound = 0,
		corruptedItemsFound = 0,
		setItemsFound = 0,
		mysteryItemsFound = 0,
		-- Streak/luck modifiers (temporary buffs from events, consumables, etc.)
		luckStreak = 0,        -- Temporary luck bonus that decays
		luckStreakExpiry = 0,   -- When the streak expires (os.time())
	}
end

-- Get effective luck (base + streak, if not expired)
function PlayerDataTypes.getEffectiveLuck(data)
	if not data then return 0 end
	local luck = data.luck or 0
	if data.luckStreak and data.luckStreakExpiry and os.time() < data.luckStreakExpiry then
		luck = luck + data.luckStreak
	end
	return luck
end

-- Apply a temporary luck streak
function PlayerDataTypes.applyLuckStreak(data, amount, durationSeconds)
	if not data then return end
	durationSeconds = durationSeconds or 300 -- default 5 minutes
	data.luckStreak = (data.luckStreak or 0) + amount
	data.luckStreakExpiry = os.time() + durationSeconds
end

-- Check and decay expired luck streaks
function PlayerDataTypes.decayLuckStreak(data)
	if not data then return end
	if data.luckStreakExpiry and os.time() >= data.luckStreakExpiry then
		data.luckStreak = 0
		data.luckStreakExpiry = 0
	end
end

-- Update best rarity found (returns true if new best)
function PlayerDataTypes.updateBestRarity(data, rarity)
	if not data or not rarity then return false end
	local order = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Corrupted = 7}
	local current = order[data.bestRarityFound or "Common"] or 1
	local new = order[rarity] or 1
	if new > current then
		data.bestRarityFound = rarity
		return true
	end
	return false
end

return PlayerDataTypes