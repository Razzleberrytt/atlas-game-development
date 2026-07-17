--!strict

--[[
	P5-0104 shared enemy vocabulary. Declarations only: stable IDs and data
	shapes for the production enemy lifecycle. The server owns every enemy
	fact — identity, spawning, position, behavior, health, attacks, and death.
	Clients never mint, steer, damage, or reveal an enemy through these types;
	enemy bodies replicate as ordinary server-owned Workspace instances.
]]

local EnemyContracts = {}

export type EnemyArchetypeId = "enemy.exclusion_walker"

export type EnemyBehaviorStateId = "Roaming" | "Pursuing" | "WindingUp" | "Attacking" | "StandDown" | "Dead"

export type EnemyAttackWindupActionId = "None" | "Begin" | "Continue" | "Cancel" | "Commit"

export type EnemySpawnSourceId = "AuthoredWave" | "RoamingPressure"

export type EnemySpawnRejectionReasonId =
	"InvalidDefinition"
	| "DuplicateEntityId"
	| "PopulationCapReached"
	| "OutsidePlayableExtent"
	| "TooCloseToOperative"

export type EnemyBehaviorRejectionReasonId = "InvalidFacts" | "InvalidTimestamp"

export type EnemyWorldPosition = {
	x: number,
	y: number,
	z: number,
}

export type EnemySpawnRequest = {
	entityId: string,
	archetypeId: EnemyArchetypeId,
	spawnSourceId: EnemySpawnSourceId,
	displayName: string,
	position: EnemyWorldPosition,
}

-- Caller-supplied server-owned facts for one fair-spawn decision. Remote
-- payloads and client-authored values are never valid sources.
export type EnemySpawnFacts = {
	existingEnemyEntityIds: { [string]: boolean },
	activeEnemyCount: number,
	populationCap: number,
	playableHalfExtentStuds: number,
	alivePositions: { EnemyWorldPosition },
}

export type EnemySpawnResolution = {
	isLegal: boolean,
	rejectionReasonId: EnemySpawnRejectionReasonId?,
}

-- Server-owned facts about one alive-or-not operative used for behavior
-- decisions. `operativeEntityId` is the P3 life identity, which is also the
-- P2 combat entity identity.
export type EnemyOperativeFact = {
	operativeEntityId: string,
	isAlive: boolean,
	position: EnemyWorldPosition,
}

export type EnemyBehaviorFacts = {
	entityId: string,
	behaviorStateId: EnemyBehaviorStateId,
	position: EnemyWorldPosition,
	targetOperativeEntityId: string?,
	lastAttackServerTimestamp: number?,
	attackWindupTargetOperativeEntityId: string?,
	attackWindupStartedServerTimestamp: number?,
}

-- One authoritative melee swing derived entirely from server-owned facts.
-- Shape-compatible with the P3 AuthoritativeOperativeDamage commit boundary.
export type AuthoritativeEnemyAttack = {
	damageEventId: string,
	sourceEntityId: string,
	targetEntityId: string,
	damageAmount: number,
	serverTimestamp: number,
}

export type EnemyBehaviorDecision = {
	behaviorStateIdAfter: EnemyBehaviorStateId,
	targetOperativeEntityId: string?,
	attackWindupActionId: EnemyAttackWindupActionId,
	shouldAttack: boolean,
	attack: AuthoritativeEnemyAttack?,
	rejectionReasonId: EnemyBehaviorRejectionReasonId?,
}

EnemyContracts.EnemyArchetypeIds = table.freeze({
	ExclusionWalker = "enemy.exclusion_walker" :: EnemyArchetypeId,
})

EnemyContracts.EnemyBehaviorStateIds = table.freeze({
	Roaming = "Roaming" :: EnemyBehaviorStateId,
	Pursuing = "Pursuing" :: EnemyBehaviorStateId,
	WindingUp = "WindingUp" :: EnemyBehaviorStateId,
	Attacking = "Attacking" :: EnemyBehaviorStateId,
	StandDown = "StandDown" :: EnemyBehaviorStateId,
	Dead = "Dead" :: EnemyBehaviorStateId,
})

EnemyContracts.EnemyAttackWindupActionIds = table.freeze({
	None = "None" :: EnemyAttackWindupActionId,
	Begin = "Begin" :: EnemyAttackWindupActionId,
	Continue = "Continue" :: EnemyAttackWindupActionId,
	Cancel = "Cancel" :: EnemyAttackWindupActionId,
	Commit = "Commit" :: EnemyAttackWindupActionId,
})

EnemyContracts.EnemySpawnSourceIds = table.freeze({
	AuthoredWave = "AuthoredWave" :: EnemySpawnSourceId,
	RoamingPressure = "RoamingPressure" :: EnemySpawnSourceId,
})

EnemyContracts.EnemySpawnRejectionReasonIds = table.freeze({
	InvalidDefinition = "InvalidDefinition" :: EnemySpawnRejectionReasonId,
	DuplicateEntityId = "DuplicateEntityId" :: EnemySpawnRejectionReasonId,
	PopulationCapReached = "PopulationCapReached" :: EnemySpawnRejectionReasonId,
	OutsidePlayableExtent = "OutsidePlayableExtent" :: EnemySpawnRejectionReasonId,
	TooCloseToOperative = "TooCloseToOperative" :: EnemySpawnRejectionReasonId,
})

EnemyContracts.EnemyBehaviorRejectionReasonIds = table.freeze({
	InvalidFacts = "InvalidFacts" :: EnemyBehaviorRejectionReasonId,
	InvalidTimestamp = "InvalidTimestamp" :: EnemyBehaviorRejectionReasonId,
})

return table.freeze(EnemyContracts)
