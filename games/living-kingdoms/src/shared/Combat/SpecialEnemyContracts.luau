--!strict

--[[
	P9-0101 shared special-enemy vocabulary. Declarations only: stable IDs and
	data shapes for the Blight Spitter, the milestone's first special enemy. The
	server owns every fact — identity, spawning, position, behavior, the Corrosive
	Bloom ability, and death. Clients never mint, steer, charge, or reveal a
	special enemy through these types; bodies replicate as ordinary server-owned
	Workspace instances and the bloom telegraph rides replicated model attributes.

	The Blight Spitter reuses the production enemy owner (EnemyContracts /
	EnemyConfig / EnemyDirectorService). Spawn legality, world position, health,
	corpse cleanup, and stand-down are the existing enemy paths (P9-0102); these
	declarations add only the ranged area-denial ability that distinguishes the
	archetype. It is not an HROI horde role and not an RPG elite affix.
]]

local EnemyContracts = require(script.Parent.EnemyContracts)

local SpecialEnemyContracts = {}

export type EnemyWorldPosition = EnemyContracts.EnemyWorldPosition
export type EnemyOperativeFact = EnemyContracts.EnemyOperativeFact
export type AuthoritativeEnemyAttack = EnemyContracts.AuthoritativeEnemyAttack

export type SpecialEnemyArchetypeId = "enemy.blight_spitter"

-- Roaming: no operative in detection. Approaching: an anchor exists but the
-- densest cluster is beyond bloom range. Charging: the telegraphed windup with a
-- locked landing position. Recovering: in range but on ability cooldown.
export type SpecialEnemyBehaviorStateId = "Roaming" | "Approaching" | "Charging" | "Recovering" | "StandDown" | "Dead"

export type SpecialAbilityActionId = "None" | "Begin" | "Continue" | "Cancel" | "Commit"

export type SpecialEnemyBehaviorRejectionReasonId = "InvalidFacts" | "InvalidTimestamp"

-- Server-owned facts about one Blight Spitter for a single behavior decision.
-- `bloomChargeTargetPosition` and `bloomChargeStartedServerTimestamp` are the
-- landing position and start time locked when the charge began; both are present
-- exactly while the enemy is `Charging`.
export type SpecialEnemyBehaviorFacts = {
	entityId: string,
	behaviorStateId: SpecialEnemyBehaviorStateId,
	position: EnemyWorldPosition,
	anchorOperativeEntityId: string?,
	lastBloomCommitServerTimestamp: number?,
	bloomChargeTargetPosition: EnemyWorldPosition?,
	bloomChargeStartedServerTimestamp: number?,
}

-- A short-lived area-denial pool committed by one Corrosive Bloom. The runtime
-- (P9-0102) owns the pool and ticks it on the existing enemy evaluation pass;
-- `resolveLingeringDamage` derives each tick's authoritative damage.
export type LingeringBloomZone = {
	zoneId: string,
	sourceEntityId: string,
	centerPosition: EnemyWorldPosition,
	radiusStuds: number,
	tickDamage: number,
	tickIntervalSeconds: number,
	lifetimeSeconds: number,
	committedServerTimestamp: number,
	lastTickServerTimestamp: number?,
}

export type SpecialEnemyBehaviorDecision = {
	behaviorStateIdAfter: SpecialEnemyBehaviorStateId,
	anchorOperativeEntityId: string?,
	bloomActionId: SpecialAbilityActionId,
	bloomTargetPosition: EnemyWorldPosition?,
	shouldCommitBloom: boolean,
	-- One authoritative damage event per Alive operative inside the impact radius
	-- at commit; shape-compatible with the P3 damage boundary. Empty otherwise.
	bloomImpacts: { AuthoritativeEnemyAttack },
	lingeringZone: LingeringBloomZone?,
	rejectionReasonId: SpecialEnemyBehaviorRejectionReasonId?,
}

export type LingeringDamageResolution = {
	isActive: boolean,
	ticked: boolean,
	impacts: { AuthoritativeEnemyAttack },
	tickServerTimestamp: number?,
	rejectionReasonId: SpecialEnemyBehaviorRejectionReasonId?,
}

SpecialEnemyContracts.SpecialEnemyArchetypeIds = table.freeze({
	BlightSpitter = "enemy.blight_spitter" :: SpecialEnemyArchetypeId,
})

SpecialEnemyContracts.SpecialEnemyBehaviorStateIds = table.freeze({
	Roaming = "Roaming" :: SpecialEnemyBehaviorStateId,
	Approaching = "Approaching" :: SpecialEnemyBehaviorStateId,
	Charging = "Charging" :: SpecialEnemyBehaviorStateId,
	Recovering = "Recovering" :: SpecialEnemyBehaviorStateId,
	StandDown = "StandDown" :: SpecialEnemyBehaviorStateId,
	Dead = "Dead" :: SpecialEnemyBehaviorStateId,
})

SpecialEnemyContracts.SpecialAbilityActionIds = table.freeze({
	None = "None" :: SpecialAbilityActionId,
	Begin = "Begin" :: SpecialAbilityActionId,
	Continue = "Continue" :: SpecialAbilityActionId,
	Cancel = "Cancel" :: SpecialAbilityActionId,
	Commit = "Commit" :: SpecialAbilityActionId,
})

SpecialEnemyContracts.SpecialEnemyBehaviorRejectionReasonIds = table.freeze({
	InvalidFacts = "InvalidFacts" :: SpecialEnemyBehaviorRejectionReasonId,
	InvalidTimestamp = "InvalidTimestamp" :: SpecialEnemyBehaviorRejectionReasonId,
})

return table.freeze(SpecialEnemyContracts)
