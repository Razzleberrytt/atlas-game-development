from pathlib import Path


def write(path: str, content: str) -> None:
    Path(path).write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    content = file_path.read_text(encoding="utf-8")
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"expected exactly one replacement in {path}, found {count}: {old[:100]!r}")
    file_path.write_text(content.replace(old, new, 1), encoding="utf-8")


write(
    "games/living-kingdoms/src/shared/Combat/EnemyContracts.luau",
    r'''--!strict

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
''',
)

write(
    "games/living-kingdoms/src/server/Systems/EnemyBehaviorResolver.luau",
    r'''--!strict

--[[
	P5-0104 pure enemy decision logic. Deterministic, side-effect free, and
	loop free: the caller supplies server-owned facts and a monotonic server
	timestamp, and receives a spawn-legality or behavior decision without any
	input mutation, Roblox service access, raycast, or randomness. The runtime
	director owns state commits, movement, windup disclosure, and damage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)

type EnemyBehaviorDecision = EnemyContracts.EnemyBehaviorDecision
type EnemyBehaviorFacts = EnemyContracts.EnemyBehaviorFacts
type EnemyOperativeFact = EnemyContracts.EnemyOperativeFact
type EnemySpawnFacts = EnemyContracts.EnemySpawnFacts
type EnemySpawnRequest = EnemyContracts.EnemySpawnRequest
type EnemySpawnResolution = EnemyContracts.EnemySpawnResolution

local BehaviorStateIds = EnemyContracts.EnemyBehaviorStateIds
local AttackWindupActionIds = EnemyContracts.EnemyAttackWindupActionIds
local SpawnRejectionReasonIds = EnemyContracts.EnemySpawnRejectionReasonIds
local BehaviorRejectionReasonIds = EnemyContracts.EnemyBehaviorRejectionReasonIds

local EnemyBehaviorResolver = {}

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteTimestamp(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0
end

local function isNonemptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isKnownValue(values: { [string]: string }, value: unknown): boolean
	for _, knownValue in values do
		if knownValue == value then
			return true
		end
	end
	return false
end

local function isWorldPosition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local position = value :: { [string]: unknown }
	return isFiniteNumber(position.x) and isFiniteNumber(position.y) and isFiniteNumber(position.z)
end

local function horizontalDistanceSquared(a: { x: number, z: number }, b: { x: number, z: number }): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return dx * dx + dz * dz
end

local function spawnResolution(rejectionReasonId: string?): EnemySpawnResolution
	return table.freeze({
		isLegal = rejectionReasonId == nil,
		rejectionReasonId = rejectionReasonId,
	}) :: EnemySpawnResolution
end

function EnemyBehaviorResolver.resolveSpawn(request: EnemySpawnRequest, facts: EnemySpawnFacts): EnemySpawnResolution
	if
		type(request) ~= "table"
		or not isNonemptyString(request.entityId)
		or not isKnownValue(EnemyContracts.EnemyArchetypeIds :: any, request.archetypeId)
		or not isKnownValue(EnemyContracts.EnemySpawnSourceIds :: any, request.spawnSourceId)
		or not isNonemptyString(request.displayName)
		or not isWorldPosition(request.position)
		or type(facts) ~= "table"
		or type(facts.existingEnemyEntityIds) ~= "table"
		or not isFiniteNumber(facts.activeEnemyCount)
		or not isFiniteNumber(facts.populationCap)
		or not isFiniteNumber(facts.playableHalfExtentStuds)
		or type(facts.alivePositions) ~= "table"
	then
		return spawnResolution(SpawnRejectionReasonIds.InvalidDefinition)
	end
	if facts.existingEnemyEntityIds[request.entityId] == true then
		return spawnResolution(SpawnRejectionReasonIds.DuplicateEntityId)
	end
	if facts.activeEnemyCount >= facts.populationCap then
		return spawnResolution(SpawnRejectionReasonIds.PopulationCapReached)
	end
	local position = request.position
	local halfExtent = facts.playableHalfExtentStuds
	if math.abs(position.x) > halfExtent or math.abs(position.z) > halfExtent then
		return spawnResolution(SpawnRejectionReasonIds.OutsidePlayableExtent)
	end
	local minimumDistance = EnemyConfig.FairSpawn.MinimumOperativeDistanceStuds
	local minimumDistanceSquared = minimumDistance * minimumDistance
	for _, alivePosition in facts.alivePositions do
		if horizontalDistanceSquared(position, alivePosition) < minimumDistanceSquared then
			return spawnResolution(SpawnRejectionReasonIds.TooCloseToOperative)
		end
	end
	return spawnResolution(nil)
end

local function decision(
	behaviorStateIdAfter: string,
	targetOperativeEntityId: string?,
	attackWindupActionId: string,
	shouldAttack: boolean,
	attack: EnemyContracts.AuthoritativeEnemyAttack?,
	rejectionReasonId: string?
): EnemyBehaviorDecision
	return table.freeze({
		behaviorStateIdAfter = behaviorStateIdAfter,
		targetOperativeEntityId = targetOperativeEntityId,
		attackWindupActionId = attackWindupActionId,
		shouldAttack = shouldAttack,
		attack = attack,
		rejectionReasonId = rejectionReasonId,
	}) :: EnemyBehaviorDecision
end

local function targetStateDecision(
	targetId: string?,
	targetDistanceSquared: number,
	attackRangeSquared: number,
	windupActionId: string
): EnemyBehaviorDecision
	if targetId == nil then
		return decision(BehaviorStateIds.Roaming, nil, windupActionId, false, nil, nil)
	end
	if targetDistanceSquared > attackRangeSquared then
		return decision(BehaviorStateIds.Pursuing, targetId, windupActionId, false, nil, nil)
	end
	return decision(BehaviorStateIds.Attacking, targetId, windupActionId, false, nil, nil)
end

function EnemyBehaviorResolver.resolveBehavior(
	enemy: EnemyBehaviorFacts,
	operatives: { EnemyOperativeFact },
	serverTimestamp: number
): EnemyBehaviorDecision
	if
		type(enemy) ~= "table"
		or not isNonemptyString(enemy.entityId)
		or not isKnownValue(BehaviorStateIds :: any, enemy.behaviorStateId)
		or not isWorldPosition(enemy.position)
		or type(operatives) ~= "table"
	then
		return decision(
			BehaviorStateIds.Roaming,
			nil,
			AttackWindupActionIds.None,
			false,
			nil,
			BehaviorRejectionReasonIds.InvalidFacts
		)
	end
	if not isFiniteTimestamp(serverTimestamp) then
		return decision(
			enemy.behaviorStateId,
			nil,
			AttackWindupActionIds.None,
			false,
			nil,
			BehaviorRejectionReasonIds.InvalidTimestamp
		)
	end

	local windupTargetId = enemy.attackWindupTargetOperativeEntityId
	local windupStartedAt = enemy.attackWindupStartedServerTimestamp
	local hasWindupTarget = windupTargetId ~= nil
	local hasWindupTimestamp = windupStartedAt ~= nil
	local hasWindup = hasWindupTarget and hasWindupTimestamp
	if
		hasWindupTarget ~= hasWindupTimestamp
		or (hasWindupTarget and not isNonemptyString(windupTargetId))
		or (hasWindupTimestamp and (not isFiniteTimestamp(windupStartedAt) or (windupStartedAt :: number) > serverTimestamp))
		or ((enemy.behaviorStateId == BehaviorStateIds.WindingUp) ~= hasWindup)
	then
		return decision(
			BehaviorStateIds.Roaming,
			nil,
			AttackWindupActionIds.None,
			false,
			nil,
			BehaviorRejectionReasonIds.InvalidFacts
		)
	end

	if enemy.behaviorStateId == BehaviorStateIds.Dead then
		return decision(
			BehaviorStateIds.Dead,
			nil,
			if hasWindup then AttackWindupActionIds.Cancel else AttackWindupActionIds.None,
			false,
			nil,
			nil
		)
	end
	if enemy.behaviorStateId == BehaviorStateIds.StandDown then
		return decision(
			BehaviorStateIds.StandDown,
			nil,
			if hasWindup then AttackWindupActionIds.Cancel else AttackWindupActionIds.None,
			false,
			nil,
			nil
		)
	end

	local walker = EnemyConfig.Walker
	local detectionSquared = walker.DetectionRadiusStuds * walker.DetectionRadiusStuds
	local dropSquared = walker.PursuitDropRadiusStuds * walker.PursuitDropRadiusStuds
	local attackRangeSquared = walker.AttackRangeStuds * walker.AttackRangeStuds

	local retainedTargetId: string? = nil
	local retainedDistanceSquared = math.huge
	local nearestTargetId: string? = nil
	local nearestDistanceSquared = math.huge
	local windupTargetIsAlive = false
	local windupTargetDistanceSquared = math.huge
	for _, operative in operatives do
		if
			type(operative) ~= "table"
			or not isNonemptyString(operative.operativeEntityId)
			or operative.isAlive ~= true
			or not isWorldPosition(operative.position)
		then
			continue
		end
		local distanceSquared = horizontalDistanceSquared(enemy.position, operative.position)
		if operative.operativeEntityId == windupTargetId then
			windupTargetIsAlive = true
			windupTargetDistanceSquared = distanceSquared
		end
		if operative.operativeEntityId == enemy.targetOperativeEntityId and distanceSquared <= dropSquared then
			retainedTargetId = operative.operativeEntityId
			retainedDistanceSquared = distanceSquared
		end
		if
			distanceSquared <= detectionSquared
			and (
				distanceSquared < nearestDistanceSquared
				or (
					distanceSquared == nearestDistanceSquared
					and (nearestTargetId == nil or operative.operativeEntityId < nearestTargetId)
				)
			)
		then
			nearestTargetId = operative.operativeEntityId
			nearestDistanceSquared = distanceSquared
		end
	end

	local targetId = retainedTargetId
	local targetDistanceSquared = retainedDistanceSquared
	if targetId == nil then
		targetId = nearestTargetId
		targetDistanceSquared = nearestDistanceSquared
	end

	if hasWindup then
		if windupTargetIsAlive and windupTargetDistanceSquared <= attackRangeSquared then
			local startedAt = windupStartedAt :: number
			local commitAt = startedAt + walker.AttackWindupSeconds
			if serverTimestamp < commitAt then
				return decision(
					BehaviorStateIds.WindingUp,
					windupTargetId,
					AttackWindupActionIds.Continue,
					false,
					nil,
					nil
				)
			end
			local attack: EnemyContracts.AuthoritativeEnemyAttack = table.freeze({
				damageEventId = "enemyattack:" .. enemy.entityId .. ":" .. (windupTargetId :: string) .. ":" .. startedAt,
				sourceEntityId = enemy.entityId,
				targetEntityId = windupTargetId :: string,
				damageAmount = walker.AttackDamage,
				serverTimestamp = serverTimestamp,
			})
			return decision(
				BehaviorStateIds.WindingUp,
				windupTargetId,
				AttackWindupActionIds.Commit,
				true,
				attack,
				nil
			)
		end
		return targetStateDecision(targetId, targetDistanceSquared, attackRangeSquared, AttackWindupActionIds.Cancel)
	end

	if targetId == nil then
		return decision(BehaviorStateIds.Roaming, nil, AttackWindupActionIds.None, false, nil, nil)
	end
	if targetDistanceSquared > attackRangeSquared then
		return decision(BehaviorStateIds.Pursuing, targetId, AttackWindupActionIds.None, false, nil, nil)
	end

	local lastAttack = enemy.lastAttackServerTimestamp
	local cooldownElapsed = lastAttack == nil or serverTimestamp >= lastAttack + walker.AttackCooldownSeconds
	if not cooldownElapsed then
		return decision(BehaviorStateIds.Attacking, targetId, AttackWindupActionIds.None, false, nil, nil)
	end
	return decision(BehaviorStateIds.WindingUp, targetId, AttackWindupActionIds.Begin, false, nil, nil)
end

return table.freeze(EnemyBehaviorResolver)
''',
)

