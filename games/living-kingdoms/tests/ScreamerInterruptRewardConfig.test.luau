--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local config = luau.load(fs.readFile(
	"games/living-kingdoms/src/shared/Config/ScreamerInterruptRewardConfig.luau"
), {
	debugName = "ScreamerInterruptRewardConfig",
	injectGlobals = true,
})()

assert(config.Version == "HROI-SCREAMER-INTERRUPT-REWARD-v1", "reward config version drifted")
assert(config.BonusFieldXp == 10, "confirmed Screamer interruption must award exactly 10 bonus Field XP")
assert(config.ScanIntervalSeconds == 0.1, "interrupt reward observation cadence drifted")
assert(config.MaximumTrackedEnemyModels == 64, "interrupt reward observation ceiling drifted")
assert(config.MaximumRewardIdCharacters == 240, "interrupt reward ID ceiling drifted")

print("ScreamerInterruptRewardConfig: bounded bonus, cadence, population, and reward ID passed")
