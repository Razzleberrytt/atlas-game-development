--!strict

--[[
	P9-0101 pure Blight Spitter decision logic. Deterministic, side-effect free,
	loop free (no yielding), Roblox-service free, and randomness free: the caller
	supplies server-owned facts and a monotonic server timestamp, and receives an
	area-denial ability decision without input mutation, raycasts, or randomness.

	`resolveBehavior` drives the Corrosive Bloom lifecycle — densest-cluster
	targeting, legal charge use, cooldown, death/stand-down inertness, and the
	commit burst against every Alive operative in the impact radius. `resolveLingeringDamage`
	derives one tick of the short-lived pool the commit leaves behind. The runtime
	director (P9-0102) owns state commits, movement, telegraph disclosure, the
	pool lifetime, and the P3 damage commits.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpecialEnemyConfig = require(ReplicatedStorage.Shared.Config.SpecialEnemyConfig)
local SpecialEnemyContracts = require(ReplicatedStorage.Shared.Combat.SpecialEnemyContracts)

type EnemyWorldPosition = SpecialEnemyContracts.EnemyWorldPosition
type EnemyOperativeFact = SpecialEnemyContracts.EnemyOperativeFact
type AuthoritativeEnemyAttack = SpecialEnemyContracts.AuthoritativeEnemyAttack
type LingeringBloomZone = SpecialEnemyContracts.LingeringBloomZone
type SpecialEnemyBehaviorFacts = SpecialEnemyContracts.SpecialEnemyBehaviorFacts
type SpecialEnemyBehaviorDecision = SpecialEnemyContracts.SpecialEnemyBehaviorDecision
type LingeringDamageResolution = SpecialEnemyContracts.LingeringDamageResolution

local BehaviorStateIds = SpecialEnemyContracts.SpecialEnemyBehaviorStateIds
local AbilityActionIds = SpecialEnemyContracts.SpecialAbilityActionIds
local RejectionReasonIds = SpecialEnemyContracts.SpecialEnemyBehaviorRejectionReasonIds

local SpecialEnemyBehaviorResolver = {}

local EMPTY_IMPACTS: { AuthoritativeEnemyAttack } = table.freeze({})

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

local function copyPosition(position: EnemyWorldPosition): EnemyWorldPosition
	return table.freeze({ x = position.x, y = position.y, z = position.z }) :: EnemyWorldPosition
end

local function decision(
	behaviorStateIdAfter: string,
	anchorOperativeEntityId: string?,
	bloomActionId: string,
	bloomTargetPosition: EnemyWorldPosition?,
	shouldCommitBloom: boolean,
	bloomImpacts: { AuthoritativeEnemyAttack },
	lingeringZone: LingeringBloomZone?,
	rejectionReasonId: string?
): SpecialEnemyBehaviorDecision
	return table.freeze({
		behaviorStateIdAfter = behaviorStateIdAfter,
		anchorOperativeEntityId = anchorOperativeEntityId,
		bloomActionId = bloomActionId,
		bloomTargetPosition = bloomTargetPosition,
		shouldCommitBloom = shouldCommitBloom,
		bloomImpacts = bloomImpacts,
		lingeringZone = lingeringZone,
		rejectionReasonId = rejectionReasonId,
	}) :: SpecialEnemyBehaviorDecision
end

local function invalidFactsDecision(): SpecialEnemyBehaviorDecision
	return decision(
		BehaviorStateIds.Roaming,
		nil,
		AbilityActionIds.None,
		nil,
		false,
		EMPTY_IMPACTS,
		nil,
		RejectionReasonIds.InvalidFacts
	)
end

-- One validated Alive operative, precomputed for cluster and impact math.
type AliveOperative = {
	id: string,
	position: EnemyWorldPosition,
	distanceSquaredFromEnemy: number,
}

local function collectAliveOperatives(
	operatives: { EnemyOperativeFact },
	enemyPosition: EnemyWorldPosition
): { AliveOperative }
	local aliveOperatives: { AliveOperative } = {}
	for _, operative in operatives do
		if
			type(operative) ~= "table"
			or not isNonemptyString(operative.operativeEntityId)
			or operative.isAlive ~= true
			or not isWorldPosition(operative.position)
		then
			continue
		end
		table.insert(aliveOperatives, {
			id = operative.operativeEntityId,
			position = operative.position,
			distanceSquaredFromEnemy = horizontalDistanceSquared(enemyPosition, operative.position),
		})
	end
	return aliveOperatives
end

local function impactsAgainst(
	aliveOperatives: { AliveOperative },
	sourceEntityId: string,
	center: EnemyWorldPosition,
	radiusSquared: number,
	damageAmount: number,
	eventPrefix: string,
	eventSuffix: string,
	serverTimestamp: number
): { AuthoritativeEnemyAttack }
	local impacts: { AuthoritativeEnemyAttack } = {}
	for _, operative in aliveOperatives do
		if horizontalDistanceSquared(center, operative.position) <= radiusSquared then
			table.insert(
				impacts,
				table.freeze({
					damageEventId = eventPrefix .. sourceEntityId .. ":" .. operative.id .. ":" .. eventSuffix,
					sourceEntityId = sourceEntityId,
					targetEntityId = operative.id,
					damageAmount = damageAmount,
					serverTimestamp = serverTimestamp,
				}) :: AuthoritativeEnemyAttack
			)
		end
	end
	return table.freeze(impacts)
end

function SpecialEnemyBehaviorResolver.resolveBehavior(
	enemy: SpecialEnemyBehaviorFacts,
	operatives: { EnemyOperativeFact },
	serverTimestamp: number
): SpecialEnemyBehaviorDecision
	if
		type(enemy) ~= "table"
		or not isNonemptyString(enemy.entityId)
		or not isKnownValue(BehaviorStateIds :: any, enemy.behaviorStateId)
		or not isWorldPosition(enemy.position)
		or (enemy.anchorOperativeEntityId ~= nil and not isNonemptyString(enemy.anchorOperativeEntityId))
		or type(operatives) ~= "table"
	then
		return invalidFactsDecision()
	end
	if not isFiniteTimestamp(serverTimestamp) then
		return decision(
			enemy.behaviorStateId,
			nil,
			AbilityActionIds.None,
			nil,
			false,
			EMPTY_IMPACTS,
			nil,
			RejectionReasonIds.InvalidTimestamp
		)
	end

	local lastCommit = enemy.lastBloomCommitServerTimestamp
	if lastCommit ~= nil and (not isFiniteTimestamp(lastCommit) or (lastCommit :: number) > serverTimestamp) then
		return invalidFactsDecision()
	end

	local chargeTarget = enemy.bloomChargeTargetPosition
	local chargeStartedAt = enemy.bloomChargeStartedServerTimestamp
	local hasChargeTarget = chargeTarget ~= nil
	local hasChargeTimestamp = chargeStartedAt ~= nil
	local hasCharge = hasChargeTarget and hasChargeTimestamp
	if
		hasChargeTarget ~= hasChargeTimestamp
		or (hasChargeTarget and not isWorldPosition(chargeTarget))
		or (hasChargeTimestamp and (not isFiniteTimestamp(chargeStartedAt) or (chargeStartedAt :: number) > serverTimestamp))
		or ((enemy.behaviorStateId == BehaviorStateIds.Charging) ~= hasCharge)
	then
		return invalidFactsDecision()
	end

	if enemy.behaviorStateId == BehaviorStateIds.Dead then
		return decision(
			BehaviorStateIds.Dead,
			nil,
			if hasCharge then AbilityActionIds.Cancel else AbilityActionIds.None,
			nil,
			false,
			EMPTY_IMPACTS,
			nil,
			nil
		)
	end
	if enemy.behaviorStateId == BehaviorStateIds.StandDown then
		return decision(
			BehaviorStateIds.StandDown,
			nil,
			if hasCharge then AbilityActionIds.Cancel else AbilityActionIds.None,
			nil,
			false,
			EMPTY_IMPACTS,
			nil,
			nil
		)
	end

	local config = SpecialEnemyConfig
	local aliveOperatives = collectAliveOperatives(operatives, enemy.position)

	-- A committed charge lands on its locked position regardless of where the
	-- squad moved: killing the Spitter is the only interrupt (handled above).
	if hasCharge then
		local startedAt = chargeStartedAt :: number
		local center = chargeTarget :: EnemyWorldPosition
		local commitAt = startedAt + config.Bloom.ChargeWindupSeconds
		if serverTimestamp < commitAt then
			return decision(
				BehaviorStateIds.Charging,
				enemy.anchorOperativeEntityId,
				AbilityActionIds.Continue,
				copyPosition(center),
				false,
				EMPTY_IMPACTS,
				nil,
				nil
			)
		end
		local impacts = impactsAgainst(
			aliveOperatives,
			enemy.entityId,
			center,
			config.Bloom.ImpactRadiusStuds * config.Bloom.ImpactRadiusStuds,
			config.Bloom.ImpactDamage,
			"spitterbloom:",
			tostring(startedAt),
			serverTimestamp
		)
		local lingering = config.Bloom.Lingering
		local lingeringZone: LingeringBloomZone = table.freeze({
			zoneId = "spitterzone:" .. enemy.entityId .. ":" .. tostring(startedAt),
			sourceEntityId = enemy.entityId,
			centerPosition = copyPosition(center),
			radiusStuds = config.Bloom.ImpactRadiusStuds,
			tickDamage = lingering.TickDamage,
			tickIntervalSeconds = lingering.TickIntervalSeconds,
			lifetimeSeconds = lingering.LifetimeSeconds,
			committedServerTimestamp = serverTimestamp,
			lastTickServerTimestamp = nil,
		})
		return decision(
			BehaviorStateIds.Recovering,
			enemy.anchorOperativeEntityId,
			AbilityActionIds.Commit,
			copyPosition(center),
			true,
			impacts,
			lingeringZone,
			nil
		)
	end

	-- Not charging: pick the densest cluster's anchor among Alive operatives in
	-- detection. The anchor is the operative catching the most neighbors inside
	-- the cluster radius; exact ties break to the lexically smallest entity ID.
	local detectionSquared = config.BlightSpitter.DetectionRadiusStuds * config.BlightSpitter.DetectionRadiusStuds
	local engagementSquared = config.BlightSpitter.BloomEngagementRangeStuds
		* config.BlightSpitter.BloomEngagementRangeStuds
	local clusterSquared = config.Bloom.ClusterRadiusStuds * config.Bloom.ClusterRadiusStuds

	local anchorId: string? = nil
	local anchorPosition: EnemyWorldPosition? = nil
	local anchorDistanceSquared = math.huge
	local anchorClusterCount = -1
	for _, candidate in aliveOperatives do
		if candidate.distanceSquaredFromEnemy > detectionSquared then
			continue
		end
		local clusterCount = 0
		for _, other in aliveOperatives do
			if horizontalDistanceSquared(candidate.position, other.position) <= clusterSquared then
				clusterCount += 1
			end
		end
		if
			anchorId == nil
			or clusterCount > anchorClusterCount
			or (clusterCount == anchorClusterCount and candidate.id < anchorId)
		then
			anchorId = candidate.id
			anchorPosition = candidate.position
			anchorDistanceSquared = candidate.distanceSquaredFromEnemy
			anchorClusterCount = clusterCount
		end
	end

	if anchorId == nil then
		return decision(BehaviorStateIds.Roaming, nil, AbilityActionIds.None, nil, false, EMPTY_IMPACTS, nil, nil)
	end
	if anchorDistanceSquared > engagementSquared then
		return decision(
			BehaviorStateIds.Approaching,
			anchorId,
			AbilityActionIds.None,
			nil,
			false,
			EMPTY_IMPACTS,
			nil,
			nil
		)
	end

	local cooldownElapsed = lastCommit == nil
		or serverTimestamp >= (lastCommit :: number) + config.Bloom.CooldownSeconds
	if not cooldownElapsed then
		return decision(
			BehaviorStateIds.Recovering,
			anchorId,
			AbilityActionIds.None,
			nil,
			false,
			EMPTY_IMPACTS,
			nil,
			nil
		)
	end
	return decision(
		BehaviorStateIds.Charging,
		anchorId,
		AbilityActionIds.Begin,
		copyPosition(anchorPosition :: EnemyWorldPosition),
		false,
		EMPTY_IMPACTS,
		nil,
		nil
	)
end

local function lingeringResolution(
	isActive: boolean,
	ticked: boolean,
	impacts: { AuthoritativeEnemyAttack },
	tickServerTimestamp: number?,
	rejectionReasonId: string?
): LingeringDamageResolution
	return table.freeze({
		isActive = isActive,
		ticked = ticked,
		impacts = impacts,
		tickServerTimestamp = tickServerTimestamp,
		rejectionReasonId = rejectionReasonId,
	}) :: LingeringDamageResolution
end

function SpecialEnemyBehaviorResolver.resolveLingeringDamage(
	zone: LingeringBloomZone,
	operatives: { EnemyOperativeFact },
	serverTimestamp: number
): LingeringDamageResolution
	if
		type(zone) ~= "table"
		or not isNonemptyString(zone.zoneId)
		or not isNonemptyString(zone.sourceEntityId)
		or not isWorldPosition(zone.centerPosition)
		or not isFiniteNumber(zone.radiusStuds)
		or zone.radiusStuds <= 0
		or not isFiniteNumber(zone.tickDamage)
		or zone.tickDamage <= 0
		or not isFiniteNumber(zone.tickIntervalSeconds)
		or zone.tickIntervalSeconds <= 0
		or not isFiniteNumber(zone.lifetimeSeconds)
		or zone.lifetimeSeconds <= 0
		or not isFiniteTimestamp(zone.committedServerTimestamp)
		or type(operatives) ~= "table"
	then
		return lingeringResolution(false, false, EMPTY_IMPACTS, nil, RejectionReasonIds.InvalidFacts)
	end
	local lastTick = zone.lastTickServerTimestamp
	if
		lastTick ~= nil and (not isFiniteTimestamp(lastTick) or (lastTick :: number) < zone.committedServerTimestamp)
	then
		return lingeringResolution(false, false, EMPTY_IMPACTS, nil, RejectionReasonIds.InvalidFacts)
	end
	if not isFiniteTimestamp(serverTimestamp) or serverTimestamp < zone.committedServerTimestamp then
		return lingeringResolution(false, false, EMPTY_IMPACTS, nil, RejectionReasonIds.InvalidTimestamp)
	end
	if lastTick ~= nil and (lastTick :: number) > serverTimestamp then
		return lingeringResolution(false, false, EMPTY_IMPACTS, nil, RejectionReasonIds.InvalidTimestamp)
	end

	if serverTimestamp >= zone.committedServerTimestamp + zone.lifetimeSeconds then
		return lingeringResolution(false, false, EMPTY_IMPACTS, nil, nil)
	end
	local previousTick = if lastTick ~= nil then lastTick :: number else zone.committedServerTimestamp
	if serverTimestamp < previousTick + zone.tickIntervalSeconds then
		return lingeringResolution(true, false, EMPTY_IMPACTS, nil, nil)
	end

	local aliveOperatives = collectAliveOperatives(operatives, zone.centerPosition)
	local impacts = impactsAgainst(
		aliveOperatives,
		zone.sourceEntityId,
		zone.centerPosition,
		zone.radiusStuds * zone.radiusStuds,
		zone.tickDamage,
		"spitterlinger:",
		tostring(serverTimestamp),
		serverTimestamp
	)
	return lingeringResolution(true, true, impacts, serverTimestamp, nil)
end

return table.freeze(SpecialEnemyBehaviorResolver)