replace_once(
    "games/living-kingdoms/src/shared/Config/EnemyConfig.luau",
    'Version = "P5-0104-v1",',
    'Version = "P5-0104-v2",',
)
replace_once(
    "games/living-kingdoms/src/shared/Config/EnemyConfig.luau",
    '\t\tAttackDamage = 12,\n\t\tAttackCooldownSeconds = 1.6,',
    '\t\tAttackDamage = 12,\n\t\tAttackWindupSeconds = 0.6,\n\t\tAttackCooldownSeconds = 1.6,',
)
replace_once(
    "games/living-kingdoms/src/shared/Config/EnemyConfig.luau",
    'assert(EnemyConfig.Walker.AttackDamage > 0, "attack damage must be positive")\nassert(EnemyConfig.Walker.AttackCooldownSeconds > 0, "attack cooldown must be positive")',
    'assert(EnemyConfig.Walker.AttackDamage > 0, "attack damage must be positive")\nassert(\n\tEnemyConfig.Walker.AttackWindupSeconds >= EnemyConfig.EvaluationIntervalSeconds\n\t\tand EnemyConfig.Walker.AttackWindupSeconds < EnemyConfig.Walker.AttackCooldownSeconds,\n\t"attack windup must be visible, bounded, and shorter than the cooldown"\n)\nassert(EnemyConfig.Walker.AttackCooldownSeconds > 0, "attack cooldown must be positive")',
)

write(
    "games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau",
    r'''--!strict

--[[
	Replicated, presentation-only disclosure names for server-owned enemies.
	These attributes describe authoritative state, windup intent, and committed
	events. They do not request attacks, select targets, apply damage, change
	health, or own death.
]]

local AttributeNames = table.freeze({
	BehaviorStateId = "EnemyPresentationBehaviorStateId",
	LifeStateId = "EnemyPresentationLifeStateId",
	WindupSequence = "EnemyPresentationWindupSequence",
	WindupStartedServerTimestamp = "EnemyPresentationWindupStartedServerTimestamp",
	WindupCommitServerTimestamp = "EnemyPresentationWindupCommitServerTimestamp",
	AttackSequence = "EnemyPresentationAttackSequence",
	AttackServerTimestamp = "EnemyPresentationAttackServerTimestamp",
	HitSequence = "EnemyPresentationHitSequence",
	HitServerTimestamp = "EnemyPresentationHitServerTimestamp",
})

local LifeStateIds = table.freeze({
	Alive = "Alive",
	Dead = "Dead",
})

return table.freeze({
	AttributeNames = AttributeNames,
	LifeStateIds = LifeStateIds,
})
''',
)

write(
    "games/living-kingdoms/src/client/Presentation/EnemyPresentationPoseResolver.luau",
    r'''--!strict

--[[
	VIS-0103 pure pose selection for the Exclusion Walker procedural fallback.
	Inputs are replicated presentation facts. The resolver cannot move an enemy,
	choose a target, apply damage, change health, or alter death and cleanup.
]]

local PoseIds = table.freeze({
	Idle = "Idle",
	RoamingA = "RoamingA",
	RoamingB = "RoamingB",
	PursuingA = "PursuingA",
	PursuingB = "PursuingB",
	ThreatReady = "ThreatReady",
	WindupEarlyLeft = "WindupEarlyLeft",
	WindupEarlyRight = "WindupEarlyRight",
	WindupLateLeft = "WindupLateLeft",
	WindupLateRight = "WindupLateRight",
	StrikeActiveLeft = "StrikeActiveLeft",
	StrikeActiveRight = "StrikeActiveRight",
	StrikeRecoveryLeft = "StrikeRecoveryLeft",
	StrikeRecoveryRight = "StrikeRecoveryRight",
	HitReaction = "HitReaction",
	StandDown = "StandDown",
	Dead = "Dead",
})

local SensorModes = table.freeze({
	Normal = "Normal",
	Alert = "Alert",
	Windup = "Windup",
	Strike = "Strike",
	Hit = "Hit",
	Dim = "Dim",
	Dead = "Dead",
})

local Timing = table.freeze({
	HitReactionSeconds = 0.28,
	WindupLateProgress = 0.55,
	AttackActiveSeconds = 0.16,
	AttackRecoverySeconds = 0.52,
})

export type PoseInput = {
	isDead: boolean,
	isStoodDown: boolean,
	isMoving: boolean,
	isPursuing: boolean,
	isWindingUp: boolean,
	windupSequence: number,
	windupProgress: number?,
	attackSequence: number,
	secondsSinceAttack: number?,
	secondsSinceHit: number?,
	strideIndex: number,
}

export type Pose = {
	id: string,
	torsoPitchDegrees: number,
	torsoRollDegrees: number,
	leftArmPitchDegrees: number,
	rightArmPitchDegrees: number,
	leftArmRollDegrees: number,
	rightArmRollDegrees: number,
	leftLegPitchDegrees: number,
	rightLegPitchDegrees: number,
	sensorMode: string,
}

local function pose(
	id: string,
	torsoPitchDegrees: number,
	torsoRollDegrees: number,
	leftArmPitchDegrees: number,
	rightArmPitchDegrees: number,
	leftArmRollDegrees: number,
	rightArmRollDegrees: number,
	leftLegPitchDegrees: number,
	rightLegPitchDegrees: number,
	sensorMode: string
): Pose
	return table.freeze({
		id = id,
		torsoPitchDegrees = torsoPitchDegrees,
		torsoRollDegrees = torsoRollDegrees,
		leftArmPitchDegrees = leftArmPitchDegrees,
		rightArmPitchDegrees = rightArmPitchDegrees,
		leftArmRollDegrees = leftArmRollDegrees,
		rightArmRollDegrees = rightArmRollDegrees,
		leftLegPitchDegrees = leftLegPitchDegrees,
		rightLegPitchDegrees = rightLegPitchDegrees,
		sensorMode = sensorMode,
	})
end

local IDLE = pose(PoseIds.Idle, 0, 0, 5, -5, 4, -4, 0, 0, SensorModes.Normal)
local THREAT_READY = pose(PoseIds.ThreatReady, -8, 0, -38, -38, 12, -12, 5, -5, SensorModes.Alert)
local WINDUP_EARLY_LEFT = pose(PoseIds.WindupEarlyLeft, 8, 7, 22, -54, -14, -18, -5, 5, SensorModes.Windup)
local WINDUP_EARLY_RIGHT = pose(PoseIds.WindupEarlyRight, 8, -7, -54, 22, 18, 14, 5, -5, SensorModes.Windup)
local WINDUP_LATE_LEFT = pose(PoseIds.WindupLateLeft, 15, 13, 48, -86, -25, -32, -10, 10, SensorModes.Windup)
local WINDUP_LATE_RIGHT = pose(PoseIds.WindupLateRight, 15, -13, -86, 48, 32, 25, 10, -10, SensorModes.Windup)
local STRIKE_ACTIVE_LEFT = pose(PoseIds.StrikeActiveLeft, -21, -11, -92, -24, -31, -6, 15, -15, SensorModes.Strike)
local STRIKE_ACTIVE_RIGHT = pose(PoseIds.StrikeActiveRight, -21, 11, -24, -92, 6, 31, -15, 15, SensorModes.Strike)
local STRIKE_RECOVERY_LEFT = pose(PoseIds.StrikeRecoveryLeft, 3, 6, -18, -42, 13, -16, -7, 7, SensorModes.Alert)
local STRIKE_RECOVERY_RIGHT = pose(PoseIds.StrikeRecoveryRight, 3, -6, -42, -18, 16, -13, 7, -7, SensorModes.Alert)
local HIT_REACTION = pose(PoseIds.HitReaction, 16, 9, 26, -34, -18, 20, -8, 8, SensorModes.Hit)
local STAND_DOWN = pose(PoseIds.StandDown, 19, 0, 38, 38, 12, -12, 0, 0, SensorModes.Dim)
local DEAD = pose(PoseIds.Dead, 72, 13, 66, 58, 24, -28, -18, 22, SensorModes.Dead)

local EnemyPresentationPoseResolver = {
	PoseIds = PoseIds,
	SensorModes = SensorModes,
	Timing = Timing,
}

function EnemyPresentationPoseResolver.resolve(input: PoseInput): Pose
	if input.isDead then
		return DEAD
	end

	local secondsSinceHit = input.secondsSinceHit
	if secondsSinceHit ~= nil and secondsSinceHit >= 0 and secondsSinceHit <= Timing.HitReactionSeconds then
		return HIT_REACTION
	end

	if input.isStoodDown then
		return STAND_DOWN
	end

	local windupProgress = input.windupProgress
	if input.isWindingUp and windupProgress ~= nil and windupProgress >= 0 and windupProgress <= 1 then
		local usesLeftArm = input.windupSequence % 2 == 1
		if windupProgress < Timing.WindupLateProgress then
			return if usesLeftArm then WINDUP_EARLY_LEFT else WINDUP_EARLY_RIGHT
		end
		return if usesLeftArm then WINDUP_LATE_LEFT else WINDUP_LATE_RIGHT
	end

	local secondsSinceAttack = input.secondsSinceAttack
	if secondsSinceAttack ~= nil and secondsSinceAttack >= 0 then
		local strikeUsesLeftArm = input.attackSequence % 2 == 1
		if secondsSinceAttack <= Timing.AttackActiveSeconds then
			return if strikeUsesLeftArm then STRIKE_ACTIVE_LEFT else STRIKE_ACTIVE_RIGHT
		end
		if secondsSinceAttack <= Timing.AttackRecoverySeconds then
			return if strikeUsesLeftArm then STRIKE_RECOVERY_LEFT else STRIKE_RECOVERY_RIGHT
		end
	end

	local strideIsEven = input.strideIndex % 2 == 0
	if input.isMoving and input.isPursuing then
		if strideIsEven then
			return pose(PoseIds.PursuingA, -16, -2, -34, 26, 7, -7, 24, -24, SensorModes.Alert)
		end
		return pose(PoseIds.PursuingB, -16, 2, 26, -34, 7, -7, -24, 24, SensorModes.Alert)
	end

	if input.isMoving then
		if strideIsEven then
			return pose(PoseIds.RoamingA, -6, -1, -16, 12, 5, -5, 13, -13, SensorModes.Normal)
		end
		return pose(PoseIds.RoamingB, -6, 1, 12, -16, 5, -5, -13, 13, SensorModes.Normal)
	end

	if input.isPursuing then
		return THREAT_READY
	end

	return IDLE
end

return table.freeze(EnemyPresentationPoseResolver)
''',
)

