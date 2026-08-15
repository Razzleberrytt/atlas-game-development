--!strict

-- Character XP is intentionally separate from the existing five-rank operative
-- expedition map. Rank remains a bounded unlock projection; character level is
-- the long-horizon numeric progression axis that combat, exploration, quests,
-- events, and future systems can award through the server progression service.

local SourceIds = table.freeze({
	EnemyKill = "EnemyKill",
	Assist = "Assist",
	Quest = "Quest",
	DungeonCompletion = "DungeonCompletion",
	Event = "Event",
	Exploration = "Exploration",
	System = "System",
})

local RewardXP = table.freeze({
	-- Shared co-op enemy-death reward. Individual killer/assist splits can be
	-- layered on once combat exposes a durable contributor ledger.
	EnemyKill = 20,
	Assist = 10,
	DungeonCompletion = 250,
})

local Config = {
	Version = "CHARACTER-XP-v1",
	MinimumLevel = 1,
	MaximumLevel = 1000,

	-- XP required to advance from level L to L + 1 is:
	-- Base + Linear * n + Quadratic * n^2, where n = L - MinimumLevel.
	-- The matching cumulative threshold has a closed form, so resolving even a
	-- very high level never requires a hand-authored table or a linear scan.
	BaseXPToNextLevel = 100,
	LinearXPPerLevel = 25,
	QuadraticXPPerLevelSquared = 1,

	SourceIds = SourceIds,
	RewardXP = RewardXP,
}

assert(Config.MinimumLevel == 1, "character progression currently expects level one as its origin")
assert(Config.MaximumLevel > Config.MinimumLevel, "character progression requires more than one level")
assert(Config.MaximumLevel % 1 == 0, "character level cap must be an integer")
assert(Config.BaseXPToNextLevel > 0 and Config.BaseXPToNextLevel % 1 == 0, "base XP must be a positive integer")
assert(Config.LinearXPPerLevel >= 0 and Config.LinearXPPerLevel % 1 == 0, "linear XP growth must be a nonnegative integer")
assert(
	Config.QuadraticXPPerLevelSquared >= 0 and Config.QuadraticXPPerLevelSquared % 1 == 0,
	"quadratic XP growth must be a nonnegative integer"
)
assert(Config.RewardXP.EnemyKill > 0 and Config.RewardXP.EnemyKill % 1 == 0, "enemy XP must be a positive integer")
assert(Config.RewardXP.Assist > 0 and Config.RewardXP.Assist % 1 == 0, "assist XP must be a positive integer")
assert(
	Config.RewardXP.DungeonCompletion > 0 and Config.RewardXP.DungeonCompletion % 1 == 0,
	"dungeon completion XP must be a positive integer"
)

return table.freeze(Config)
