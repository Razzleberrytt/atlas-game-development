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

local resolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/OperativeProgressionResolver.luau"), {
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
assertThat(
	vanguard.NextRank == nil and vanguard.CompletedExpeditionsToNextRank == nil,
	"maximum rank has no fake next step"
)
assertThat(vanguard.IsMaximumRank, "ten clears should report maximum rank")

local beyondCap = table.clone(tenClears)
for index = 11, 15 do
	table.insert(beyondCap, boss("expedition:run:" .. tostring(index)))
end
local capped = resolver.resolve(config, beyondCap)
assertThat(
	capped.Rank == 5 and capped.CompletedExpeditions == 15,
	"rank cap must not discard lifetime completion truth"
)

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
assertThat(
	type(rejectedConfig.Unlocks) == "table" and #rejectedConfig.Unlocks == 0 and rejectedConfig.EarnedUnlockCount == 0,
	"a rejected snapshot must disclose no entitlement at all"
)

-- Unlock projection: the resolver is the single owner of the entitlement rule, so
-- both the server check and the progression map read the same resolved answer.
local function unlockById(snapshot: any, unlockId: string): any?
	for _, unlock in snapshot.Unlocks do
		if unlock.Id == unlockId then
			return unlock
		end
	end
	return nil
end

assertThat(#config.Unlocks > 0, "the durable progression map must author unlocks")
assertThat(fresh.TotalUnlockCount == #config.Unlocks, "every authored unlock must be disclosed")
assertThat(fresh.EarnedUnlockCount == 0, "a fresh operative holds no unlocks")
for _, unlock in fresh.Unlocks do
	assertThat(not unlock.IsEarned, "rank one must not earn a rank-two-or-higher unlock")
	assertThat(
		type(unlock.DisplayName) == "string" and type(unlock.Description) == "string",
		"disclosed unlocks must carry their authored presentation copy"
	)
end

local previousRequiredRank = 0
for _, unlock in vanguard.Unlocks do
	assertThat(unlock.RequiredRank >= previousRequiredRank, "disclosed unlocks must be ordered by required rank")
	previousRequiredRank = unlock.RequiredRank
	assertThat(unlock.IsEarned, "maximum rank must earn every authored unlock")
end
assertThat(vanguard.EarnedUnlockCount == vanguard.TotalUnlockCount, "maximum rank must report a complete unlock ledger")

-- Rank boundaries: an unlock is held at exactly its required rank, not one later.
assertThat(unlockById(firstClear, "squad-rally-ping").IsEarned, "rank two earns its own rank-two unlock")
assertThat(not unlockById(firstClear, "personal-focused-beam").IsEarned, "rank two must not earn a rank-three unlock")
assertThat(firstClear.EarnedUnlockCount == 2, "rank two earns exactly the two authored rank-two unlocks")
assertThat(unlockById(duplicateAndNoise, "personal-focused-beam").IsEarned, "rank three earns the rank-three unlock")
assertThat(
	not unlockById(duplicateAndNoise, "medic-self-treatment").IsEarned,
	"rank three must not earn the rank-four unlock"
)
assertThat(unlockById(veteran, "medic-self-treatment").IsEarned, "rank four earns the rank-four unlock")

assertThat(table.isfrozen(fresh.Unlocks), "the disclosed unlock list must be immutable")
assertThat(table.isfrozen(fresh.Unlocks[1]), "each disclosed unlock must be immutable")

-- A config without unlocks still resolves rank, and a malformed unlock list fails
-- the whole snapshot closed rather than disclosing a partial entitlement set.
local rankOnlyConfig = {
	Version = config.Version,
	DurableRewardGrantPrefix = config.DurableRewardGrantPrefix,
	CompletedExpeditionSourceId = config.CompletedExpeditionSourceId,
	Ranks = config.Ranks,
}
local rankOnly = resolver.resolve(rankOnlyConfig, { boss("expedition:alpha") })
assertThat(rankOnly.Accepted and rankOnly.Rank == 2, "a partial runtime may resolve rank without unlocks")
assertThat(rankOnly.TotalUnlockCount == 0 and #rankOnly.Unlocks == 0, "an unlock-free config discloses no unlocks")

for _, malformedUnlocks in
	{
		{ { Id = "", DisplayName = "A", Description = "B", RequiredRank = 1 } },
		{
			{ Id = "dup", DisplayName = "A", Description = "B", RequiredRank = 1 },
			{ Id = "dup", DisplayName = "A", Description = "B", RequiredRank = 2 },
		},
		{ { Id = "a", DisplayName = "A", Description = "B", RequiredRank = 0 } },
		{ { Id = "a", DisplayName = "A", Description = "B", RequiredRank = #config.Ranks + 1 } },
		{ { Id = "a", DisplayName = "A", Description = "B", RequiredRank = 1.5 } },
		{ { Id = "a", DisplayName = "", Description = "B", RequiredRank = 1 } },
		{ { Id = "a", DisplayName = "A", Description = "", RequiredRank = 1 } },
		{ "not-a-table" },
	}
do
	local malformed = {
		Version = config.Version,
		DurableRewardGrantPrefix = config.DurableRewardGrantPrefix,
		CompletedExpeditionSourceId = config.CompletedExpeditionSourceId,
		Ranks = config.Ranks,
		Unlocks = malformedUnlocks,
	}
	local resolved = resolver.resolve(malformed, {})
	assertThat(
		not resolved.Accepted and resolved.ReasonId == "InvalidConfig",
		"a malformed unlock list must fail closed"
	)
end
