--!strict

--[[
	Wave 2 reusable encounter runtime facade. It composes bounded deterministic
	spawn plans, submits them through EnemyDirectorService's existing authoritative
	spawn boundary, and tracks completion by exact entity IDs.

	It intentionally owns no heartbeat, dungeon lifecycle, rewards, or global
	pressure stand-down. Agent 5 may run multiple encounters simultaneously and
	poll only the encounter it owns.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local EnemyEncounterComposer = require(script.Parent.EnemyEncounterComposer)
local EnemyDirectorService = require(script.Parent.EnemyDirectorService)
local EnemyArchetypeRuntimeBridge = require(script.Parent.EnemyArchetypeRuntimeBridge)

export type EncounterStartResult = {
	didStart: boolean,
	encounterId: string?,
	plannedCount: number,
	acceptedCount: number,
	deferredCount: number,
	compositionIdentity: string?,
	rejectionReasonId: string?,
}

export type EncounterRead = {
	encounterId: string,
	compositionIdentity: string?,
	plannedCount: number,
	acceptedCount: number,
	aliveCount: number,
	completionReported: boolean,
	cancelled: boolean,
}

type EncounterSession = {
	encounterId: string,
	compositionIdentity: string?,
	trackedEntityIds: { [string]: boolean },
	plannedCount: number,
	acceptedCount: number,
	sawTrackedEntity: boolean,
	completionReported: boolean,
	cancelled: boolean,
}

type DirectorLike = {
	spawnEnemy: (request: any) -> any,
	readEnemyCombatFacts: () -> { any },
}

type ComposerLike = {
	compose: (config: any, spawnPoints: { any }, context: any) -> any,
}

type BridgeLike = {
	install: ((director: any) -> boolean)?,
	registerSpawn: (request: any) -> boolean,
	unregisterSpawn: (entityId: string) -> boolean,
}

local EnemyEncounterService = {}
EnemyEncounterService.__index = EnemyEncounterService

local function invalidStart(reasonId: string): EncounterStartResult
	return table.freeze({
		didStart = false,
		encounterId = nil,
		plannedCount = 0,
		acceptedCount = 0,
		deferredCount = 0,
		compositionIdentity = nil,
		rejectionReasonId = reasonId,
	})
end

function EnemyEncounterService.new(
	directorOverride: DirectorLike?,
	composerOverride: ComposerLike?,
	bridgeOverride: BridgeLike?
)
	local director = directorOverride or (EnemyDirectorService :: any)
	local bridge: BridgeLike? = bridgeOverride
	if bridge == nil and directorOverride == nil then
		bridge = EnemyArchetypeRuntimeBridge :: any
		local install = bridge.install
		if install == nil or install(director) ~= true then
			error("EnemyEncounterService could not install the archetype runtime bridge")
		end
	end
	local self = setmetatable({
		director = director,
		composer = composerOverride or (EnemyEncounterComposer :: any),
		bridge = bridge,
		sessions = {} :: { [string]: EncounterSession },
		destroyed = false,
	}, EnemyEncounterService)
	return self
end

function EnemyEncounterService:spawnEncounter(config: any, spawnPoints: { any }, context: any): EncounterStartResult
	if self.destroyed then
		return invalidStart("ServiceDestroyed")
	end
	if type(config) ~= "table" or type(config.Id) ~= "string" or config.Id == "" then
		return invalidStart("InvalidEncounterDefinition")
	end
	if self.sessions[config.Id] ~= nil then
		return invalidStart("EncounterAlreadyTracked")
	end

	local plan = self.composer.compose(config, spawnPoints, context)
	if type(plan) ~= "table" or plan.isValid ~= true or type(plan.spawns) ~= "table" or #plan.spawns == 0 then
		return invalidStart(
			if type(plan) == "table" then plan.rejectionReasonId or "InvalidComposition" else "InvalidComposition"
		)
	end

	local tracked = {}
	local acceptedCount = 0
	local deferredCount = 0
	local permanentRejectionReason: string? = nil
	for _, planned in plan.spawns do
		local request = {
			entityId = planned.entityId,
			archetypeId = planned.archetypeId,
			spawnSourceId = EnemyContracts.EnemySpawnSourceIds.AuthoredWave,
			displayName = planned.displayName,
			position = planned.position,
			isHordePulse = false,
			hordeRoleId = nil,
			encounterId = config.Id,
			compositionIdentity = plan.compositionIdentity,
			eliteChance = planned.eliteChance,
			requestedEliteAffixId = planned.requestedEliteAffixId,
		}
		local bridge = self.bridge
		if bridge ~= nil and not bridge.registerSpawn(request) then
			if permanentRejectionReason == nil then
				permanentRejectionReason = "RuntimeRegistrationRejected"
			end
			continue
		end

		local result = self.director.spawnEnemy(request)
		if result.didSpawn == true or result.wasDeferred == true then
			tracked[planned.entityId] = true
			acceptedCount += 1
			if result.wasDeferred == true then
				deferredCount += 1
			end
		else
			if bridge ~= nil then
				bridge.unregisterSpawn(planned.entityId)
			end
			if permanentRejectionReason == nil then
				permanentRejectionReason = result.rejectionReasonId or "SpawnRejected"
			end
		end
	end

	if acceptedCount == 0 then
		return table.freeze({
			didStart = false,
			encounterId = nil,
			plannedCount = #plan.spawns,
			acceptedCount = 0,
			deferredCount = 0,
			compositionIdentity = plan.compositionIdentity,
			rejectionReasonId = permanentRejectionReason or "NoSpawnsAccepted",
		})
	end

	self.sessions[config.Id] = {
		encounterId = config.Id,
		compositionIdentity = plan.compositionIdentity,
		trackedEntityIds = tracked,
		plannedCount = #plan.spawns,
		acceptedCount = acceptedCount,
		sawTrackedEntity = false,
		completionReported = false,
		cancelled = false,
	}

	return table.freeze({
		didStart = true,
		encounterId = config.Id,
		plannedCount = #plan.spawns,
		acceptedCount = acceptedCount,
		deferredCount = deferredCount,
		compositionIdentity = plan.compositionIdentity,
		rejectionReasonId = if acceptedCount < #plan.spawns
			then permanentRejectionReason or "CompositionDrift"
			else nil,
	})
end

local function aliveTrackedCount(session: EncounterSession, facts: { any }): number
	local aliveCount = 0
	for _, fact in facts do
		if
			type(fact) == "table"
			and type(fact.entityId) == "string"
			and session.trackedEntityIds[fact.entityId] == true
			and fact.isAlive == true
		then
			aliveCount += 1
		end
	end
	return aliveCount
end

function EnemyEncounterService:pollCompletion(encounterId: string): (boolean, string)
	if self.destroyed then
		return false, "ServiceDestroyed"
	end
	if type(encounterId) ~= "string" or encounterId == "" then
		return false, "InvalidEncounterId"
	end
	local session = self.sessions[encounterId]
	if session == nil then
		return false, "UnknownEncounter"
	end
	if session.cancelled then
		return false, "EncounterCancelled"
	end
	if session.completionReported then
		return false, "CompletionAlreadyReported"
	end
	local facts = self.director.readEnemyCombatFacts()
	if type(facts) ~= "table" then
		return false, "InvalidDirectorFacts"
	end
	local aliveCount = aliveTrackedCount(session, facts)
	if aliveCount > 0 then
		session.sawTrackedEntity = true
		return false, "EncounterInProgress"
	end
	if not session.sawTrackedEntity then
		return false, "AwaitingTrackedSpawn"
	end
	session.completionReported = true
	return true, encounterId
end

function EnemyEncounterService:readEncounter(encounterId: string): EncounterRead?
	if self.destroyed or type(encounterId) ~= "string" then
		return nil
	end
	local session = self.sessions[encounterId]
	if session == nil then
		return nil
	end
	local facts = self.director.readEnemyCombatFacts()
	local aliveCount = if type(facts) == "table" then aliveTrackedCount(session, facts) else 0
	return table.freeze({
		encounterId = session.encounterId,
		compositionIdentity = session.compositionIdentity,
		plannedCount = session.plannedCount,
		acceptedCount = session.acceptedCount,
		aliveCount = aliveCount,
		completionReported = session.completionReported,
		cancelled = session.cancelled,
	})
end

function EnemyEncounterService:cancelEncounter(encounterId: string): boolean
	if self.destroyed or type(encounterId) ~= "string" or encounterId == "" then
		return false
	end
	local session = self.sessions[encounterId]
	if session == nil or session.cancelled then
		return false
	end
	session.cancelled = true
	return true
end

function EnemyEncounterService:releaseEncounter(encounterId: string): boolean
	if self.destroyed or type(encounterId) ~= "string" or encounterId == "" then
		return false
	end
	if self.sessions[encounterId] == nil then
		return false
	end
	self.sessions[encounterId] = nil
	return true
end

function EnemyEncounterService:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	table.clear(self.sessions)
end

return table.freeze(EnemyEncounterService)
