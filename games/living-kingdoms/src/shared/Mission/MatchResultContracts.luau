--!strict

--[[
	P10-0101 shared vocabulary for the terminal match loop: the result cause, the
	extraction-readiness and replay lifecycle states, the cleanup-owner order, and
	the safe result and per-operative contribution snapshots the server discloses.

	The server owns every terminal fact. Clients receive only the validated safe
	snapshots here and may never establish the outcome, cause, contribution, or
	timing. No persistent XP, rank, or unlock is represented — result and
	contribution facts are recorded and disclosed for P11 to weight, nothing more.

	Reuses the existing `MissionContracts` outcome/phase vocabulary and the P3
	`OperativeLifeContracts` life state; this module adds only the terminal-result
	layer over the single first-commit-wins boundary.
]]

local MissionContracts = require(script.Parent.MissionContracts)
local OperativeLifeContracts = require(script.Parent.Parent.Health.OperativeLifeContracts)

export type MissionOutcomeId = MissionContracts.MissionOutcomeId
export type MissionPhaseId = MissionContracts.MissionPhaseId
export type OperativeLifeStateId = OperativeLifeContracts.OperativeLifeStateId

-- Extracted (Success): the boss is defeated and the squad completes extraction.
-- SquadWipe / Abandoned (Failure): the only failure origins, unchanged from today.
export type MissionResultCauseId = "Extracted" | "SquadWipe" | "Abandoned"

-- The extraction sequence readiness. Locked until the boss falls; Inbound during
-- the arrival window; Arrived once extraction is available.
export type ExtractionReadinessStateId = "Locked" | "Inbound" | "Arrived"

-- The operation lifecycle for replay. Replay is only offered after Resolved.
export type OperationReplayStateId = "InProgress" | "Resolved" | "Replayable"

-- Why the pure terminal-result resolver declined to commit a new result.
export type TerminalDecisionRejectionReasonId = "InvalidFacts" | "InvalidTimestamp" | "AlreadyResolved" | "NotTerminal"

-- One first-commit-wins terminal decision. `shouldCommit` is true only when the
-- operation resolves this pass; otherwise a rejection reason explains why not.
export type TerminalDecision = {
	shouldCommit: boolean,
	causeId: MissionResultCauseId?,
	outcomeId: MissionOutcomeId?,
	rejectionReasonId: TerminalDecisionRejectionReasonId?,
}

-- Every runtime owner that participates in the documented terminal stop order.
export type CleanupOwnerId =
	"EnemyDirector"
	| "Objectives"
	| "AmmunitionCaches"
	| "Classes"
	| "ReviveSessions"
	| "OperativeLife"
	| "SquadFailure"
	| "ContributionRecord"
	| "MissionDirector"

-- One operative's server-recorded contribution, disclosed for P11 to weight into
-- XP. Every field is a bounded, server-authored count or a life state — never a
-- client-reported value and never a reward.
-- RPG-0112: one squad Field Upgrade and its stack count, as an array so the
-- summary is deterministic to read and to render.
export type SafeUpgradeStackSnapshot = {
	upgradeId: string,
	stacks: number,
}

export type SafeContributionSnapshot = {
	operativeEntityId: string,
	kills: number,
	damageDealt: number,
	revivesPerformed: number,
	objectivesContributed: number,
	classActionsCommitted: number,
	bossExposureHits: number,
	survivalStateId: OperativeLifeStateId,
	-- RPG-0112: the relics this operative finished the run holding.
	equippedRelicIds: { string },
}

export type SafeMatchResultSnapshot = {
	operationId: string,
	outcomeId: MissionOutcomeId,
	causeId: MissionResultCauseId,
	durationSeconds: number,
	phaseReachedId: MissionPhaseId,
	objectivesCompleted: number,
	bossDefeated: boolean,
	wavesSurvived: number,
	contributions: { SafeContributionSnapshot },
	-- RPG-0112: the squad Field Upgrades the run finished with.
	upgradeStacks: { SafeUpgradeStackSnapshot },
}

local MatchResultContracts = {}

MatchResultContracts.MissionResultCauseIds = table.freeze({
	Extracted = "Extracted" :: MissionResultCauseId,
	SquadWipe = "SquadWipe" :: MissionResultCauseId,
	Abandoned = "Abandoned" :: MissionResultCauseId,
})

-- The fixed cause → outcome pairing. The terminal resolver and the validator both
-- read this; a snapshot whose outcome contradicts its cause is invalid.
MatchResultContracts.OutcomeByCauseId = table.freeze({
	Extracted = MissionContracts.MissionOutcomeIds.Success,
	SquadWipe = MissionContracts.MissionOutcomeIds.Failure,
	Abandoned = MissionContracts.MissionOutcomeIds.Failure,
})