# Enemy director: add windup runtime state and disclosure.
replace_once(
    "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau",
    'local BehaviorStateIds = EnemyContracts.EnemyBehaviorStateIds\nlocal PresentationAttributeNames',
    'local BehaviorStateIds = EnemyContracts.EnemyBehaviorStateIds\nlocal AttackWindupActionIds = EnemyContracts.EnemyAttackWindupActionIds\nlocal PresentationAttributeNames',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau",
    '\tlastAttackServerTimestamp: number?,\n\tattackPresentationSequence: number,\n\thitPresentationSequence: number,',
    '\tlastAttackServerTimestamp: number?,\n\tattackAttemptSequence: number,\n\tattackWindupTargetOperativeEntityId: string?,\n\tattackWindupStartedServerTimestamp: number?,\n\tattackWindupPresentationSequence: number?,\n\tattackPresentationSequence: number,\n\thitPresentationSequence: number,',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau",
    '''local function initializePresentationAttributes(entry: EnemyEntry)\n\tentry.model:SetAttribute(PresentationAttributeNames.BehaviorStateId, entry.behaviorStateId)\n\tentry.model:SetAttribute(PresentationAttributeNames.LifeStateId, PresentationLifeStateIds.Alive)\n\tentry.model:SetAttribute(PresentationAttributeNames.AttackSequence, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.AttackServerTimestamp, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.HitSequence, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.HitServerTimestamp, 0)\nend\n\nlocal function discloseCommittedAttack(entry: EnemyEntry, serverTimestamp: number)\n\tentry.attackPresentationSequence += 1\n\tentry.model:SetAttribute(PresentationAttributeNames.AttackSequence, entry.attackPresentationSequence)\n\tentry.model:SetAttribute(PresentationAttributeNames.AttackServerTimestamp, serverTimestamp)\nend\n\nlocal function discloseCommittedHit(entry: EnemyEntry, serverTimestamp: number)\n\tentry.hitPresentationSequence += 1\n\tentry.model:SetAttribute(PresentationAttributeNames.HitSequence, entry.hitPresentationSequence)\n\tentry.model:SetAttribute(PresentationAttributeNames.HitServerTimestamp, serverTimestamp)\nend''',
    '''local function initializePresentationAttributes(entry: EnemyEntry)\n\tentry.model:SetAttribute(PresentationAttributeNames.BehaviorStateId, entry.behaviorStateId)\n\tentry.model:SetAttribute(PresentationAttributeNames.LifeStateId, PresentationLifeStateIds.Alive)\n\tentry.model:SetAttribute(PresentationAttributeNames.WindupSequence, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.WindupStartedServerTimestamp, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.WindupCommitServerTimestamp, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.AttackSequence, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.AttackServerTimestamp, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.HitSequence, 0)\n\tentry.model:SetAttribute(PresentationAttributeNames.HitServerTimestamp, 0)\nend\n\nlocal function clearAttackWindup(entry: EnemyEntry)\n\tentry.attackWindupTargetOperativeEntityId = nil\n\tentry.attackWindupStartedServerTimestamp = nil\n\tentry.attackWindupPresentationSequence = nil\nend\n\nlocal function beginAttackWindup(entry: EnemyEntry, targetOperativeEntityId: string, serverTimestamp: number)\n\tentry.attackAttemptSequence += 1\n\tentry.attackWindupTargetOperativeEntityId = targetOperativeEntityId\n\tentry.attackWindupStartedServerTimestamp = serverTimestamp\n\tentry.attackWindupPresentationSequence = entry.attackAttemptSequence\n\tentry.model:SetAttribute(PresentationAttributeNames.WindupStartedServerTimestamp, serverTimestamp)\n\tentry.model:SetAttribute(\n\t\tPresentationAttributeNames.WindupCommitServerTimestamp,\n\t\tserverTimestamp + EnemyConfig.Walker.AttackWindupSeconds\n\t)\n\tentry.model:SetAttribute(PresentationAttributeNames.WindupSequence, entry.attackAttemptSequence)\nend\n\nlocal function discloseCommittedAttack(entry: EnemyEntry, serverTimestamp: number, presentationSequence: number)\n\tentry.attackPresentationSequence = presentationSequence\n\tentry.model:SetAttribute(PresentationAttributeNames.AttackServerTimestamp, serverTimestamp)\n\tentry.model:SetAttribute(PresentationAttributeNames.AttackSequence, presentationSequence)\nend\n\nlocal function discloseCommittedHit(entry: EnemyEntry, serverTimestamp: number)\n\tentry.hitPresentationSequence += 1\n\tentry.model:SetAttribute(PresentationAttributeNames.HitServerTimestamp, serverTimestamp)\n\tentry.model:SetAttribute(PresentationAttributeNames.HitSequence, entry.hitPresentationSequence)\nend''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau",
    '\t\tlastAttackServerTimestamp = nil,\n\t\tattackPresentationSequence = 0,\n\t\thitPresentationSequence = 0,',
    '\t\tlastAttackServerTimestamp = nil,\n\t\tattackAttemptSequence = 0,\n\t\tattackWindupTargetOperativeEntityId = nil,\n\t\tattackWindupStartedServerTimestamp = nil,\n\t\tattackWindupPresentationSequence = nil,\n\t\tattackPresentationSequence = 0,\n\t\thitPresentationSequence = 0,',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau",
    '\t\tif entry.isAlive then\n\t\t\tsetPresentationBehaviorState(entry, BehaviorStateIds.StandDown)\n\t\t\tentry.targetOperativeEntityId = nil',
    '\t\tif entry.isAlive then\n\t\t\tclearAttackWindup(entry)\n\t\t\tsetPresentationBehaviorState(entry, BehaviorStateIds.StandDown)\n\t\t\tentry.targetOperativeEntityId = nil',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau",
    '''local function applyDeath(entry: EnemyEntry, serverTimestamp: number)\n\tentry.isAlive = false\n\tsetPresentationBehaviorState(entry, BehaviorStateIds.Dead)''',
    '''local function applyDeath(entry: EnemyEntry, serverTimestamp: number)\n\tentry.isAlive = false\n\tclearAttackWindup(entry)\n\tsetPresentationBehaviorState(entry, BehaviorStateIds.Dead)''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau",
    '''local function applyBehavior(entry: EnemyEntry, operativeFacts: { EnemyOperativeFact }, serverTimestamp: number): number\n\tlocal decision = EnemyBehaviorResolver.resolveBehavior({\n\t\tentityId = entry.entityId,\n\t\tbehaviorStateId = entry.behaviorStateId,\n\t\tposition = { x = entry.root.Position.X, y = entry.root.Position.Y, z = entry.root.Position.Z },\n\t\ttargetOperativeEntityId = entry.targetOperativeEntityId,\n\t\tlastAttackServerTimestamp = entry.lastAttackServerTimestamp,\n\t}, operativeFacts, serverTimestamp)\n\tif decision.rejectionReasonId ~= nil then\n\t\treturn 0\n\tend\n\tsetPresentationBehaviorState(entry, decision.behaviorStateIdAfter)\n\tentry.targetOperativeEntityId = decision.targetOperativeEntityId\n\n\tif decision.behaviorStateIdAfter == BehaviorStateIds.Pursuing then\n\t\tlocal targetId = decision.targetOperativeEntityId\n\t\tentry.humanoid.WalkSpeed = EnemyConfig.Walker.PursuitSpeedStudsPerSecond\n\t\tfor _, fact in operativeFacts do\n\t\t\tif fact.operativeEntityId == targetId then\n\t\t\t\tentry.humanoid:MoveTo(Vector3.new(fact.position.x, fact.position.y, fact.position.z))\n\t\t\t\tbreak\n\t\t\tend\n\t\tend\n\t\treturn 0\n\tend\n\tif decision.behaviorStateIdAfter == BehaviorStateIds.Roaming then\n\t\tentry.humanoid.WalkSpeed = EnemyConfig.Walker.RoamSpeedStudsPerSecond\n\t\tif serverTimestamp >= entry.nextRoamRetargetServerTimestamp then\n\t\t\tentry.nextRoamRetargetServerTimestamp = serverTimestamp + EnemyConfig.Walker.RoamRetargetIntervalSeconds\n\t\t\tlocal angle = nextSequence() * 2.399963\n\t\t\tlocal anchor = entry.roamAnchor\n\t\t\tlocal radius = EnemyConfig.Walker.RoamWanderRadiusStuds\n\t\t\tentry.humanoid:MoveTo(\n\t\t\t\tVector3.new(anchor.x + math.cos(angle) * radius, anchor.y, anchor.z + math.sin(angle) * radius)\n\t\t\t)\n\t\tend\n\t\treturn 0\n\tend\n\tif decision.behaviorStateIdAfter ~= BehaviorStateIds.Attacking then\n\t\treturn 0\n\tend\n\n\tentry.humanoid.WalkSpeed = EnemyConfig.Walker.PursuitSpeedStudsPerSecond\n\tlocal attack = decision.attack\n\tif not decision.shouldAttack or attack == nil then\n\t\treturn 0\n\tend\n\tlocal targetRead = OperativeLifeService.readByOperativeEntityId(attack.targetEntityId)\n\tif targetRead == nil or targetRead.snapshot.lifeStateId ~= "Alive" then\n\t\treturn 0\n\tend\n\tlocal commit = OperativeLifeService.applyAuthoritativeDamage(attack.targetEntityId, targetRead.revision, {\n\t\tdamageEventId = attack.damageEventId,\n\t\tsourceEntityId = attack.sourceEntityId,\n\t\ttargetEntityId = attack.targetEntityId,\n\t\tdamageAmount = attack.damageAmount,\n\t\tserverTimestamp = attack.serverTimestamp,\n\t})\n\tif commit.didCommit then\n\t\tentry.lastAttackServerTimestamp = attack.serverTimestamp\n\t\tdiscloseCommittedAttack(entry, attack.serverTimestamp)\n\t\treturn 1\n\tend\n\treturn 0\nend''',
    '''local function applyBehavior(entry: EnemyEntry, operativeFacts: { EnemyOperativeFact }, serverTimestamp: number): number\n\tlocal decision = EnemyBehaviorResolver.resolveBehavior({\n\t\tentityId = entry.entityId,\n\t\tbehaviorStateId = entry.behaviorStateId,\n\t\tposition = { x = entry.root.Position.X, y = entry.root.Position.Y, z = entry.root.Position.Z },\n\t\ttargetOperativeEntityId = entry.targetOperativeEntityId,\n\t\tlastAttackServerTimestamp = entry.lastAttackServerTimestamp,\n\t\tattackWindupTargetOperativeEntityId = entry.attackWindupTargetOperativeEntityId,\n\t\tattackWindupStartedServerTimestamp = entry.attackWindupStartedServerTimestamp,\n\t}, operativeFacts, serverTimestamp)\n\tif decision.rejectionReasonId ~= nil then\n\t\treturn 0\n\tend\n\tsetPresentationBehaviorState(entry, decision.behaviorStateIdAfter)\n\tentry.targetOperativeEntityId = decision.targetOperativeEntityId\n\n\tlocal windupActionId = decision.attackWindupActionId\n\tif windupActionId == AttackWindupActionIds.Begin then\n\t\tlocal targetId = decision.targetOperativeEntityId\n\t\tif targetId == nil then\n\t\t\treturn 0\n\t\tend\n\t\tbeginAttackWindup(entry, targetId, serverTimestamp)\n\t\tentry.humanoid.WalkSpeed = 0\n\t\treturn 0\n\telseif windupActionId == AttackWindupActionIds.Continue then\n\t\tentry.humanoid.WalkSpeed = 0\n\t\treturn 0\n\telseif windupActionId == AttackWindupActionIds.Cancel then\n\t\tclearAttackWindup(entry)\n\tend\n\n\tif decision.behaviorStateIdAfter == BehaviorStateIds.Pursuing then\n\t\tlocal targetId = decision.targetOperativeEntityId\n\t\tentry.humanoid.WalkSpeed = EnemyConfig.Walker.PursuitSpeedStudsPerSecond\n\t\tfor _, fact in operativeFacts do\n\t\t\tif fact.operativeEntityId == targetId then\n\t\t\t\tentry.humanoid:MoveTo(Vector3.new(fact.position.x, fact.position.y, fact.position.z))\n\t\t\t\tbreak\n\t\t\tend\n\t\tend\n\t\treturn 0\n\tend\n\tif decision.behaviorStateIdAfter == BehaviorStateIds.Roaming then\n\t\tentry.humanoid.WalkSpeed = EnemyConfig.Walker.RoamSpeedStudsPerSecond\n\t\tif serverTimestamp >= entry.nextRoamRetargetServerTimestamp then\n\t\t\tentry.nextRoamRetargetServerTimestamp = serverTimestamp + EnemyConfig.Walker.RoamRetargetIntervalSeconds\n\t\t\tlocal angle = nextSequence() * 2.399963\n\t\t\tlocal anchor = entry.roamAnchor\n\t\t\tlocal radius = EnemyConfig.Walker.RoamWanderRadiusStuds\n\t\t\tentry.humanoid:MoveTo(\n\t\t\t\tVector3.new(anchor.x + math.cos(angle) * radius, anchor.y, anchor.z + math.sin(angle) * radius)\n\t\t\t)\n\t\tend\n\t\treturn 0\n\tend\n\n\tif decision.behaviorStateIdAfter == BehaviorStateIds.WindingUp then\n\t\tentry.humanoid.WalkSpeed = 0\n\t\tlocal attack = decision.attack\n\t\tif windupActionId ~= AttackWindupActionIds.Commit or not decision.shouldAttack or attack == nil then\n\t\t\treturn 0\n\t\tend\n\t\tlocal targetRead = OperativeLifeService.readByOperativeEntityId(attack.targetEntityId)\n\t\tif targetRead == nil or targetRead.snapshot.lifeStateId ~= "Alive" then\n\t\t\treturn 0\n\t\tend\n\t\tlocal commit = OperativeLifeService.applyAuthoritativeDamage(attack.targetEntityId, targetRead.revision, {\n\t\t\tdamageEventId = attack.damageEventId,\n\t\t\tsourceEntityId = attack.sourceEntityId,\n\t\t\ttargetEntityId = attack.targetEntityId,\n\t\t\tdamageAmount = attack.damageAmount,\n\t\t\tserverTimestamp = attack.serverTimestamp,\n\t\t})\n\t\tif commit.didCommit then\n\t\t\tlocal presentationSequence = entry.attackWindupPresentationSequence\n\t\t\tif presentationSequence == nil then\n\t\t\t\treturn 0\n\t\t\tend\n\t\t\tentry.lastAttackServerTimestamp = attack.serverTimestamp\n\t\t\tclearAttackWindup(entry)\n\t\t\tsetPresentationBehaviorState(entry, BehaviorStateIds.Attacking)\n\t\t\tdiscloseCommittedAttack(entry, attack.serverTimestamp, presentationSequence)\n\t\t\treturn 1\n\t\tend\n\t\treturn 0\n\tend\n\n\tif decision.behaviorStateIdAfter == BehaviorStateIds.Attacking then\n\t\tentry.humanoid.WalkSpeed = EnemyConfig.Walker.PursuitSpeedStudsPerSecond\n\tend\n\treturn 0\nend''',
)

