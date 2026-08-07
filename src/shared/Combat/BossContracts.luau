--!strict

--[[
	P9-0103 shared boss vocabulary for The Progenitor, the authored extraction-
	holdout climax. Declarations only: stable IDs and data shapes for the boss's
	phases, vulnerability windows, the Slam attack, the Brood summon, the spore
	shroud, and the terminal outcome. The server owns every fact — phase, health,
	timing, damage, summons, and defeat. Clients never drive a phase, legalise a
	hit, or declare the outcome; the boss body replicates as an ordinary
	server-owned Workspace instance and its telegraphs ride replicated attributes.

	The boss reuses the production enemy owner (EnemyContracts / EnemyDirectorService,
	P9-0104) for identity, health, damage, and cleanup. These declarations add only
	the phase machine and its authored actions. Deterministic, monotonic phase
	transitions come from the pure BossPhaseResolver.
]]

local EnemyContracts = require(script.Parent.EnemyContracts)

local BossContracts = {}

export type EnemyWorldPosition = EnemyContracts.EnemyWorldPosition
export type EnemyOperativeFact = EnemyContracts.EnemyOperativeFact
export type AuthoritativeEnemyAttack = EnemyContracts.AuthoritativeEnemyAttack

export type BossArchetypeId = "boss.progenitor"

-- Monotonic phases. Carapace: armored, only vulnerable in post-Slam exposure
-- windows. Brood: summons a bounded add surge under a visibility-shrinking spore
-- shroud. Collapse: enrage, whose readability pays off the P8 floodlight repair.
-- Defeated: terminal.
export type BossPhaseId = "Carapace" | "Brood" | "Collapse" | "Defeated"

-- The Slam attack lifecycle, mirroring the enemy windup vocabulary.
export type BossActionId = "None" | "Begin" | "Continue" | "Cancel" | "Commit"

export type BossOutcomeId = "Pending" | "Defeated"

export type BossDecisionRejectionReasonId = "InvalidFacts" | "InvalidTimestamp"

-- Server-owned facts for one boss phase decision. `slamTargetPosition` and
-- `slamWindupStartedServerTimestamp` are the locked Slam centre and start time,
-- both present exactly while a Slam is winding up. `broodSummonedForPhase` is the
-- runtime's record that the Brood surge already fired this phase.
export type BossPhaseFacts = {
	entityId: string,
	phaseId: BossPhaseId,
	position: EnemyWorldPosition,
	currentHealth: number,
	maximumHealth: number,
	lastSlamCommitServerTimestamp: number?,
	slamWindupStartedServerTimestamp: number?,
	slamTargetPosition: EnemyWorldPosition?,
	broodSummonedForPhase: boolean,
	floodlightsRestored: boolean,
}

export type BossPhaseDecision = {
	phaseIdAfter: BossPhaseId,
	-- The boss only takes damage while true (an open post-Slam exposure window).
	isVulnerable: boolean,
	slamActionId: BossActionId,
	slamTargetPosition: EnemyWorldPosition?,
	-- One authoritative damage event per Alive operative inside the Slam radius at
	-- commit; shape-compatible with the P3 damage boundary. Empty otherwise.
	slamImpacts: { AuthoritativeEnemyAttack },
	-- The Brood surge: true exactly once on entering Brood.
	shouldSummonBrood: boolean,
	broodSurgeCount: number,
	-- The spore shroud / Collapse darkness reduces the operative gameplay-visibility
	-- radius; nil means no override (normal visibility).
	shroudActive: boolean,
	visibilityOverrideRadiusStuds: number?,
	outcomeId: BossOutcomeId,
	rejectionReasonId: BossDecisionRejectionReasonId?,
}

-- Sourced from the shared registry so there is one archetype-ID source of truth.
BossContracts.BossArchetypeIds = table.freeze({
	Progenitor = EnemyContracts.EnemyArchetypeIds.Progenitor :: BossArchetypeId,
})

BossContracts.BossPhaseIds = table.freeze({
	Carapace = "Carapace" :: BossPhaseId,
	Brood = "Brood" :: BossPhaseId,
	Collapse = "Collapse" :: BossPhaseId,
	Defeated = "Defeated" :: BossPhaseId,
})

-- Fixed monotonic order; the resolver never regresses a boss to a lower value.
BossContracts.BossPhaseOrder = table.freeze({
	Carapace = 1,
	Brood = 2,
	Collapse = 3,
	Defeated = 4,
})

BossContracts.BossActionIds = table.freeze({
	None = "None" :: BossActionId,
	Begin = "Begin" :: BossActionId,
	Continue = "Continue" :: BossActionId,
	Cancel = "Cancel" :: BossActionId,
	Commit = "Commit" :: BossActionId,
})

BossContracts.BossOutcomeIds = table.freeze({
	Pending = "Pending" :: BossOutcomeId,
	Defeated = "Defeated" :: BossOutcomeId,
})

BossContracts.BossDecisionRejectionReasonIds = table.freeze({
	InvalidFacts = "InvalidFacts" :: BossDecisionRejectionReasonId,
	InvalidTimestamp = "InvalidTimestamp" :: BossDecisionRejectionReasonId,
})

return table.freeze(BossContracts)
