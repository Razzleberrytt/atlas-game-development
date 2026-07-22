--!strict

-- P10-0101 terminal match-loop contracts and configuration: the result cause,
-- extraction-readiness, replay, and cleanup-owner vocabulary; the fixed cause →
-- outcome pairing; the safe result and contribution snapshot validators; and the
-- extraction-window and cleanup-order config invariants.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P10-0101 match-result contracts fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local missionContracts =
	loadSimple("games/living-kingdoms/src/shared/Mission/MissionContracts.luau", "MissionContracts")
local lifeContracts =
	loadSimple("games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau", "OperativeLifeContracts")

local MISSION_TOKEN = {}
local LIFE_TOKEN = {}
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Mission/MatchResultContracts.luau"), {
	debugName = "MatchResultContracts",
	environment = {
		script = {
			Parent = {
				MissionContracts = MISSION_TOKEN,
				Parent = { Health = { OperativeLifeContracts = LIFE_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == MISSION_TOKEN then
				return missionContracts
			end
			if token == LIFE_TOKEN then
				return lifeContracts
			end
			error("unexpected MatchResultContracts dependency")
		end,
	},
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MatchResultConfig.luau"), {
	debugName = "MatchResultConfig",
	environment = {
		script = { Parent = { Parent = { Mission = { MatchResultContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == CONTRACTS_TOKEN, "unexpected MatchResultConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

-- Stable vocabulary.
for _, cause in { "Extracted", "SquadWipe", "Abandoned" } do
	assert(contracts.MissionResultCauseIds[cause] == cause, "missing cause: " .. cause)
end
for _, state in { "Locked", "Inbound", "Arrived" } do
	assert(contracts.ExtractionReadinessStateIds[state] == state, "missing readiness state: " .. state)
end
for _, state in { "InProgress", "Resolved", "Replayable" } do
	assert(contracts.OperationReplayStateIds[state] == state, "missing replay state: " .. state)
end
for _, owner in
	{
		"EnemyDirector",
		"Objectives",
		"AmmunitionCaches",
		"Classes",
		"ReviveSessions",
		"OperativeLife",
		"SquadFailure",
		"ContributionRecord",
		"MissionDirector",
	}
do
	assert(contracts.CleanupOwnerIds[owner] == owner, "missing cleanup owner: " .. owner)
end
assert(table.isfrozen(contracts) and table.isfrozen(contracts.MissionResultCauseIds))
assert(table.isfrozen(contracts.CleanupOwnerIds) and table.isfrozen(contracts.OutcomeByCauseId))

-- The fixed cause → outcome pairing: Extracted wins, the rest fail.
assert(contracts.OutcomeByCauseId.Extracted == missionContracts.MissionOutcomeIds.Success)
assert(contracts.OutcomeByCauseId.SquadWipe == missionContracts.MissionOutcomeIds.Failure)
assert(contracts.OutcomeByCauseId.Abandoned == missionContracts.MissionOutcomeIds.Failure)

-- Contribution snapshot validation.
local function contribution(overrides: { [string]: any }?)
	local snapshot = {
		operativeEntityId = "operative.player:1",
		kills = 12,
		damageDealt = 840,
		revivesPerformed = 2,
		objectivesContributed = 3,
		classActionsCommitted = 5,
		bossExposureHits = 7,
		survivalStateId = "Alive",
	}
	for key, value in overrides or {} do
		snapshot[key] = value
	end
	return snapshot
end

assert(contracts.validateSafeContributionSnapshot(contribution()))
assert(contracts.validateSafeContributionSnapshot(contribution({ survivalStateId = "Dead" })))
assert(not contracts.validateSafeContributionSnapshot(nil))
assert(not contracts.validateSafeContributionSnapshot(contribution({ operativeEntityId = "" })))
assert(not contracts.validateSafeContributionSnapshot(contribution({ kills = -1 })), "counts must be non-negative")
assert(not contracts.validateSafeContributionSnapshot(contribution({ damageDealt = 0 / 0 })))
assert(
	not contracts.validateSafeContributionSnapshot(contribution({ survivalStateId = "Ghost" })),
	"survival state must reuse the P3 life vocabulary"
)

-- Match-result snapshot validation.
local function result(overrides: { [string]: any }?)
	local snapshot = {
		operationId = "operation.blackwater-relay:run-7",
		outcomeId = "Success",
		causeId = "Extracted",
		durationSeconds = 615,
		phaseReachedId = "Resolved",
		objectivesCompleted = 3,
		bossDefeated = true,
		wavesSurvived = 3,
		contributions = { contribution() },
	}
	for key, value in overrides or {} do
		snapshot[key] = value
	end
	return snapshot
end

assert(contracts.validateSafeMatchResultSnapshot(result()))
assert(contracts.validateSafeMatchResultSnapshot(result({
	outcomeId = "Failure",
	causeId = "SquadWipe",
	bossDefeated = false,
})))
assert(not contracts.validateSafeMatchResultSnapshot(nil))
assert(not contracts.validateSafeMatchResultSnapshot(result({ operationId = "" })))
assert(not contracts.validateSafeMatchResultSnapshot(result({ causeId = "Vanished" })), "unknown cause rejected")
assert(
	not contracts.validateSafeMatchResultSnapshot(result({ outcomeId = "Failure", causeId = "Extracted" })),
	"the outcome must match the fixed cause pairing"
)
assert(not contracts.validateSafeMatchResultSnapshot(result({ phaseReachedId = "Nowhere" })))
assert(not contracts.validateSafeMatchResultSnapshot(result({ durationSeconds = -1 })))
assert(not contracts.validateSafeMatchResultSnapshot(result({ bossDefeated = "yes" })))
assert(not contracts.validateSafeMatchResultSnapshot(result({ contributions = "nope" })))
assert(
	not contracts.validateSafeMatchResultSnapshot(result({ contributions = { contribution({ kills = -1 }) } })),
	"every contribution entry is validated"
)

-- Config invariants.
assert(config.ExtractionArrivalWindowSeconds > 0 and config.ExtractionArrivalWindowSeconds < math.huge)
assert(table.isfrozen(config) and table.isfrozen(config.CleanupStopOrder))
local seen = {}
local ownerCount = 0
for _ in contracts.CleanupOwnerIds do
	ownerCount += 1
end
assert(#config.CleanupStopOrder == ownerCount, "the stop order must cover every cleanup owner exactly once")
for _, ownerId in config.CleanupStopOrder do
	assert(
		contracts.CleanupOwnerIds[ownerId] == ownerId and not seen[ownerId],
		"stop order owners must be unique/known"
	)
	seen[ownerId] = true
end
-- Enemies stand down first; the mission director tears itself down last.
assert(config.CleanupStopOrder[1] == contracts.CleanupOwnerIds.EnemyDirector)
assert(config.CleanupStopOrder[#config.CleanupStopOrder] == contracts.CleanupOwnerIds.MissionDirector)

print(
	"MatchResultContracts: P10-0101 cause/readiness/replay/cleanup vocabulary, cause→outcome pairing, validators, and config bounds passed"
)
