--!strict

--[[
	P5-0104 pure enemy decision logic. Deterministic, side-effect free, and
	loop free: the caller supplies server-owned facts and a monotonic server
	timestamp, and receives a spawn-legality or behavior decision without any
	input mutation, Roblox service access, raycast, or randomness. The runtime
	director owns state commits, movement, and damage application.
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

--[[
	Fair-spawn legality for one proposed enemy, in stable first-failure order:
	definition shape, duplicate identity, population cap, playable extent, and
	the fairness distance to every alive operative. The minimum distance is
	inclusive: exactly the configured distance is legal.
]]
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
	shouldAttack: boolean,
	attack: EnemyContracts.AuthoritativeEnemyAttack?,
	rejectionReasonId: string?
): EnemyBehaviorDecision
	return table.freeze({
		behaviorStateIdAfter = behaviorStateIdAfter,
		targetOperativeEntityId = targetOperativeEntityId,
		shouldAttack = shouldAttack,
		attack = attack,
		rejectionReasonId = rejectionReasonId,
	}) :: EnemyBehaviorDecision
end

--[[
	One deterministic behavior decision for one enemy. Dead and StandDown are
	inert. Otherwise the enemy retains its current target while that operative
	stays alive inside the pursuit-drop radius (hysteresis), or acquires the
	nearest alive operative inside the detection radius, breaking exact
	distance ties toward the lexically smallest operative entity ID. A target
	inside melee range makes the enemy Attacking; the swing itself is legal
	only when the cooldown has elapsed, and its damage event is derived
	entirely from the enemy identity, target identity, and the supplied server
	timestamp.
]]
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
		return decision(BehaviorStateIds.Roaming, nil, false, nil, BehaviorRejectionReasonIds.InvalidFacts)
	end
	if not isFiniteTimestamp(serverTimestamp) then
		return decision(enemy.behaviorStateId, nil, false, nil, BehaviorRejectionReasonIds.InvalidTimestamp)
	end
	if enemy.behaviorStateId == BehaviorStateIds.Dead then
		return decision(BehaviorStateIds.Dead, nil, false, nil, nil)
	end
	if enemy.behaviorStateId == BehaviorStateIds.StandDown then
		return decision(BehaviorStateIds.StandDown, nil, false, nil, nil)
	end

	local walker = EnemyConfig.Walker
	local detectionSquared = walker.DetectionRadiusStuds * walker.DetectionRadiusStuds
	local dropSquared = walker.PursuitDropRadiusStuds * walker.PursuitDropRadiusStuds

	local retainedTargetId: string? = nil
	local retainedDistanceSquared = math.huge
	local nearestTargetId: string? = nil
	local nearestDistanceSquared = math.huge
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
	if targetId == nil then
		return decision(BehaviorStateIds.Roaming, nil, false, nil, nil)
	end

	local attackRangeSquared = walker.AttackRangeStuds * walker.AttackRangeStuds
	if targetDistanceSquared > attackRangeSquared then
		return decision(BehaviorStateIds.Pursuing, targetId, false, nil, nil)
	end

	local lastAttack = enemy.lastAttackServerTimestamp
	local cooldownElapsed = lastAttack == nil or serverTimestamp >= lastAttack + walker.AttackCooldownSeconds
	if not cooldownElapsed then
		return decision(BehaviorStateIds.Attacking, targetId, false, nil, nil)
	end
	local attack: EnemyContracts.AuthoritativeEnemyAttack = table.freeze({
		damageEventId = "enemyattack:" .. enemy.entityId .. ":" .. targetId .. ":" .. serverTimestamp,
		sourceEntityId = enemy.entityId,
		targetEntityId = targetId,
		damageAmount = walker.AttackDamage,
		serverTimestamp = serverTimestamp,
	})
	return decision(BehaviorStateIds.Attacking, targetId, true, attack, nil)
end

return table.freeze(EnemyBehaviorResolver)
