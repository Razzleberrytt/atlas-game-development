--!strict

--[[
	Wave 2 shared enemy vocabulary. Stable IDs and server-owned data shapes for
	enemy spawning, behavior, encounter attribution, and reward hooks.

	ServerRuntimeMetadataByEntityId is intentionally a mutable nested table inside
	the otherwise frozen vocabulary. Module state is VM-local: the server uses it
	to bridge encounter-authored metadata into legacy Wave 1 resolvers, while each
	client receives its own empty copy and therefore gains no authority or server
	state disclosure.
]]

local EnemyContracts = {}

export type EnemyArchetypeId =
	"enemy.exclusion_walker"
	| "enemy.razor_runner"
	| "enemy.grief_brute"
	| "enemy.blight_spitter"
	| "boss.progenitor"
export type EnemyBehaviorStateId = "Roaming" | "Pursuing" | "WindingUp" | "Attacking" | "StandDown" | "Dead"
export type EnemyAttackWindupActionId = "None" | "Begin" | "Continue" | "Cancel" | "Commit"
export type EnemySpawnSourceId = "AuthoredWave" | "RoamingPressure"
export type EnemyMovementBehaviorId = "DirectPursuit" | "Skirmish" | "HeavyPressure" | "RangedApproach" | "StationaryBoss"
export type EnemyAttackBehaviorId = "Melee" | "CorrosiveBloom" | "BossSlam"

export type EnemySpawnRejectionReasonId =
	"InvalidDefinition"
	| "DuplicateEntityId"
	| "PopulationCapReached"
	| "OutsidePlayableExtent"
	| "TooCloseToOperative"
export type EnemyBehaviorRejectionReasonId = "InvalidFacts" | "InvalidTimestamp"

export type EnemyWorldPosition = { x: number, y: number, z: number }

export type EnemySpawnRequest = {
	entityId: string,
	archetypeId: EnemyArchetypeId,
	spawnSourceId: EnemySpawnSourceId,
	displayName: string,
	position: EnemyWorldPosition,
	isHordePulse: boolean?,
	hordeRoleId: string?,
	encounterId: string?,
	compositionIdentity: string?,
	eliteChance: number?,
	requestedEliteAffixId: string?,
}

export type EnemySpawnFacts = {
	existingEnemyEntityIds: { [string]: boolean },
	activeEnemyCount: number,
	populationCap: number,
	playableHalfExtentStuds: number,
	alivePositions: { EnemyWorldPosition },
}

export type EnemySpawnResolution = { isLegal: boolean, rejectionReasonId: EnemySpawnRejectionReasonId? }

export type EnemyOperativeFact = {
	operativeEntityId: string,
	isAlive: boolean,
	position: EnemyWorldPosition,
}

export type EnemyBehaviorFacts = {
	entityId: string,
	archetypeId: EnemyArchetypeId?,
	behaviorStateId: EnemyBehaviorStateId,
	position: EnemyWorldPosition,
	targetOperativeEntityId: string?,
	lastAttackServerTimestamp: number?,
	attackWindupTargetOperativeEntityId: string?,
	attackWindupStartedServerTimestamp: number?,
	attackCadenceMultiplier: number?,
}

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

export type ServerRuntimeEnemyMetadata = {
	archetypeId: EnemyArchetypeId,
	encounterId: string?,
	compositionIdentity: string?,
	eliteChance: number?,
	requestedEliteAffixId: string?,
	hordeRoleId: string?,
	eliteEligible: boolean?,
	lastDamagingOperativeEntityId: string?,
	deathHandled: boolean?,
}

EnemyContracts.EnemyArchetypeIds = table.freeze({
	ExclusionWalker = "enemy.exclusion_walker" :: EnemyArchetypeId,
	RazorRunner = "enemy.razor_runner" :: EnemyArchetypeId,
	GriefBrute = "enemy.grief_brute" :: EnemyArchetypeId,
	BlightSpitter = "enemy.blight_spitter" :: EnemyArchetypeId,
	Progenitor = "boss.progenitor" :: EnemyArchetypeId,
})

EnemyContracts.EnemyMovementBehaviorIds = table.freeze({
	DirectPursuit = "DirectPursuit" :: EnemyMovementBehaviorId,
	Skirmish = "Skirmish" :: EnemyMovementBehaviorId,
	HeavyPressure = "HeavyPressure" :: EnemyMovementBehaviorId,
	RangedApproach = "RangedApproach" :: EnemyMovementBehaviorId,
	StationaryBoss = "StationaryBoss" :: EnemyMovementBehaviorId,
})

EnemyContracts.EnemyAttackBehaviorIds = table.freeze({
	Melee = "Melee" :: EnemyAttackBehaviorId,
	CorrosiveBloom = "CorrosiveBloom" :: EnemyAttackBehaviorId,
	BossSlam = "BossSlam" :: EnemyAttackBehaviorId,
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

EnemyContracts.ServerRuntimeMetadataByEntityId = {} :: { [string]: ServerRuntimeEnemyMetadata }

return table.freeze(EnemyContracts)