# Client controller: consume windup facts and map them to pose progress.
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '\tAlert = Color3.fromRGB(255, 145, 54),\n\tStrike = Color3.fromRGB(255, 204, 74),',
    '\tAlert = Color3.fromRGB(255, 145, 54),\n\tWindup = Color3.fromRGB(255, 176, 48),\n\tStrike = Color3.fromRGB(255, 204, 74),',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '\tAlert = 0,\n\tStrike = 0,',
    '\tAlert = 0,\n\tWindup = 0,\n\tStrike = 0,',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '\trightLegBaseC0: CFrame,\n\tattackSequence: number,',
    '\trightLegBaseC0: CFrame,\n\twindupSequence: number,\n\twindupStartedServerTimestamp: number?,\n\twindupCommitServerTimestamp: number?,\n\tattackSequence: number,',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '''\tlocal attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)\n\tlocal attackServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.AttackServerTimestamp)\n\tlocal hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)\n\tlocal hitServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.HitServerTimestamp)\n\tif attackSequence == nil or attackServerTimestamp == nil or hitSequence == nil or hitServerTimestamp == nil then\n\t\treturn\n\tend''',
    '''\tlocal windupSequence = readNumberAttribute(model, PresentationAttributeNames.WindupSequence)\n\tlocal windupStartedServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.WindupStartedServerTimestamp)\n\tlocal windupCommitServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.WindupCommitServerTimestamp)\n\tlocal attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)\n\tlocal attackServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.AttackServerTimestamp)\n\tlocal hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)\n\tlocal hitServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.HitServerTimestamp)\n\tif\n\t\twindupSequence == nil\n\t\tor windupStartedServerTimestamp == nil\n\t\tor windupCommitServerTimestamp == nil\n\t\tor attackSequence == nil\n\t\tor attackServerTimestamp == nil\n\t\tor hitSequence == nil\n\t\tor hitServerTimestamp == nil\n\tthen\n\t\treturn\n\tend''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '''\t\trightLegBaseC0 = rightLegMotor.C0,\n\t\tattackSequence = attackSequence,\n\t\tattackServerTimestamp = if attackSequence > 0 and attackServerTimestamp > 0 then attackServerTimestamp else nil,''',
    '''\t\trightLegBaseC0 = rightLegMotor.C0,\n\t\twindupSequence = windupSequence,\n\t\twindupStartedServerTimestamp = if windupSequence > 0 and windupStartedServerTimestamp > 0\n\t\t\tthen windupStartedServerTimestamp\n\t\t\telse nil,\n\t\twindupCommitServerTimestamp = if windupSequence > 0 and windupCommitServerTimestamp > windupStartedServerTimestamp\n\t\t\tthen windupCommitServerTimestamp\n\t\t\telse nil,\n\t\tattackSequence = attackSequence,\n\t\tattackServerTimestamp = if attackSequence > 0 and attackServerTimestamp > 0 then attackServerTimestamp else nil,''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '''local function updateRecord(model: Model, record: Record, serverTimestamp: number)\n\tlocal attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)''',
    '''local function updateRecord(model: Model, record: Record, serverTimestamp: number)\n\tlocal windupSequence = readNumberAttribute(model, PresentationAttributeNames.WindupSequence)\n\tlocal windupStartedServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.WindupStartedServerTimestamp)\n\tlocal windupCommitServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.WindupCommitServerTimestamp)\n\tlocal currentWindupStartedAt = record.windupStartedServerTimestamp or 0\n\tif\n\t\twindupSequence ~= nil\n\t\tand windupStartedServerTimestamp ~= nil\n\t\tand windupCommitServerTimestamp ~= nil\n\t\tand windupSequence >= record.windupSequence\n\t\tand windupStartedServerTimestamp > currentWindupStartedAt\n\t\tand windupCommitServerTimestamp > windupStartedServerTimestamp\n\tthen\n\t\trecord.windupSequence = windupSequence\n\t\trecord.windupStartedServerTimestamp = windupStartedServerTimestamp\n\t\trecord.windupCommitServerTimestamp = windupCommitServerTimestamp\n\tend\n\n\tlocal attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '''\t\tand attackSequence > record.attackSequence\n\t\tand attackServerTimestamp > 0\n\tthen''',
    '''\t\tand attackSequence >= record.attackSequence\n\t\tand attackServerTimestamp > (record.attackServerTimestamp or 0)\n\tthen''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '''\t\tand hitSequence > record.hitSequence\n\t\tand hitServerTimestamp > 0\n\tthen''',
    '''\t\tand hitSequence >= record.hitSequence\n\t\tand hitServerTimestamp > (record.hitServerTimestamp or 0)\n\tthen''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '''\tlocal attackAt = record.attackServerTimestamp\n\tlocal hitAt = record.hitServerTimestamp\n\tlocal secondsSinceAttack = if attackAt == nil then nil else serverTimestamp - attackAt\n\tlocal secondsSinceHit = if hitAt == nil then nil else serverTimestamp - hitAt\n\tlocal isDead = lifeStateId == PresentationLifeStateIds.Dead\n\tlocal isStoodDown = behaviorStateId == BehaviorStateIds.StandDown\n\tlocal isMoving = record.humanoid.MoveDirection.Magnitude > MOVEMENT_THRESHOLD\n\tlocal isPursuing = behaviorStateId == BehaviorStateIds.Pursuing or behaviorStateId == BehaviorStateIds.Attacking''',
    '''\tlocal windupStartedAt = record.windupStartedServerTimestamp\n\tlocal windupCommitAt = record.windupCommitServerTimestamp\n\tlocal attackAt = record.attackServerTimestamp\n\tlocal hitAt = record.hitServerTimestamp\n\tlocal secondsSinceAttack = if attackAt == nil then nil else serverTimestamp - attackAt\n\tlocal secondsSinceHit = if hitAt == nil then nil else serverTimestamp - hitAt\n\tlocal isDead = lifeStateId == PresentationLifeStateIds.Dead\n\tlocal isStoodDown = behaviorStateId == BehaviorStateIds.StandDown\n\tlocal isWindingUp = behaviorStateId == BehaviorStateIds.WindingUp\n\tlocal windupProgress = nil\n\tif isWindingUp and windupStartedAt ~= nil and windupCommitAt ~= nil and windupCommitAt > windupStartedAt then\n\t\twindupProgress = math.clamp((serverTimestamp - windupStartedAt) / (windupCommitAt - windupStartedAt), 0, 1)\n\tend\n\tlocal isMoving = record.humanoid.MoveDirection.Magnitude > MOVEMENT_THRESHOLD\n\tlocal isPursuing = behaviorStateId == BehaviorStateIds.Pursuing\n\t\tor behaviorStateId == BehaviorStateIds.WindingUp\n\t\tor behaviorStateId == BehaviorStateIds.Attacking''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau",
    '''\t\tisMoving = isMoving,\n\t\tisPursuing = isPursuing,\n\t\tattackSequence = record.attackSequence,''',
    '''\t\tisMoving = isMoving,\n\t\tisPursuing = isPursuing,\n\t\tisWindingUp = isWindingUp,\n\t\twindupSequence = record.windupSequence,\n\t\twindupProgress = windupProgress,\n\t\tattackSequence = record.attackSequence,''',
)

