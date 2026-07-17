--!strict

-- Narrow runtime adapter between Roblox-facing service facts and the pure
-- P5-0104 domain module. Keeping this translation explicit prevents the
-- lifecycle owner from duplicating deterministic rules.

local Domain = require(script.Parent.Parent.Domain.EnemyDomain)

local Adapter = {}

function Adapter.evaluateSpawn(facts: any): string?
	local minimumDistance: number? = nil
	if facts.tooCloseToLivingOperative then
		minimumDistance = 0
	end
	local accepted, rejection = Domain.validateSpawnFacts({
		serviceRunning = facts.started == true,
		definitionValid = facts.definitionValid == true,
		duplicateEntityId = facts.duplicateEntityId == true,
		activeEnemyCount = facts.activeCount or 0,
		insidePlayableBounds = facts.insidePlayableBounds == true,
		minimumLivingOperativeDistance = minimumDistance,
		visibleToLivingOperative = facts.visibleToLivingOperative == true,
		spawnVolumeBlocked = facts.blockedSpawnVolume == true,
		creationSucceeded = true,
	})
	return if accepted then nil else rejection
end

function Adapter.selectTarget(
	currentTargetEntityId: string?,
	candidates: { any },
	_acquisitionRadiusStuds: number,
	_targetLossRadiusStuds: number
): string?
	local domainCandidates = {}
	local enemyPosition = { x = 0, y = 0, z = 0 }
	for _, candidate in candidates do
		table.insert(domainCandidates, {
			entityId = candidate.operativeEntityId,
			position = { x = candidate.distanceStuds, y = 0, z = 0 },
			lifeStateId = if candidate.isAlive then "Alive" else "Dead",
		})
	end
	return Domain.selectTarget(enemyPosition, currentTargetEntityId, domainCandidates)
end

function Adapter.applyDamage(
	snapshot: any,
	correlationId: string,
	damage: number,
	serverTimestamp: number,
	processedDamageCorrelations: { [string]: boolean }
): any
	local didCommit, rejectionReasonId, nextState = Domain.applyAuthorizedDamage({
		lifecycleStateId = snapshot.lifecycleStateId,
		health = snapshot.health,
		revision = snapshot.revision,
		processedCorrelations = processedDamageCorrelations,
	}, correlationId, damage, nil)
	if not didCommit then
		return { didCommit = false, rejectionReasonId = rejectionReasonId, snapshot = nil }
	end
	local died = nextState.lifecycleStateId == "Dead"
	return {
		didCommit = true,
		rejectionReasonId = nil,
		snapshot = {
			entityId = snapshot.entityId,
			archetypeId = snapshot.archetypeId,
			lifecycleStateId = nextState.lifecycleStateId,
			activityStateId = if died then nil else snapshot.activityStateId,
			health = nextState.health,
			selectedOperativeEntityId = if died then nil else snapshot.selectedOperativeEntityId,
			spawnServerTimestamp = snapshot.spawnServerTimestamp,
			lastAttackServerTimestamp = snapshot.lastAttackServerTimestamp,
			cleanupDeadlineServerTimestamp = if died then serverTimestamp + 5 else nil,
			revision = nextState.revision,
		},
	}
end

return table.freeze(Adapter)
