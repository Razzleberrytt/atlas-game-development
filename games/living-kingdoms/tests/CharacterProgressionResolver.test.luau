--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/CharacterProgressionConfig.luau"), {
	debugName = "CharacterProgressionConfig",
	injectGlobals = true,
})()
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/CharacterProgressionResolver.luau"), {
	debugName = "CharacterProgressionResolver",
	injectGlobals = true,
})()

assertThat(config.MinimumLevel == 1, "leveling must begin at level one")
assertThat(config.MaximumLevel == 1000, "default character cap must support long-horizon progression")
assertThat(resolver.totalXPForLevel(1, config) == 0, "level one threshold must be zero total XP")
assertThat(resolver.xpToNextLevel(1, config) == 100, "level one must require the configured base XP")
assertThat(resolver.totalXPForLevel(2, config) == 100, "level two boundary must equal level-one requirement")

local below = resolver.normalizeState({ TotalXP = 99 }, config)
assertThat(below.Level == 1 and below.XPIntoLevel == 99, "XP below the first boundary must stay level one")
assertThat(below.XPRemainingToNextLevel == 1, "boundary remainder must be exact")

local boundary = resolver.normalizeState({ TotalXP = 100 }, config)
assertThat(boundary.Level == 2 and boundary.XPIntoLevel == 0, "exact threshold must advance exactly one level")

local targetFive = resolver.totalXPForLevel(5, config)
assertThat(type(targetFive) == "number", "level-five threshold must resolve")
local multi = resolver.awardXP(nil, (targetFive :: number) + 7, config)
assertThat(multi.Accepted == true, "large valid XP award must be accepted")
assertThat(multi.State.Level == 5, "large award must resolve all crossed levels")
assertThat(multi.State.XPIntoLevel == 7, "large award must preserve remainder within the final level")
assertThat(multi.LevelsGained == 4 and #multi.LevelUps == 4, "large award must report every gained level")
assertThat(multi.LevelUps[1] == 2 and multi.LevelUps[4] == 5, "level-up hook payload must be ordered")

local malformed = resolver.normalizeState({ TotalXP = "broken", Level = 900 }, config)
assertThat(malformed.Level == 1 and malformed.TotalXP == 0, "malformed canonical XP must fail closed")
assertThat(malformed.RecoveredState == true and malformed.RecoveryReasonId == "InvalidTotalXP", "repair reason must be explicit")

local legacy = resolver.normalizeState({ Level = 10 }, config)
assertThat(legacy.Level == 10, "legacy level-only state must migrate to the same bounded level")
assertThat(legacy.TotalXP == resolver.totalXPForLevel(10, config), "legacy level migration must use canonical threshold")
assertThat(legacy.RecoveredState == true, "legacy state must be marked as recovered")

for _, invalid in { -1, 0, 0 / 0, math.huge, -math.huge, "100" } do
	local rejected = resolver.awardXP({ TotalXP = 25 }, invalid, config)
	assertThat(rejected.Accepted == false and rejected.ReasonId == "InvalidXPAward", "invalid XP input must reject")
	assertThat(rejected.State.TotalXP == 25, "invalid XP input must not mutate progression")
end

local capXP = resolver.totalXPForLevel(config.MaximumLevel, config)
assertThat(type(capXP) == "number" and capXP > 0, "cap threshold must resolve")
local huge = resolver.awardXP(nil, 1e300, config)
assertThat(huge.Accepted == true and huge.ReasonId == "XPClampedAtLevelCap", "huge finite XP must safely clamp")
assertThat(huge.State.Level == config.MaximumLevel and huge.State.TotalXP == capXP, "huge XP must land exactly at cap")
assertThat(huge.State.IsLevelCap == true and huge.State.XPRemainingToNextLevel == 0, "cap state must expose no phantom next level")
local capped = resolver.awardXP(huge.State, 1, config)
assertThat(capped.Accepted == false and capped.ReasonId == "LevelCapReached", "XP at cap must reject without overflow")

for _, level in { 1, 2, 10, 100, 500, 999, 1000 } do
	local threshold = resolver.totalXPForLevel(level, config)
	assertThat(type(threshold) == "number", "sample threshold must resolve")
	local atThreshold = resolver.normalizeState({ TotalXP = threshold }, config)
	assertThat(atThreshold.Level == level, "threshold and level resolution must be consistent")
	if level > 1 then
		local beforeThreshold = resolver.normalizeState({ TotalXP = (threshold :: number) - 1 }, config)
		assertThat(beforeThreshold.Level == level - 1, "one XP below a threshold must resolve to prior level")
	end
end

for level = 1, 999 do
	local current = resolver.xpToNextLevel(level, config)
	local nextRequirement = if level < 999 then resolver.xpToNextLevel(level + 1, config) else nil
	assertThat(type(current) == "number" and current > 0, "every non-cap level needs positive XP")
	if nextRequirement ~= nil then
		assertThat((nextRequirement :: number) > (current :: number), "configured XP curve must increase monotonically")
	end
end

print("CharacterProgressionResolver: thresholds, migration, multi-level awards, cap, invalid input, and consistency passed")