# Presentation contract test.
write(
    "games/living-kingdoms/tests/EnemyPresentationContracts.test.luau",
    r'''--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau"), {
	debugName = "EnemyPresentationContracts",
	injectGlobals = true,
})()

local expected = {
	"EnemyPresentationBehaviorStateId",
	"EnemyPresentationLifeStateId",
	"EnemyPresentationWindupSequence",
	"EnemyPresentationWindupStartedServerTimestamp",
	"EnemyPresentationWindupCommitServerTimestamp",
	"EnemyPresentationAttackSequence",
	"EnemyPresentationAttackServerTimestamp",
	"EnemyPresentationHitSequence",
	"EnemyPresentationHitServerTimestamp",
}
local observed = {}
for _, attributeName in contracts.AttributeNames do
	assertThat(type(attributeName) == "string" and attributeName ~= "", "attribute names must be non-empty strings")
	assertThat(not observed[attributeName], "presentation attribute names must be unique")
	observed[attributeName] = true
end
for _, attributeName in expected do
	assertThat(observed[attributeName] == true, "missing presentation attribute " .. attributeName)
end
assertThat(contracts.LifeStateIds.Alive == "Alive" and contracts.LifeStateIds.Dead == "Dead", "life IDs drifted")

local mutationSucceeded = pcall(function()
	contracts.AttributeNames.WindupSequence = "mutated"
end)
assertThat(not mutationSucceeded, "presentation contracts must be immutable")

print("EnemyPresentationContracts: nine unique immutable disclosure attributes passed")
''',
)

# Pose resolver test.
write(
    "games/living-kingdoms/tests/EnemyPresentationPoseResolver.test.luau",
    r'''--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/client/Presentation/EnemyPresentationPoseResolver.luau"),
	{
		debugName = "EnemyPresentationPoseResolver",
		injectGlobals = true,
	}
)()

local function resolve(overrides)
	local input = {
		isDead = false,
		isStoodDown = false,
		isMoving = false,
		isPursuing = false,
		isWindingUp = false,
		windupSequence = 0,
		windupProgress = nil,
		attackSequence = 0,
		secondsSinceAttack = nil,
		secondsSinceHit = nil,
		strideIndex = 0,
	}
	for key, value in overrides do
		input[key] = value
	end
	return resolver.resolve(input)
end

assertThat(resolve({}).id == resolver.PoseIds.Idle, "stationary living Walker must use Idle")
assertThat(resolve({ isMoving = true, strideIndex = 0 }).id == resolver.PoseIds.RoamingA, "roaming even stride")
assertThat(resolve({ isMoving = true, strideIndex = 1 }).id == resolver.PoseIds.RoamingB, "roaming odd stride")
assertThat(
	resolve({ isMoving = true, isPursuing = true, strideIndex = 0 }).id == resolver.PoseIds.PursuingA,
	"pursuit even stride"
)
assertThat(resolve({ isPursuing = true }).id == resolver.PoseIds.ThreatReady, "stationary pursuit threat pose")
assertThat(
	resolve({ isWindingUp = true, windupSequence = 1, windupProgress = 0 }).id == resolver.PoseIds.WindupEarlyLeft,
	"odd windup starts on the left"
)
assertThat(
	resolve({ isWindingUp = true, windupSequence = 1, windupProgress = 0.55 }).id == resolver.PoseIds.WindupLateLeft,
	"windup late boundary must be inclusive"
)
assertThat(
	resolve({ isWindingUp = true, windupSequence = 2, windupProgress = 1 }).id == resolver.PoseIds.WindupLateRight,
	"even windup ends on the right"
)
assertThat(
	resolve({ isWindingUp = true, windupSequence = 1, windupProgress = 1.01, isPursuing = true }).id
		== resolver.PoseIds.ThreatReady,
	"malformed progress must not fabricate anticipation"
)
assertThat(
	resolve({ attackSequence = 1, secondsSinceAttack = 0 }).id == resolver.PoseIds.StrikeActiveLeft,
	"confirmed odd attack uses matching left strike"
)
assertThat(
	resolve({ attackSequence = 2, secondsSinceAttack = 0.16 }).id == resolver.PoseIds.StrikeActiveRight,
	"active strike includes exact boundary"
)
assertThat(
	resolve({ attackSequence = 2, secondsSinceAttack = 0.161 }).id == resolver.PoseIds.StrikeRecoveryRight,
	"recovery begins after active boundary"
)
assertThat(resolve({ isStoodDown = true }).id == resolver.PoseIds.StandDown, "stand-down pose")
assertThat(resolve({ secondsSinceHit = 0.28 }).id == resolver.PoseIds.HitReaction, "hit exact upper boundary")
assertThat(
	resolve({ isWindingUp = true, windupSequence = 1, windupProgress = 0.8, secondsSinceHit = 0.1 }).id
		== resolver.PoseIds.HitReaction,
	"committed hit overrides windup"
)
assertThat(
	resolve({ isStoodDown = true, isWindingUp = true, windupSequence = 1, windupProgress = 0.8 }).id
		== resolver.PoseIds.StandDown,
	"stand-down suppresses stale windup"
)
assertThat(
	resolve({ isDead = true, isStoodDown = true, isWindingUp = true, windupProgress = 0.8, secondsSinceHit = 0.1 }).id
		== resolver.PoseIds.Dead,
	"death has first precedence"
)

local poseMutationSucceeded = pcall(function()
	resolve({}).torsoPitchDegrees = 999
end)
assertThat(not poseMutationSucceeded, "resolved poses must be immutable")

print("EnemyPresentationPoseResolver: windup, strike, precedence, boundaries, and immutability passed")
''',
)

