--!strict

--[[
	P10-0101 shared balance and structure home for the terminal match loop. The
	extraction arrival window and the documented cleanup stop order live here as
	server-owned, configuration-driven values. Prototype authoring intent, not
	promises: the P12 pass confirms them against evidence.
]]

local MatchResultContracts = require(script.Parent.Parent.Mission.MatchResultContracts)

local CleanupOwnerIds = MatchResultContracts.CleanupOwnerIds

local MatchResultConfig = {
	Version = "P10-0105-v1",
	-- After the boss is defeated, extraction is inbound for this window before the
	-- squad extracts. Long enough to be a readable payoff, short enough that a
	-- wiped squad still loses.
	ExtractionArrivalWindowSeconds = 15,
	-- After a result is disclosed the squad reads the debrief for this long, then
	-- the operation restarts deterministically. Long enough to read the result,
	-- short enough that a resolved server never sits dead.
	ReplayDebriefSeconds = 20,
	-- The documented terminal stop order (P10-0105). Enemies and pressure stand
	-- down first; the mission director tears itself down last. Every cleanup owner
	-- appears exactly once.
	CleanupStopOrder = table.freeze({
		CleanupOwnerIds.EnemyDirector,
		CleanupOwnerIds.Objectives,
		CleanupOwnerIds.AmmunitionCaches,
		CleanupOwnerIds.Classes,
		CleanupOwnerIds.ReviveSessions,
		CleanupOwnerIds.OperativeLife,
		CleanupOwnerIds.SquadFailure,
		CleanupOwnerIds.ContributionRecord,
		CleanupOwnerIds.MissionDirector,
	}),
	-- The replay start order. It is not the reverse of the stop order: an owner
	-- that tears down late may still need to start early (the mission director
	-- reads the frozen roster and pressure owners it starts after). Every cleanup
	-- owner appears exactly once here too.
	ReplayStartOrder = table.freeze({
		CleanupOwnerIds.OperativeLife,
		CleanupOwnerIds.SquadFailure,
		CleanupOwnerIds.ReviveSessions,
		CleanupOwnerIds.EnemyDirector,
		CleanupOwnerIds.ContributionRecord,
		CleanupOwnerIds.AmmunitionCaches,
		CleanupOwnerIds.Objectives,
		CleanupOwnerIds.MissionDirector,
		CleanupOwnerIds.Classes,
	}),
}

assert(
	MatchResultConfig.ReplayDebriefSeconds > 0 and MatchResultConfig.ReplayDebriefSeconds <= 60,
	"the debrief window must be readable without stranding a resolved server"
)

assert(
	MatchResultConfig.ExtractionArrivalWindowSeconds > 0
		and MatchResultConfig.ExtractionArrivalWindowSeconds < math.huge,
	"the extraction arrival window must be a bounded positive duration"
)

-- The stop order must cover every declared cleanup owner exactly once, so no owner
-- is skipped and none is torn down twice.
local seenOwners: { [string]: boolean } = {}
for _, ownerId in MatchResultConfig.CleanupStopOrder do
	assert(CleanupOwnerIds[ownerId] == ownerId, "cleanup stop order contains an unknown owner: " .. tostring(ownerId))
	assert(not seenOwners[ownerId], "cleanup stop order lists an owner twice: " .. tostring(ownerId))
	seenOwners[ownerId] = true
end
local declaredOwnerCount = 0
for _ in CleanupOwnerIds do
	declaredOwnerCount += 1
end
assert(#MatchResultConfig.CleanupStopOrder == declaredOwnerCount, "the stop order must cover every cleanup owner")

-- The start order must cover the same owners exactly once, so a replay can never
-- skip an owner it just tore down or start one twice.
local seenStartOwners: { [string]: boolean } = {}
for _, ownerId in MatchResultConfig.ReplayStartOrder do
	assert(CleanupOwnerIds[ownerId] == ownerId, "replay start order contains an unknown owner: " .. tostring(ownerId))
	assert(not seenStartOwners[ownerId], "replay start order lists an owner twice: " .. tostring(ownerId))
	seenStartOwners[ownerId] = true
end
assert(#MatchResultConfig.ReplayStartOrder == declaredOwnerCount, "the start order must cover every cleanup owner")

return table.freeze(MatchResultConfig)
