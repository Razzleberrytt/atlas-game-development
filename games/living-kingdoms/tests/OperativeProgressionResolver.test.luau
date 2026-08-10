--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/OperativeProgressionConfig.luau"), {
	debugName = "OperativeProgressionConfig",
	injectGlobals = true,
})()

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/OperativeProgressionResolver.luau"), {
	debugName = "OperativeProgressionResolver",
	injectGlobals = true,
})()

local function boss(runId: string): string
	return string.format("reward:%s:Boss", runId)
end

local function elite(runId: string): string
	return string.format("reward:%s:Elite", runId)
end

assertThat(config.Version == "PATCH-0.4-OPERATIVE-RANK-v1", "operative progression config version must be stable")
assertThat(#config.Ranks == 5, "initial progression map should stay deliberately small")
assertThat(config.Ranks[1].RequiredCompletedExpeditions == 0, "rank one must be available immediately")
assertThat(config.Ranks[5].RequiredCompletedExpeditions == 10, "initial rank map should cap at ten clears")

local fresh = resolver.resolve(config, {})
assertThat(fresh.Accepted, "empty durable ledger must resolve")
assertThat(fresh.CompletedExpeditions == 0, "fresh operative should have zero completed expeditions")
assertThat(fresh.Rank == 1 and fresh.RankId == "Initiate", "fresh operative should begin at Initiate")
assertThat(fresh.NextRank == 2 and fresh.NextRankId == "Delver", "fresh operative should anticipate Delver")
assertThat(fresh.CompletedExpeditionsToNextRank == 1, "first durable rank should be one clear away")
assertThat(not fresh.IsMaximumRank, "fresh operative must not be maximum rank")

local firstClear = resolver.resolve(config, {
	elite("expedition:alpha"),
	boss("expedition:alpha"),
})
assertThat(firstClear.Accepted, "banked first clear must resolve")
assertThat(firstClear.CompletedExpeditions == 1, "Elite and Boss rewards from one run must count as one completion")
assertThat(firstClear.Rank == 2 and firstClear.RankId == "Delver", "one clear should promote to Delver")
assertThat(firstClear.CompletedExpeditionsToNextRank == 2, "Delver should see two clears to Pathfinder")

local duplicateAndNoise = resolver.resolve(config, {
	boss("expedition:alpha"),
	boss("expedition:alpha"),
	elite("expedition:alpha"),
	"reward:expedition:alpha:BossExtra",
	"not-a-reward:expedition:beta:Boss",
	boss("expedition:beta"),
	boss("expedition:gamma"),
})
assertThat(duplicateAndNoise.Accepted, "valid string ledger with unrelated grants must resolve")
assertThat(duplicateAndNoise.CompletedExpeditions == 3, "duplicate and non-Boss identities must not inflate clears")
assertThat(duplicateAndNoise.Rank == 3 and duplicateAndNoise.RankId == "Pathfinder", "three clears should promote")
assertThat(duplicateAndNoise.NextRankRequiredCompletedExpeditions == 6, "Pathfinder should point at Veteran threshold")
assertThat(duplicateAndNoise.CompletedExpeditionsToNextRank == 3, "Pathfinder should show exact remaining clears")

local sixClears = {}
for index = 1, 6 do
	table.insert(sixClears, boss("expedition:run:" .. tostring(index)))
end
local veteran = resolver.resolve(config, sixClears)
assertThat(veteran.Accepted and veteran.RankId == "Veteran", "six unique Boss grants should resolve Veteran")
assertThat(veteran.CompletedExpeditionsToNextRank == 4, "Veteran should be four clears from Vanguard")

local tenClears = {}
for index = 1, 10 do
	table.insert(tenClears, boss("expedition:run:" .. tostring(index)))
end
local vanguard = resolver.resolve(config, tenClears)
assertThat(vanguard.Accepted, "maximum rank ledger must resolve")
assertThat(vanguard.CompletedExpeditions == 10, "maximum-rank clear count must remain visible")
assertThat(vanguard.Rank == 5 and vanguard.RankId == "Vanguard", "ten clears should reach Vanguard")
assertThat(vanguard.NextRank == nil and vanguard.CompletedExpeditionsToNextRank == nil, "maximum rank has no fake next step")
assertThat(vanguard.IsMaximumRank, "ten clears should report maximum rank")

local beyondCap = table.clone(tenClears)
for index = 11, 15 do
	table.insert(beyondCap, boss("expedition:run:" .. tostring(index)))
end
local capped = resolver.resolve(config, beyondCap)
assertThat(capped.Rank == 5 and capped.CompletedExpeditions == 15, "rank cap must not discard lifetime completion truth")

local malformedLedger = resolver.resolve(config, { boss("expedition:alpha"), 42 })
assertThat(not malformedLedger.Accepted, "non-string durable grant identity must fail closed")
assertThat(malformedLedger.ReasonId == "InvalidGrantLedger", "malformed ledger reason must be stable")

local malformedConfig = {
	Version = "bad",
	DurableRewardGrantPrefix = "reward:",
	CompletedExpeditionSourceId = "Boss",
	Ranks = {
		{ Rank = 1, Id = "one", DisplayName = "One", RequiredCompletedExpeditions = 0 },
		{ Rank = 2, Id = "two", DisplayName = "Two", RequiredCompletedExpeditions = 0 },
	},
}
local rejectedConfig = resolver.resolve(malformedConfig, {})
assertThat(not rejectedConfig.Accepted, "duplicate rank thresholds must fail closed")
assertThat(rejectedConfig.ReasonId == "InvalidConfig", "invalid progression config reason must be stable")