# Behavior resolver fixture: add pending windup facts and replace attack section.
replace_once(
    "games/living-kingdoms/tests/EnemyBehaviorResolver.test.luau",
    '\t\ttargetOperativeEntityId = nil,\n\t\tlastAttackServerTimestamp = nil,',
    '\t\ttargetOperativeEntityId = nil,\n\t\tlastAttackServerTimestamp = nil,\n\t\tattackWindupTargetOperativeEntityId = nil,\n\t\tattackWindupStartedServerTimestamp = nil,',
)
replace_once(
    "games/living-kingdoms/tests/EnemyBehaviorResolver.test.luau",
    '''-- Attack range is inclusive; the first swing needs no elapsed cooldown.\nlocal firstSwing = resolver.resolveBehavior(enemyFacts(), { operative("operative:a", walker.AttackRangeStuds, 0) }, 10)\nassert(firstSwing.behaviorStateIdAfter == "Attacking" and firstSwing.shouldAttack)\nlocal attack = firstSwing.attack\nassert(attack ~= nil)\nassert(attack.damageEventId == "enemyattack:enemy.test.alpha:operative:a:10")\nassert(attack.sourceEntityId == "enemy.test.alpha" and attack.targetEntityId == "operative:a")\nassert(attack.damageAmount == walker.AttackDamage and attack.serverTimestamp == 10)\n\n-- Cooldown gate: just before is blocked but still Attacking; exactly at the\n-- deadline swings again.\nlocal blocked = resolver.resolveBehavior(\n\tenemyFacts({ lastAttackServerTimestamp = 10 }),\n\t{ operative("operative:a", 2, 0) },\n\t10 + walker.AttackCooldownSeconds - 0.01\n)\nassert(blocked.behaviorStateIdAfter == "Attacking" and not blocked.shouldAttack and blocked.attack == nil)\nlocal secondSwing = resolver.resolveBehavior(\n\tenemyFacts({ lastAttackServerTimestamp = 10 }),\n\t{ operative("operative:a", 2, 0) },\n\t10 + walker.AttackCooldownSeconds\n)\nassert(secondSwing.shouldAttack and secondSwing.attack ~= nil)''',
    '''-- Attack range is inclusive, but damage begins with a real server-owned windup.\nlocal beginWindup = resolver.resolveBehavior(enemyFacts(), { operative("operative:a", walker.AttackRangeStuds, 0) }, 10)\nassert(beginWindup.behaviorStateIdAfter == "WindingUp")\nassert(beginWindup.attackWindupActionId == "Begin" and not beginWindup.shouldAttack and beginWindup.attack == nil)\n\nlocal windingFacts = enemyFacts({\n\tbehaviorStateId = "WindingUp",\n\ttargetOperativeEntityId = "operative:a",\n\tattackWindupTargetOperativeEntityId = "operative:a",\n\tattackWindupStartedServerTimestamp = 10,\n})\nlocal continuing = resolver.resolveBehavior(windingFacts, { operative("operative:a", 2, 0) }, 10 + walker.AttackWindupSeconds - 0.01)\nassert(continuing.behaviorStateIdAfter == "WindingUp" and continuing.attackWindupActionId == "Continue")\nassert(not continuing.shouldAttack and continuing.attack == nil)\nlocal commit = resolver.resolveBehavior(windingFacts, { operative("operative:a", 2, 0) }, 10 + walker.AttackWindupSeconds)\nassert(commit.behaviorStateIdAfter == "WindingUp" and commit.attackWindupActionId == "Commit" and commit.shouldAttack)\nlocal attack = commit.attack\nassert(attack ~= nil)\nassert(attack.damageEventId == "enemyattack:enemy.test.alpha:operative:a:10")\nassert(attack.sourceEntityId == "enemy.test.alpha" and attack.targetEntityId == "operative:a")\nassert(attack.damageAmount == walker.AttackDamage and attack.serverTimestamp == 10 + walker.AttackWindupSeconds)\n\nlocal canceled = resolver.resolveBehavior(windingFacts, { operative("operative:a", walker.AttackRangeStuds + 0.01, 0) }, 10.2)\nassert(canceled.behaviorStateIdAfter == "Pursuing" and canceled.attackWindupActionId == "Cancel")\nassert(not canceled.shouldAttack and canceled.attack == nil)\n\n-- Partial or fabricated windup facts are invalid.\nassert(\n\tresolver.resolveBehavior(enemyFacts({ behaviorStateId = "WindingUp" }), { operative("operative:a", 2, 0) }, 10).rejectionReasonId\n\t\t== "InvalidFacts"\n)\nassert(\n\tresolver.resolveBehavior(\n\t\tenemyFacts({ attackWindupTargetOperativeEntityId = "operative:a" }),\n\t\t{ operative("operative:a", 2, 0) },\n\t\t10\n\t).rejectionReasonId == "InvalidFacts"\n)\n\n-- Cooldown gate: just before is blocked; exactly at the deadline starts the next windup.\nlocal blocked = resolver.resolveBehavior(\n\tenemyFacts({ lastAttackServerTimestamp = 10 }),\n\t{ operative("operative:a", 2, 0) },\n\t10 + walker.AttackCooldownSeconds - 0.01\n)\nassert(blocked.behaviorStateIdAfter == "Attacking" and blocked.attackWindupActionId == "None")\nassert(not blocked.shouldAttack and blocked.attack == nil)\nlocal secondWindup = resolver.resolveBehavior(\n\tenemyFacts({ lastAttackServerTimestamp = 10 }),\n\t{ operative("operative:a", 2, 0) },\n\t10 + walker.AttackCooldownSeconds\n)\nassert(secondWindup.behaviorStateIdAfter == "WindingUp" and secondWindup.attackWindupActionId == "Begin")''',
)

