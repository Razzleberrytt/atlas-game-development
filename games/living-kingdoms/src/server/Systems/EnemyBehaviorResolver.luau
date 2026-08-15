--!strict

--[[
	Wave 2 pure ordinary-enemy decision logic. Deterministic and side-effect free:
	the caller supplies server-owned facts plus a monotonic timestamp and receives
	spawn legality / behavior intent. Runtime movement and damage commits remain
	owned by EnemyDirectorService.

	The dependency surface intentionally remains identical to Wave 1 so existing
	Lune fixtures and director harnesses remain valid. Encounter-authored identity
	is read from EnemyContracts' VM-local server runtime metadata registry.
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
local ArchetypeIds = EnemyContracts.EnemyArchetypeIds

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
		or (request.isHordePulse ~= nil and type(request.isHordePulse) ~= "boolean")
		or (request.hordeRoleId ~= nil and not isNonemptyString(request.hordeRoleId))
		or (request.encounterId ~= nil and not isNonemptyString(request.encounterId))
		or (request.compositionIdentity ~= nil and not isNonemptyString(request.compositionIdentity))
		or (request.eliteChance ~= nil and (not isFiniteNumber(request.eliteChance) or (request.eliteChance :: number) < 0 or (request.eliteChance :: number) > 1))
		or (request.requestedEliteAffixId ~= nil and not isNonemptyString(request.requestedEliteAffixId))
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
	local minimumDistanceSquared = EnemyConfig.FairSpawn.MinimumOperativeDistanceStuds ^ 2
	for _, alivePosition in facts.alivePositions do
		if not isWorldPosition(alivePosition) then
			return spawnResolution(SpawnRejectionReasonIds.InvalidDefinition)
		end
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

local function resolveOrdinaryArchetype(enemy: EnemyBehaviorFacts)
	local metadata = EnemyContracts.ServerRuntimeMetadataByEntityId[enemy.entityId]
	local archetypeId = enemy.archetypeId
		or (if metadata == nil then nil else metadata.archetypeId)
		or ArchetypeIds.ExclusionWalker
	return EnemyConfig.getOrdinaryArchetype(archetypeId)
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

	local archetype = resolveOrdinaryArchetype(enemy)
	if archetype == nil then
		return decision(
			BehaviorStateIds.Roaming,
			nil,
			AttackWindupActionIds.None,
			false,
			nil,
			BehaviorRejectionReasonIds.InvalidFacts
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

	local cadenceMultiplier = enemy.attackCadenceMultiplier
	if cadenceMultiplier == nil then
		cadenceMultiplier = 1
	elseif not isFiniteNumber(cadenceMultiplier) or cadenceMultiplier < 0.4 or cadenceMultiplier > 1 then
		return decision(
			BehaviorStateIds.Roaming,
			nil,
			AttackWindupActionIds.None,
			false,
			nil,
			BehaviorRejectionReasonIds.InvalidFacts
		)
	end

	local detectionSquared = archetype.DetectionRadiusStuds ^ 2
	local dropSquared = archetype.PursuitDropRadiusStuds ^ 2
	local attackRangeSquared = archetype.AttackRangeStuds ^ 2
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
			local commitAt = startedAt + archetype.AttackWindupSeconds * cadenceMultiplier
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
				damageEventId = "enemyattack:"
					.. enemy.entityId
					.. ":"
					.. (windupTargetId :: string)
					.. ":"
					.. startedAt,
				sourceEntityId = enemy.entityId,
				targetEntityId = windupTargetId :: string,
				damageAmount = archetype.AttackDamage,
				serverTimestamp = serverTimestamp,
			})
			return decision(BehaviorStateIds.WindingUp, windupTargetId, AttackWindupActionIds.Commit, true, attack, nil)
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
	local cooldownElapsed = lastAttack == nil
		or serverTimestamp >= lastAttack + archetype.AttackCooldownSeconds * cadenceMultiplier
	if not cooldownElapsed then
		return decision(BehaviorStateIds.Attacking, targetId, AttackWindupActionIds.None, false, nil, nil)
	end
	return decision(BehaviorStateIds.WindingUp, targetId, AttackWindupActionIds.Begin, false, nil, nil)
end

return table.freeze(EnemyBehaviorResolver)
