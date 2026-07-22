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
	Version = "P10-0101-v1",
	-- After the boss is defeated, extraction is inbound for this window before the
	-- squad extracts. Long enough to be a readable payoff, short enough that a
	-- wiped squad still loses.
	ExtractionArrivalWindowSeconds = 15,
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
}

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

return table.freeze(MatchResultConfig)
