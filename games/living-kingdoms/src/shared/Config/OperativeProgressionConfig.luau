--!strict

-- Patch 0.4 durable progression begins with one deliberately small progression
-- map. Rank is derived from already-persisted completed-expedition Boss grant
-- identities, so this foundation adds no second save owner and no permanent raw
-- combat-stat inflation.

local Ranks = table.freeze({
	table.freeze({
		Rank = 1,
		Id = "Initiate",
		DisplayName = "Initiate",
		RequiredCompletedExpeditions = 0,
	}),
	table.freeze({
		Rank = 2,
		Id = "Delver",
		DisplayName = "Delver",
		RequiredCompletedExpeditions = 1,
	}),
	table.freeze({
		Rank = 3,
		Id = "Pathfinder",
		DisplayName = "Pathfinder",
		RequiredCompletedExpeditions = 3,
	}),
	table.freeze({
		Rank = 4,
		Id = "Veteran",
		DisplayName = "Veteran",
		RequiredCompletedExpeditions = 6,
	}),
	table.freeze({
		Rank = 5,
		Id = "Vanguard",
		DisplayName = "Vanguard",
		RequiredCompletedExpeditions = 10,
	}),
})

local Config = {
	Version = "PATCH-0.4-OPERATIVE-RANK-v1",
	DurableRewardGrantPrefix = "reward:",
	CompletedExpeditionSourceId = "Boss",
	Ranks = Ranks,
}

local previousThreshold = -1
for index, rank in Ranks do
	assert(rank.Rank == index, "operative rank ordinals must be contiguous from one")
	assert(type(rank.Id) == "string" and rank.Id ~= "", "operative ranks require stable IDs")
	assert(type(rank.DisplayName) == "string" and rank.DisplayName ~= "", "operative ranks require display names")
	assert(
		type(rank.RequiredCompletedExpeditions) == "number"
			and rank.RequiredCompletedExpeditions >= 0
			and rank.RequiredCompletedExpeditions % 1 == 0,
		"operative rank thresholds must be nonnegative integers"
	)
	assert(rank.RequiredCompletedExpeditions > previousThreshold, "operative rank thresholds must strictly increase")
	previousThreshold = rank.RequiredCompletedExpeditions
end

assert(Ranks[1].RequiredCompletedExpeditions == 0, "rank one must be available before the first clear")
assert(#Ranks >= 2 and #Ranks <= 10, "the initial operative progression map must stay small and testable")
assert(Config.DurableRewardGrantPrefix == "reward:", "rank derivation must match the canonical durable reward grant prefix")
assert(Config.CompletedExpeditionSourceId == "Boss", "completed-expedition rank credit must use the banked Boss grant")

return table.freeze(Config)