MatchResultContracts.ExtractionReadinessStateIds = table.freeze({
	Locked = "Locked" :: ExtractionReadinessStateId,
	Inbound = "Inbound" :: ExtractionReadinessStateId,
	Arrived = "Arrived" :: ExtractionReadinessStateId,
})

MatchResultContracts.OperationReplayStateIds = table.freeze({
	InProgress = "InProgress" :: OperationReplayStateId,
	Resolved = "Resolved" :: OperationReplayStateId,
	Replayable = "Replayable" :: OperationReplayStateId,
})

MatchResultContracts.TerminalDecisionRejectionReasonIds = table.freeze({
	InvalidFacts = "InvalidFacts" :: TerminalDecisionRejectionReasonId,
	InvalidTimestamp = "InvalidTimestamp" :: TerminalDecisionRejectionReasonId,
	AlreadyResolved = "AlreadyResolved" :: TerminalDecisionRejectionReasonId,
	NotTerminal = "NotTerminal" :: TerminalDecisionRejectionReasonId,
})

MatchResultContracts.CleanupOwnerIds = table.freeze({
	EnemyDirector = "EnemyDirector" :: CleanupOwnerId,
	Objectives = "Objectives" :: CleanupOwnerId,
	AmmunitionCaches = "AmmunitionCaches" :: CleanupOwnerId,
	Classes = "Classes" :: CleanupOwnerId,
	ReviveSessions = "ReviveSessions" :: CleanupOwnerId,
	OperativeLife = "OperativeLife" :: CleanupOwnerId,
	SquadFailure = "SquadFailure" :: CleanupOwnerId,
	ContributionRecord = "ContributionRecord" :: CleanupOwnerId,
	MissionDirector = "MissionDirector" :: CleanupOwnerId,
})

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeFiniteNumber(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

function MatchResultContracts.validateSafeContributionSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local contribution = value :: { [string]: unknown }
	if not isNonEmptyString(contribution.operativeEntityId) then
		return false
	end
	for _, countField in
		{
			"kills",
			"damageDealt",
			"revivesPerformed",
			"objectivesContributed",
			"classActionsCommitted",
			"bossExposureHits",
		}
	do
		if not isNonNegativeFiniteNumber(contribution[countField]) then
			return false
		end
	end
	if
		not isNonEmptyString(contribution.survivalStateId)
		or OperativeLifeContracts.OperativeLifeStateIds[contribution.survivalStateId :: string] == nil
	then
		return false
	end
	-- The relic list is authored server state: strings only, and bounded by the
	-- three equipped slots an operative can ever hold.
	if type(contribution.equippedRelicIds) ~= "table" then
		return false
	end
	local relicIds = contribution.equippedRelicIds :: { unknown }
	if #relicIds > 3 then
		return false
	end
	for _, relicId in relicIds do
		if not isNonEmptyString(relicId) then
			return false
		end
	end
	return true
end

function MatchResultContracts.validateSafeMatchResultSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: { [string]: unknown }
	if not isNonEmptyString(snapshot.operationId) then
		return false
	end
	if
		not isNonEmptyString(snapshot.causeId)
		or MatchResultContracts.MissionResultCauseIds[snapshot.causeId :: string] == nil
	then
		return false
	end
	-- The outcome must match the fixed cause → outcome pairing.
	if
		not isNonEmptyString(snapshot.outcomeId)
		or MatchResultContracts.OutcomeByCauseId[snapshot.causeId :: string] ~= snapshot.outcomeId
	then
		return false
	end
	if
		not isNonEmptyString(snapshot.phaseReachedId)
		or MissionContracts.MissionPhaseIds[snapshot.phaseReachedId :: string] == nil
	then
		return false
	end
	for _, countField in { "durationSeconds", "objectivesCompleted", "wavesSurvived" } do
		if not isNonNegativeFiniteNumber(snapshot[countField]) then
			return false
		end
	end
	if type(snapshot.bossDefeated) ~= "boolean" then
		return false
	end
	if type(snapshot.contributions) ~= "table" then
		return false
	end
	for _, contribution in snapshot.contributions :: { unknown } do
		if not MatchResultContracts.validateSafeContributionSnapshot(contribution) then
			return false
		end
	end
	if type(snapshot.upgradeStacks) ~= "table" then
		return false
	end
	local seenUpgradeIds: { [string]: boolean } = {}
	for _, entry in snapshot.upgradeStacks :: { unknown } do
		if type(entry) ~= "table" then
			return false
		end
		local upgrade = entry :: { [string]: unknown }
		if not isNonEmptyString(upgrade.upgradeId) or seenUpgradeIds[upgrade.upgradeId :: string] then
			return false
		end
		seenUpgradeIds[upgrade.upgradeId :: string] = true
		if not isNonNegativeFiniteNumber(upgrade.stacks) or (upgrade.stacks :: number) <= 0 then
			return false
		end
	end
	return true
end

return table.freeze(MatchResultContracts)
