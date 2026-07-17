--!strict

--[[
	P5-0104 shared production-enemy vocabulary. The server owns every enemy
	identity, lifecycle transition, activity transition, health fact, target,
	attack, and removal. These contracts are server-domain shapes; they do not
	create a client authority path.
]]

export type EnemyArchetypeId = "Shambler"
export type EnemyLifecycleStateId = "Spawning" | "Active" | "Dead" | "Removed"
export type EnemyActivityStateId = "Idle" | "Pursuing" | "Attacking"

export type AuthoredVector3 = {
	x: number,
	y: number,
	z: number,
}

export type EnemySpawnDefinition = {
	entityId: string,
	archetypeId: EnemyArchetypeId,
	position: AuthoredVector3,
	facingDirection: AuthoredVector3?,
	correlationId: string,
}

export type EnemySnapshot = {
	entityId: string,
	archetypeId: EnemyArchetypeId,
	lifecycleStateId: EnemyLifecycleStateId,
	activityStateId: EnemyActivityStateId?,
	health: number,
	selectedOperativeEntityId: string?,
	spawnServerTimestamp: number,
	lastAttackServerTimestamp: number?,
	cleanupDeadlineServerTimestamp: number?,
	revision: number,
}

local EnemyContracts = {}

EnemyContracts.ArchetypeIds = table.freeze({
	Shambler = "Shambler" :: "Shambler",
})

EnemyContracts.LifecycleStateIds = table.freeze({
	Spawning = "Spawning" :: "Spawning",
	Active = "Active" :: "Active",
	Dead = "Dead" :: "Dead",
	Removed = "Removed" :: "Removed",
})

EnemyContracts.ActivityStateIds = table.freeze({
	Idle = "Idle" :: "Idle",
	Pursuing = "Pursuing" :: "Pursuing",
	Attacking = "Attacking" :: "Attacking",
})

EnemyContracts.SpawnRejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidDefinition = "InvalidDefinition",
	DuplicateEntityId = "DuplicateEntityId",
	CapacityExceeded = "CapacityExceeded",
	OutsidePlayableBounds = "OutsidePlayableBounds",
	TooCloseToLivingOperative = "TooCloseToLivingOperative",
	VisibleToLivingOperative = "VisibleToLivingOperative",
	BlockedSpawnVolume = "BlockedSpawnVolume",
	CreationFailed = "CreationFailed",
})

EnemyContracts.DamageRejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidRequest = "InvalidRequest",
	UnknownEnemy = "UnknownEnemy",
	InvalidLifecycleState = "InvalidLifecycleState",
	StaleRevision = "StaleRevision",
	DuplicateCorrelation = "DuplicateCorrelation",
})

EnemyContracts.LegalLifecycleTransitions = table.freeze({
	Spawning = table.freeze({ Active = true, Removed = true }),
	Active = table.freeze({ Dead = true }),
	Dead = table.freeze({ Removed = true }),
	Removed = table.freeze({}),
})

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0 and (value :: number) % 1 == 0
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

function EnemyContracts.validateAuthoredVector3(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local vector = value :: { [string]: unknown }
	return isFiniteNumber(vector.x) and isFiniteNumber(vector.y) and isFiniteNumber(vector.z)
end

function EnemyContracts.validateSpawnDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [string]: unknown }
	if not isNonEmptyString(definition.entityId) then
		return false
	end
	if not isNonEmptyString(definition.archetypeId) then
		return false
	end
	if EnemyContracts.ArchetypeIds[definition.archetypeId :: string] == nil then
		return false
	end
	if not EnemyContracts.validateAuthoredVector3(definition.position) then
		return false
	end
	if definition.facingDirection ~= nil and not EnemyContracts.validateAuthoredVector3(definition.facingDirection) then
		return false
	end
	return isNonEmptyString(definition.correlationId)
end

function EnemyContracts.isLegalLifecycleTransition(fromState: unknown, toState: unknown): boolean
	if type(fromState) ~= "string" or type(toState) ~= "string" then
		return false
	end
	local transitions = EnemyContracts.LegalLifecycleTransitions[fromState]
	return transitions ~= nil and transitions[toState] == true
end

function EnemyContracts.validateSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: { [string]: unknown }
	if not isNonEmptyString(snapshot.entityId) then
		return false
	end
	if
		not isNonEmptyString(snapshot.archetypeId)
		or EnemyContracts.ArchetypeIds[snapshot.archetypeId :: string] == nil
	then
		return false
	end
	if
		not isNonEmptyString(snapshot.lifecycleStateId)
		or EnemyContracts.LifecycleStateIds[snapshot.lifecycleStateId :: string] == nil
	then
		return false
	end
	local lifecycleStateId = snapshot.lifecycleStateId :: string
	if lifecycleStateId == EnemyContracts.LifecycleStateIds.Active then
		if
			not isNonEmptyString(snapshot.activityStateId)
			or EnemyContracts.ActivityStateIds[snapshot.activityStateId :: string] == nil
		then
			return false
		end
	elseif snapshot.activityStateId ~= nil then
		return false
	end
	if not isFiniteNumber(snapshot.health) or (snapshot.health :: number) < 0 then
		return false
	end
	if snapshot.selectedOperativeEntityId ~= nil and not isNonEmptyString(snapshot.selectedOperativeEntityId) then
		return false
	end
	if not isFiniteNumber(snapshot.spawnServerTimestamp) or (snapshot.spawnServerTimestamp :: number) < 0 then
		return false
	end
	if
		snapshot.lastAttackServerTimestamp ~= nil
		and (
			not isFiniteNumber(snapshot.lastAttackServerTimestamp)
			or (snapshot.lastAttackServerTimestamp :: number) < 0
		)
	then
		return false
	end
	if
		snapshot.cleanupDeadlineServerTimestamp ~= nil
		and (
			not isFiniteNumber(snapshot.cleanupDeadlineServerTimestamp)
			or (snapshot.cleanupDeadlineServerTimestamp :: number) < 0
		)
	then
		return false
	end
	return isNonNegativeInteger(snapshot.revision)
end

return table.freeze(EnemyContracts)
