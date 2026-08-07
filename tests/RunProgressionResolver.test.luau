--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "HROI-0105 run progression resolver assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau"), {
	debugName = "RunProgressionConfig",
	injectGlobals = true,
})()

local CONFIG_TOKEN = {}
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/RunProgressionResolver.luau"), {
	debugName = "RunProgressionResolver",
	environment = {
		script = {
			Parent = {
				Parent = {
					Config = { RunProgressionConfig = CONFIG_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			assert(token == CONFIG_TOKEN, "unexpected progression resolver dependency")
			return config
		end,
	},
	injectGlobals = true,
})()

assert(config.FieldXpPerConfirmedEnemyDeath == 20, "one confirmed death should award 20 Field XP")
assert(
	config.BaseXpToLevel / config.FieldXpPerConfirmedEnemyDeath == 4,
	"the first upgrade should require four ordinary confirmed deaths"
)
assert(resolver.xpRequiredForLevel(1) == 80, "the first run level should require 80 XP")
assert(resolver.xpRequiredForLevel(2) == 112, "the second threshold should slow later upgrade frequency")
assert(resolver.xpRequiredForLevel(config.MaximumRunLevel) == 0, "maximum level has no next threshold")

local oneKill = resolver.applyAward(1, 0, config.FieldXpPerConfirmedEnemyDeath)
assert(oneKill.didApply and oneKill.levelAfter == 1 and oneKill.xpAfter == 20)
assert(oneKill.levelsGained == 0 and oneKill.xpForNextLevel == 80)
assert(table.isfrozen(oneKill), "award results must be immutable")

local firstLevel = resolver.applyAward(1, 60, config.FieldXpPerConfirmedEnemyDeath)
assert(firstLevel.didApply and firstLevel.levelAfter == 2 and firstLevel.xpAfter == 0)
assert(firstLevel.levelsGained == 1 and firstLevel.xpForNextLevel == 112)

local multipleLevels = resolver.applyAward(1, 70, 150)
assert(multipleLevels.didApply and multipleLevels.levelAfter == 3 and multipleLevels.xpAfter == 28)
assert(multipleLevels.levelsGained == 2)

local invalid = resolver.applyAward(1, 0, 0)
assert(not invalid.didApply and invalid.rejectionReasonId == "InvalidProgressionFacts")

local maximum = resolver.applyAward(1, 0, 100000000)
assert(maximum.didApply and maximum.levelAfter == config.MaximumRunLevel)
assert(maximum.xpAfter == 0 and maximum.xpForNextLevel == 0)

print("RunProgressionResolver: first-upgrade pacing, carryover, validation, and level cap passed")
