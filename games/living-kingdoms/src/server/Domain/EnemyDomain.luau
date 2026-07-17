--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyContracts = require(ReplicatedStorage.Shared.Enemy.EnemyContracts)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)

export type Position3 = {
	x: number,
	y: number,
	z: number,
}

export type OperativeCandidate = {
	entityId: string,
	position: Position3,
	lifeStateId: string,
}

export type SpawnFacts = {
	serviceRunning: boolean,
	definitionValid: boolean,
	duplicateEntityId: boolean,
	activeEnemyCount: number,
	insidePlayableBounds: boolean,
	minimumLivingOperativeDistance: number?,
	visibleToLivingOperative: boolean,
	spawnVolumeBlocked: boolean,
	creationSucceeded: boolean,
}

export type EnemyDamageState = {
	lifecycleStateId: string,
	health: number,
	revision: number,
	processedCorrelations: { [string]: boolean },
}

local EnemyDomain = {}

local function distanceSquared(a: Position3, b: Position3): number
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	return dx * dx + dy * dy + dz * dz
end

function EnemyDomain.validateSpawnFacts(facts: SpawnFacts): (boolean, string?)
	if not facts.serviceRunning then
		return false, EnemyContracts.SpawnRejectionReasonIds.ServiceStopped
	end
	if not facts.definitionValid then
		return false, EnemyContracts.SpawnRejectionReasonIds.InvalidDefinition
	end
	if facts.duplicateEntityId then
		return false, EnemyContracts.SpawnRejectionReasonIds.DuplicateEntityId
	end
	if facts.activeEnemyCount >= EnemyConfig.MaximumActiveEnemies then
		return false, EnemyContracts.SpawnRejectionReasonIds.CapacityExceeded
	end
	if not facts.insidePlayableBounds then
		return false, EnemyContracts.SpawnRejectionReasonIds.OutsidePlayableBounds
	end
	if
		facts.minimumLivingOperativeDistance ~= nil
		and facts.minimumLivingOperativeDistance < EnemyConfig.MinimumFairSpawnDistanceStuds
	then
		return false, EnemyContracts.SpawnRejectionReasonIds.TooCloseToLivingOperative
	end
	if facts.visibleToLivingOperative then
		return false, EnemyContracts.SpawnRejectionReasonIds.VisibleToLivingOperative
	end
	if facts.spawnVolumeBlocked then
		return false, EnemyContracts.SpawnRejectionReasonIds.BlockedSpawnVolume
	end
	if not facts.creationSucceeded then
		return false, EnemyContracts.SpawnRejectionReasonIds.CreationFailed
	end
	return true, nil
end

function EnemyDomain.selectTarget(
	enemyPosition: Position3,
	currentTargetEntityId: string?,
	candidates: { OperativeCandidate }
): string?
	local acquisitionRadiusSquared = EnemyConfig.AcquisitionRadiusStuds * EnemyConfig.AcquisitionRadiusStuds
	local targetLossRadiusSquared = EnemyConfig.TargetLossRadiusStuds * EnemyConfig.TargetLossRadiusStuds

	if currentTargetEntityId ~= nil then
		for _, candidate in candidates do
			if
				candidate.entityId == currentTargetEntityId
				and candidate.lifeStateId == "Alive"
				and distanceSquared(enemyPosition, candidate.position) <= targetLossRadiusSquared
			then
				return currentTargetEntityId
			end
		end
	end

	local selectedEntityId: string? = nil
	local selectedDistanceSquared = math.huge
	for _, candidate in candidates do
		if candidate.lifeStateId == "Alive" then
			local candidateDistanceSquared = distanceSquared(enemyPosition, candidate.position)
			if candidateDistanceSquared <= acquisitionRadiusSquared then
				if
					candidateDistanceSquared < selectedDistanceSquared
					or (
						candidateDistanceSquared == selectedDistanceSquared
						and (selectedEntityId == nil or candidate.entityId < selectedEntityId)
					)
				then
					selectedDistanceSquared = candidateDistanceSquared
					selectedEntityId = candidate.entityId
				end
			end
		end
	end
	return selectedEntityId
end

function EnemyDomain.applyAuthorizedDamage(
	state: EnemyDamageState,
	correlationId: string,
	damage: number,
	expectedRevision: number?
): (boolean, string?, EnemyDamageState)
	if
		type(correlationId) ~= "string"
		or correlationId == ""
		or type(damage) ~= "number"
		or damage <= 0
		or damage ~= damage
	then
		return false, EnemyContracts.DamageRejectionReasonIds.InvalidRequest, state
	end
	if state.lifecycleStateId ~= EnemyContracts.LifecycleStateIds.Active then
		return false, EnemyContracts.DamageRejectionReasonIds.InvalidLifecycleState, state
	end
	if expectedRevision ~= nil and expectedRevision ~= state.revision then
		return false, EnemyContracts.DamageRejectionReasonIds.StaleRevision, state
	end
	if state.processedCorrelations[correlationId] then
		return false, EnemyContracts.DamageRejectionReasonIds.DuplicateCorrelation, state
	end

	local processedCorrelations = table.clone(state.processedCorrelations)
	processedCorrelations[correlationId] = true
	local nextHealth = math.max(0, state.health - damage)
	local nextLifecycleStateId = if nextHealth == 0
		then EnemyContracts.LifecycleStateIds.Dead
		else EnemyContracts.LifecycleStateIds.Active
	local nextState: EnemyDamageState = {
		lifecycleStateId = nextLifecycleStateId,
		health = nextHealth,
		revision = state.revision + 1,
		processedCorrelations = processedCorrelations,
	}
	return true, nil, nextState
end

function EnemyDomain.isAttackReady(
	enemyPosition: Position3,
	targetPosition: Position3,
	lastAttackServerTimestamp: number?,
	serverTimestamp: number,
	contactBlocked: boolean
): boolean
	if contactBlocked then
		return false
	end
	if distanceSquared(enemyPosition, targetPosition) > EnemyConfig.AttackRangeStuds * EnemyConfig.AttackRangeStuds then
		return false
	end
	if lastAttackServerTimestamp == nil then
		return true
	end
	return serverTimestamp >= lastAttackServerTimestamp + EnemyConfig.AttackCadenceSeconds
end

return table.freeze(EnemyDomain)
