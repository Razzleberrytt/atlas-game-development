--!strict

-- Patch 0.4 durable progression begins with one deliberately small progression
-- map. Rank and unlock eligibility are derived from already-persisted
-- completed-expedition Boss grant identities, so this foundation adds no second
-- save owner and no permanent raw combat-stat inflation.

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

local UnlockIds = table.freeze({
	SquadRallyPing = "squad-rally-ping",
	DualTacticalMarkers = "squad-dual-tactical-markers",
	FocusedFlashlightBeam = "personal-focused-beam",
})

local Unlocks = table.freeze({
	table.freeze({
		Id = UnlockIds.SquadRallyPing,
		DisplayName = "Rally Ping",
		Description = "Your standard squad ping carries a Rally identity.",
		RequiredRank = 2,
	}),
	table.freeze({
		Id = UnlockIds.DualTacticalMarkers,
		DisplayName = "Dual Tactical Markers",
		Description = "Maintain two personal squad markers at once.",
		RequiredRank = 2,
	}),
	-- The first unlock outside the squad-ping family. Its consequence is owned by
	-- PersonalFlashlightService, proving the rank/unlock seam routes into a
	-- different existing canonical owner without a second persistence authority.
	table.freeze({
		Id = UnlockIds.FocusedFlashlightBeam,
		DisplayName = "Focused Beam",
		Description = "Your personal flashlight reaches farther and wider.",
		RequiredRank = 3,
	}),
})

local Config = {
	Version = "PATCH-0.4-OPERATIVE-RANK-v1",
	DurableRewardGrantPrefix = "reward:",
	CompletedExpeditionSourceId = "Boss",
	Ranks = Ranks,
	UnlockIds = UnlockIds,
	Unlocks = Unlocks,
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

local unlockIds = {}
for _, unlock in Unlocks do
	assert(type(unlock.Id) == "string" and unlock.Id ~= "", "operative unlocks require stable IDs")
	assert(unlockIds[unlock.Id] == nil, "operative unlock IDs must be unique")
	assert(type(unlock.DisplayName) == "string" and unlock.DisplayName ~= "", "operative unlocks require display names")
	assert(type(unlock.Description) == "string" and unlock.Description ~= "", "operative unlocks require descriptions")
	assert(
		type(unlock.RequiredRank) == "number"
			and unlock.RequiredRank >= 1
			and unlock.RequiredRank <= #Ranks
			and unlock.RequiredRank % 1 == 0,
		"operative unlock rank requirements must reference an authored rank"
	)
	unlockIds[unlock.Id] = true
end

assert(Ranks[1].RequiredCompletedExpeditions == 0, "rank one must be available before the first clear")
assert(#Ranks >= 2 and #Ranks <= 10, "the initial operative progression map must stay small and testable")
assert(
	Config.DurableRewardGrantPrefix == "reward:",
	"rank derivation must match the canonical durable reward grant prefix"
)
assert(Config.CompletedExpeditionSourceId == "Boss", "completed-expedition rank credit must use the banked Boss grant")

return table.freeze(Config)