# Enemy director fixture: synchronize contract mock and attack lifecycle assertions.
replace_once(
    "games/living-kingdoms/tests/EnemyDirectorService.test.luau",
    '''-- Attacks: in range, cooldown-gated, deterministic event IDs, Alive-only.\n-- The spawn is fair; the operative then walks into melee range.\nreset()\nlocal target, targetRoot = addOperative("operative.player:7", 300, 300)\nassert(service.spawnEnemy(request("enemy.biter", 0, 0)).didSpawn)\ntargetRoot.Position = roblox.Vector3.new(3, 2, 0)\nnow = 10\nlocal swing = service.evaluateAt(now)\nassert(swing.attackCommittedCount == 1 and #damageCalls == 1)\nassert(damageCalls[1].operativeEntityId == "operative.player:7")\nassert(damageCalls[1].expectedRevision == 0)\nassert(damageCalls[1].damage.damageEventId == "enemyattack:enemy.biter:operative.player:7:10")\nassert(damageCalls[1].damage.damageAmount == walker.AttackDamage)\nassert(damageCalls[1].damage.sourceEntityId == "enemy.biter")\nassert(damageCalls[1].damage.serverTimestamp == 10)\nnow = 10 + walker.AttackCooldownSeconds - 0.01\nassert(service.evaluateAt(now).attackCommittedCount == 0, "cooldown must block the second swing")\nnow = 10 + walker.AttackCooldownSeconds\nassert(service.evaluateAt(now).attackCommittedCount == 1)\nassert(#damageCalls == 2)\n-- A rejected life commit leaves the cooldown unarmed so the swing retries.\nrejectNextDamage = true\nnow += walker.AttackCooldownSeconds\nassert(service.evaluateAt(now).attackCommittedCount == 0)\nnow += 0.2\nassert(service.evaluateAt(now).attackCommittedCount == 1, "rejected commits must not consume the cooldown")\n-- Downed operatives are not attacked.\ntarget.snapshot.lifeStateId = "Incapacitated"\nnow += walker.AttackCooldownSeconds\nassert(service.evaluateAt(now).attackCommittedCount == 0, "only Alive operatives receive enemy damage")''',
    '''-- Attacks: a server-owned windup precedes every commit and can be canceled.\n-- The spawn is fair; the operative then walks into melee range.\nreset()\nlocal target, targetRoot = addOperative("operative.player:7", 300, 300)\nassert(service.spawnEnemy(request("enemy.biter", 0, 0)).didSpawn)\ntargetRoot.Position = roblox.Vector3.new(3, 2, 0)\nlocal biterModel = findCreated("Test Walker")\nassert(biterModel ~= nil)\nnow = 10\nlocal windup = service.evaluateAt(now)\nassert(windup.attackCommittedCount == 0 and #damageCalls == 0)\nassert(biterModel:GetAttribute("EnemyPresentationBehaviorStateId") == "WindingUp")\nassert(biterModel:GetAttribute("EnemyPresentationWindupSequence") == 1)\nassert(biterModel:GetAttribute("EnemyPresentationWindupStartedServerTimestamp") == 10)\nassert(biterModel:GetAttribute("EnemyPresentationWindupCommitServerTimestamp") == 10 + walker.AttackWindupSeconds)\nnow = 10 + walker.AttackWindupSeconds - 0.01\nassert(service.evaluateAt(now).attackCommittedCount == 0 and #damageCalls == 0)\nnow = 10 + walker.AttackWindupSeconds\nlocal swing = service.evaluateAt(now)\nassert(swing.attackCommittedCount == 1 and #damageCalls == 1)\nassert(damageCalls[1].operativeEntityId == "operative.player:7")\nassert(damageCalls[1].expectedRevision == 0)\nassert(damageCalls[1].damage.damageEventId == "enemyattack:enemy.biter:operative.player:7:10")\nassert(damageCalls[1].damage.damageAmount == walker.AttackDamage)\nassert(damageCalls[1].damage.sourceEntityId == "enemy.biter")\nassert(damageCalls[1].damage.serverTimestamp == now)\nassert(biterModel:GetAttribute("EnemyPresentationAttackSequence") == 1)\nassert(biterModel:GetAttribute("EnemyPresentationAttackServerTimestamp") == now)\nassert(biterModel:GetAttribute("EnemyPresentationBehaviorStateId") == "Attacking")\n\n-- Leaving melee range during windup cancels damage and resumes pursuit.\nreset()\ntarget, targetRoot = addOperative("operative.player:7", 300, 300)\nassert(service.spawnEnemy(request("enemy.cancel", 0, 0)).didSpawn)\ntargetRoot.Position = roblox.Vector3.new(3, 2, 0)\nnow = 20\nassert(service.evaluateAt(now).attackCommittedCount == 0)\nlocal cancelModel = findCreated("Test Walker")\nassert(cancelModel ~= nil and cancelModel:GetAttribute("EnemyPresentationWindupSequence") == 1)\ntargetRoot.Position = roblox.Vector3.new(walker.AttackRangeStuds + 1, 2, 0)\nnow += 0.2\nassert(service.evaluateAt(now).attackCommittedCount == 0 and #damageCalls == 0)\nassert(cancelModel:GetAttribute("EnemyPresentationBehaviorStateId") == "Pursuing")\nassert(cancelModel:GetAttribute("EnemyPresentationAttackSequence") == 0)\n\n-- Cooldown starts at the committed strike, then another complete windup is required.\nreset()\ntarget, targetRoot = addOperative("operative.player:7", 300, 300)\nassert(service.spawnEnemy(request("enemy.retry", 0, 0)).didSpawn)\ntargetRoot.Position = roblox.Vector3.new(3, 2, 0)\nnow = 30\nservice.evaluateAt(now)\nnow += walker.AttackWindupSeconds\nassert(service.evaluateAt(now).attackCommittedCount == 1)\nlocal firstCommitAt = now\nnow = firstCommitAt + walker.AttackCooldownSeconds - 0.01\nassert(service.evaluateAt(now).attackCommittedCount == 0, "cooldown must block a new windup")\nnow = firstCommitAt + walker.AttackCooldownSeconds\nassert(service.evaluateAt(now).attackCommittedCount == 0, "cooldown deadline starts a windup, not instant damage")\nlocal retryModel = findCreated("Test Walker")\nassert(retryModel ~= nil and retryModel:GetAttribute("EnemyPresentationWindupSequence") == 2)\n\n-- A rejected life commit keeps the same windup pending and retries without a hidden instant attack.\nrejectNextDamage = true\nnow += walker.AttackWindupSeconds\nassert(service.evaluateAt(now).attackCommittedCount == 0)\nassert(retryModel:GetAttribute("EnemyPresentationBehaviorStateId") == "WindingUp")\nassert(retryModel:GetAttribute("EnemyPresentationAttackSequence") == 1)\nnow += 0.2\nassert(service.evaluateAt(now).attackCommittedCount == 1, "rejected commits must retry the disclosed windup")\nassert(retryModel:GetAttribute("EnemyPresentationAttackSequence") == 2)\n-- Downed operatives never begin a windup.\ntarget.snapshot.lifeStateId = "Incapacitated"\nnow += walker.AttackCooldownSeconds\nassert(service.evaluateAt(now).attackCommittedCount == 0, "only Alive operatives receive enemy damage")''',
)
replace_once(
    "games/living-kingdoms/tests/EnemyDirectorService.test.luau",
    '''local afterHit = service.readHealthState("enemy.mark")\nassert(afterHit ~= nil and afterHit.revision == 2 and afterHit.healthState.currentHealth == 40)''',
    '''local afterHit = service.readHealthState("enemy.mark")\nassert(afterHit ~= nil and afterHit.revision == 2 and afterHit.healthState.currentHealth == 40)\nlocal hitModel = findCreated("Test Walker")\nassert(hitModel ~= nil and hitModel:GetAttribute("EnemyPresentationHitSequence") == 1)\nassert(hitModel:GetAttribute("EnemyPresentationHitServerTimestamp") == 5)''',
)
replace_once(
    "games/living-kingdoms/tests/EnemyDirectorService.test.luau",
    '''local dead = service.readHealthState("enemy.mark")\nassert(dead ~= nil and not dead.isAlive)''',
    '''local dead = service.readHealthState("enemy.mark")\nassert(dead ~= nil and not dead.isAlive)\nassert(hitModel:GetAttribute("EnemyPresentationHitSequence") == 2)\nassert(hitModel:GetAttribute("EnemyPresentationHitServerTimestamp") == 7)\nassert(hitModel:GetAttribute("EnemyPresentationLifeStateId") == "Dead")\nassert(hitModel:GetAttribute("EnemyPresentationBehaviorStateId") == "Dead")''',
)

# Source audit now locks truthful windup and runtime bounds.
write(
    "games/living-kingdoms/tests/ExclusionWalkerStateReadabilitySourceAudit.test.luau",
    r'''--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local serverPresenter = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyPresentationService.luau")
local director = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
local behaviorResolver = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyBehaviorResolver.luau")
local enemyConfig = fs.readFile("games/living-kingdoms/src/shared/Config/EnemyConfig.luau")
local contracts = fs.readFile("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyPresentationController.luau")
local resolver = fs.readFile("games/living-kingdoms/src/client/Presentation/EnemyPresentationPoseResolver.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local manifest = fs.readFile("games/living-kingdoms/assets/visual/enemy/standard-hostile/asset-manifest.json")
local readme = fs.readFile("games/living-kingdoms/assets/visual/enemy/standard-hostile/README.md")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")

for _, required in {
	'Instance.new("Motor6D")',
	'"TorsoMotor"',
	'"ForearmLeftMotor"',
	'"ForearmRightMotor"',
	'"LegLeftMotor"',
	'"LegRightMotor"',
	'presentation:SetAttribute("PresentationMotorCount", 5)',
} do
	assertThat(string.find(serverPresenter, required, 1, true) ~= nil, "motorized Walker rig missing: " .. required)
end

for _, attributeName in {
	"EnemyPresentationBehaviorStateId",
	"EnemyPresentationLifeStateId",
	"EnemyPresentationWindupSequence",
	"EnemyPresentationWindupStartedServerTimestamp",
	"EnemyPresentationWindupCommitServerTimestamp",
	"EnemyPresentationAttackSequence",
	"EnemyPresentationAttackServerTimestamp",
	"EnemyPresentationHitSequence",
	"EnemyPresentationHitServerTimestamp",
} do
	assertThat(string.find(contracts, attributeName, 1, true) ~= nil, "presentation contract missing " .. attributeName)
end

for _, required in {
	"AttackWindupSeconds = 0.6",
	"AttackWindupActionIds.Begin",
	"AttackWindupActionIds.Continue",
	"AttackWindupActionIds.Cancel",
	"AttackWindupActionIds.Commit",
	"serverTimestamp < commitAt",
	"windupTargetDistanceSquared <= attackRangeSquared",
} do
	assertThat(string.find(behaviorResolver .. enemyConfig, required, 1, true) ~= nil, "windup contract missing: " .. required)
end

for _, required in {
	"initializePresentationAttributes(entry)",
	"beginAttackWindup(entry, targetId, serverTimestamp)",
	"clearAttackWindup(entry)",
	"discloseCommittedAttack(entry, attack.serverTimestamp, presentationSequence)",
	"discloseCommittedHit(entry, serverTimestamp)",
	"PresentationAttributeNames.WindupSequence",
	"PresentationAttributeNames.AttackSequence",
	"PresentationAttributeNames.HitSequence",
	"PresentationLifeStateIds.Dead",
} do
	assertThat(string.find(director, required, 1, true) ~= nil, "server disclosure missing: " .. required)
end

for _, required in {
	"RunService.RenderStepped:Connect",
	"folder.DescendantAdded:Connect",
	"folder.ChildRemoved:Connect",
	"Workspace:GetServerTimeNow()",
	"PresentationAttributeNames.WindupStartedServerTimestamp",
	"PresentationAttributeNames.WindupCommitServerTimestamp",
	"behaviorStateId == BehaviorStateIds.WindingUp",
	"EnemyPresentationPoseResolver.resolve",
	"record.torsoMotor.C0 =",
	"record.sensor.Color =",
} do
	assertThat(string.find(controller, required, 1, true) ~= nil, "Walker state controller missing: " .. required)
end

local _, renderConnectionCount = string.gsub(controller, "RenderStepped:Connect", "")
assertThat(renderConnectionCount == 1, "Walker state readability must use exactly one client frame connection")
local _, descendantConnectionCount = string.gsub(controller, "DescendantAdded:Connect", "")
assertThat(descendantConnectionCount == 1, "Walker state readability must use one folder descendant listener")
local _, removedConnectionCount = string.gsub(controller, "ChildRemoved:Connect", "")
assertThat(removedConnectionCount == 1, "Walker state readability must use one folder removal listener")

for _, forbidden in {
	"FireServer",
	"InvokeServer",
	"RemoteEvent",
	"RemoteFunction",
	"OnClientEvent",
	"GetPropertyChangedSignal",
	".Changed:Connect",
	"Humanoid:MoveTo",
	"TakeDamage",
	"applyAuthoritativeDamage",
	"SetNetworkOwner",
	"root.CFrame =",
	"root.Position =",
	"humanoid.WalkSpeed =",
	"healthLabel.Text =",
	"string.match",
	"Anchored =",
	"task.delay",
	"task.spawn",
} do
	assertThat(
		not string.find(controller, forbidden, 1, true),
		"Walker state controller must not contain network, scheduler, inference, or gameplay mutation token " .. forbidden
	)
end

for _, required in {
	'WindupEarlyLeft = "WindupEarlyLeft"',
	'WindupEarlyRight = "WindupEarlyRight"',
	'WindupLateLeft = "WindupLateLeft"',
	'WindupLateRight = "WindupLateRight"',
	"WindupLateProgress = 0.55",
	'StrikeActiveLeft = "StrikeActiveLeft"',
	'StrikeRecoveryRight = "StrikeRecoveryRight"',
	"AttackActiveSeconds = 0.16",
	"AttackRecoverySeconds = 0.52",
	'HitReaction = "HitReaction"',
	'StandDown = "StandDown"',
	'Dead = "Dead"',
	"if input.isDead then",
} do
	assertThat(string.find(resolver, required, 1, true) ~= nil, "Walker pose resolver missing: " .. required)
end

local requireIndex = string.find(bootstrap, "local EnemyPresentationController = require", 1, true)
local startIndex = string.find(bootstrap, "EnemyPresentationController.start()", 1, true)
assertThat(requireIndex ~= nil and startIndex ~= nil and requireIndex < startIndex, "client bootstrap must start presentation")
assertThat(string.find(manifest, '"serverPresentationAttributeCount": 9', 1, true) ~= nil, "manifest attribute count")
assertThat(string.find(manifest, '"clientFrameConnections": 1', 1, true) ~= nil, "manifest frame connection")
assertThat(string.find(manifest, '"connectionsPerEnemy": 0', 1, true) ~= nil, "manifest per-enemy connections")
assertThat(string.find(readme, "0.6-second server-owned windup", 1, true) ~= nil, "README windup contract")
assertThat(string.find(roadmap, "cancelable 0.6-second server-owned windup", 1, true) ~= nil, "roadmap windup")

print("ExclusionWalkerStateReadabilitySourceAudit: windup, disclosure, poses, authority, bounds, and docs passed")
''',
)

