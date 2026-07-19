--!strict

--[[
	Server-owned tuning for the confirmed Screamer-interruption reward. The bonus
	is intentionally smaller than one ordinary kill so tactical counterplay feels
	valuable without collapsing the four-kill first-upgrade pacing target.
]]

local Config = {
	Version = "HROI-SCREAMER-INTERRUPT-REWARD-v1",
	BonusFieldXp = 10,
	ScanIntervalSeconds = 0.1,
	MaximumTrackedEnemyModels = 64,
	MaximumRewardIdCharacters = 240,
}

assert(
	Config.BonusFieldXp > 0 and Config.BonusFieldXp < 20 and Config.BonusFieldXp % 1 == 0,
	"Screamer interruption must award a positive sub-kill integer bonus"
)
assert(
	Config.ScanIntervalSeconds >= 0.05 and Config.ScanIntervalSeconds <= 0.5,
	"Screamer interruption observation must remain responsive and bounded"
)
assert(
	Config.MaximumTrackedEnemyModels >= 24 and Config.MaximumTrackedEnemyModels <= 64,
	"Screamer interruption observation must cover the bounded enemy population"
)
assert(
	Config.MaximumRewardIdCharacters >= 64 and Config.MaximumRewardIdCharacters <= 240,
	"Screamer interruption reward IDs require a bounded server-only length"
)

return table.freeze(Config)