# Manifest and documentation.
replace_once(
    "games/living-kingdoms/assets/visual/enemy/standard-hostile/asset-manifest.json",
    '    "ThreatReady",\n    "StrikeActiveLeft",',
    '    "ThreatReady",\n    "WindupEarlyLeft",\n    "WindupEarlyRight",\n    "WindupLateLeft",\n    "WindupLateRight",\n    "StrikeActiveLeft",',
)
replace_once(
    "games/living-kingdoms/assets/visual/enemy/standard-hostile/asset-manifest.json",
    '    "EnemyPresentationLifeStateId",\n    "EnemyPresentationAttackSequence",',
    '    "EnemyPresentationLifeStateId",\n    "EnemyPresentationWindupSequence",\n    "EnemyPresentationWindupStartedServerTimestamp",\n    "EnemyPresentationWindupCommitServerTimestamp",\n    "EnemyPresentationAttackSequence",',
)
replace_once(
    "games/living-kingdoms/assets/visual/enemy/standard-hostile/asset-manifest.json",
    '"serverPresentationAttributeCount": 6',
    '"serverPresentationAttributeCount": 9',
)
replace_once(
    "games/living-kingdoms/assets/visual/enemy/standard-hostile/README.md",
    '`EnemyDirectorService` now writes six ordinary replicated model attributes for presentation only: exact behavior state, life state, confirmed attack sequence/timestamp, and confirmed hit sequence/timestamp. `EnemyPresentationController` consumes those server-authored facts plus replicated movement direction. It provides:',
    '`EnemyDirectorService` now writes nine ordinary replicated model attributes for presentation only: exact behavior/life state, a target-locked 0.6-second server-owned windup sequence/start/deadline, confirmed attack sequence/timestamp, and confirmed hit sequence/timestamp. `EnemyPresentationController` consumes those server-authored facts plus replicated movement direction. It provides:',
)
replace_once(
    "games/living-kingdoms/assets/visual/enemy/standard-hostile/README.md",
    '- a raised non-strike threat-ready pose while the authoritative state is `Pursuing` or `Attacking`;\n- alternating left/right active-strike and recovery poses only after authoritative damage commits;',
    '- a raised non-strike threat-ready pose while the authoritative state is `Pursuing` or `Attacking`;\n- alternating left/right early/late windup poses while the server has locked a living target inside melee range;\n- alternating left/right active-strike and recovery poses only after authoritative damage commits;',
)
replace_once(
    "games/living-kingdoms/assets/visual/enemy/standard-hostile/README.md",
    'This slice still does **not** claim attack anticipation. The current contact-damage contract has no windup phase, so the presentation begins only after the server confirms damage and never predicts a strike from proximity.',
    'Attack anticipation is now truthful rather than inferred. The server locks one target, stops the Walker, discloses a 0.6-second deadline, cancels if the target dies or leaves melee range, and applies damage only after the deadline. Rejected damage commits retain the same disclosed windup and retry without consuming cooldown.',
)
replace_once(
    "games/living-kingdoms/assets/visual/enemy/standard-hostile/README.md",
    '7. Verify roaming, pursuit, threat-ready, confirmed active-strike/recovery, hit, stand-down, and death readability without relying on sensor color alone.\n8. Do not mark the candidate production-approved until attack anticipation, effects, audio, cleanup, and representative performance gates pass.',
    '7. Verify roaming, pursuit, threat-ready, early/late windup, confirmed active-strike/recovery, hit, stand-down, and death readability without relying on sensor color alone.\n8. Do not mark the candidate production-approved until effects, audio, cleanup, and representative performance gates pass.',
)
replace_once(
    "games/living-kingdoms/assets/visual/enemy/standard-hostile/README.md",
    'The deterministic source, motorized procedural fallback, server-authored presentation disclosure, and client-local confirmed strike/recovery, hit, locomotion, death, and stand-down poses are implemented. Imported mesh review, attack anticipation, effects, audio, cosmetic variants, and representative horde performance evidence remain pending.',
    'The deterministic source, motorized procedural fallback, server-owned cancelable windup, confirmed strike/recovery, hit, locomotion, death, and stand-down poses are implemented. Imported mesh review, effects, audio, cosmetic variants, and representative horde performance evidence remain pending.',
)
replace_once(
    "docs/roadmap/VISUAL-PRODUCTION-TRACK.md",
    '  - Six server-authored model attributes disclose exact behavior/life state plus confirmed attack and hit sequences/timestamps; alternating left/right active-strike and recovery poses begin only after authoritative damage commits.\n',
    '  - Nine server-authored model attributes disclose exact behavior/life state, a cancelable 0.6-second server-owned windup, and confirmed attack/hit sequences and timestamps; alternating left/right early/late anticipation flows into matching committed strike/recovery poses.\n',
)
replace_once(
    "docs/roadmap/VISUAL-PRODUCTION-TRACK.md",
    '  - Attack anticipation remains pending because the contact-damage contract has no windup disclosure; the presentation layer never predicts a strike from distance or motion.\n  - Still required: Roblox Studio mesh import/canonical swap, truthful attack anticipation, effects, audio, bounded cosmetic variants, and representative horde performance evidence.',
    '  - Windup is target-locked, stops Walker movement, cancels when the victim dies or leaves melee range, and commits damage only after the disclosed deadline; rejected commits retain the same windup.\n  - Still required: Roblox Studio mesh import/canonical swap, effects, audio, bounded cosmetic variants, and representative horde performance evidence.',
)
replace_once(
    "docs/specifications/visual-placeholder-inventory.md",
    'server-authored behavior/life/attack/hit disclosure and local roaming, pursuit, threat-ready, confirmed strike/recovery, hit, stand-down, and death poses',
    'server-authored behavior/life/windup/attack/hit disclosure and local roaming, pursuit, threat-ready, early/late windup, confirmed strike/recovery, hit, stand-down, and death poses',
)
replace_once(
    "docs/specifications/visual-placeholder-inventory.md",
    'Server-confirmed active-strike/recovery and hit pose cues exist; anticipation, authored particles, impact effects, and production audio remain missing',
    'Cancelable server-owned windup plus confirmed active-strike/recovery and hit pose cues exist; authored particles, impact effects, and production audio remain missing',
)
replace_once(
    "docs/specifications/visual-placeholder-inventory.md",
    'Keep VIS-0103 honest by adding a server-confirmed attack presentation fact before any strike/recovery animation, or move to the evidence-independent operative/class silhouette slice while Studio import and horde performance review remain pending.',
    'Complete VIS-0103 with Studio import/readability evidence, authored attack effects/audio, and representative horde performance review; otherwise move to the evidence-independent operative/class silhouette slice.',
)

# The apply workflow and this script are temporary and must not enter the PR diff.
Path(".github/scripts/apply_exclusion_walker_windup.py").unlink()
Path(".github/workflows/exclusion-walker-windup-apply.yml").unlink()
