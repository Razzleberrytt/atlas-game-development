--!strict

--[[
	Wave 2 compatibility bridge for the Wave 1 EnemyDirectorService.

	The existing director remains the sole owner of spawn legality, authoritative
	health revisions, attacks, death, corpse cleanup, and its single heartbeat.
	This bridge installs narrow wrappers on public health/evaluation seams only for
	encounter-authored archetypes registered in EnemyContracts' VM-local runtime
	metadata table. It adds no heartbeat and no per-enemy connections.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyArchetypeConfig = require(ReplicatedStorage.Shared.Config.EnemyArchetypeConfig)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)

local AttributeNames = EnemyPresentationContracts.AttributeNames
local RuntimeMetadata = EnemyContracts.ServerRuntimeMetadataByEntityId

local Bridge = {}

local installed = false
local installedDirector: any = nil
local originalReadHealthState: any = nil
local originalCommitHealthState: any = nil
local originalEvaluateAt: any = nil
local originalStop: any = nil
local trackedIds: { [string]: boolean } = {}
local modelsByEntityId: { [string]: Model } = {}

local function nonemptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function definitionFor(entityId: string)
	local metadata = RuntimeMetadata[entityId]
	if metadata == nil then
		return nil
	end
	return EnemyArchetypeConfig.get(metadata.archetypeId)
end

local function ordinaryDefinition(entityId: string)
	local definition = definitionFor(entityId)
	if definition == nil or definition.RuntimeKind ~= "Ordinary" then
		return nil
	end
	return definition
end

local function healthScale(entityId: string): number
	local definition = ordinaryDefinition(entityId)
	if definition == nil then
		return 1
	end
	return definition.MaximumHealth / EnemyConfig.Walker.MaximumHealth
end

local function copyHealthRead(read: any, scale: number)
	if type(read) ~= "table" or scale == 1 then
		return read
	end
	return {
		revision = read.revision,
		isAlive = read.isAlive,
		maximumHealth = read.maximumHealth * scale,
		healthState = {
			entityId = read.healthState.entityId,
			currentHealth = read.healthState.currentHealth * scale,
			processedShotIds = table.clone(read.healthState.processedShotIds),
		},
	}
end

local function setOptionalAttribute(model: Model, name: string, value: any)
	model:SetAttribute(name, value)
end

local function decorateAliveModel(entityId: string, model: Model)
	local metadata = RuntimeMetadata[entityId]
	local definition = definitionFor(entityId)
	if metadata == nil or definition == nil then
		return
	end
	modelsByEntityId[entityId] = model
	setOptionalAttribute(model, "EnemyEncounterId", metadata.encounterId)
	setOptionalAttribute(model, "EnemyCompositionIdentity", metadata.compositionIdentity)
	model:SetAttribute("EnemyMovementBehaviorId", definition.MovementBehaviorId)
	model:SetAttribute("EnemyAttackBehaviorId", definition.AttackBehaviorId)
	model:SetAttribute("EnemyFactionId", definition.FactionId)
	model:SetAttribute("EnemySpawnCost", definition.SpawnCost)
	model:SetAttribute("EnemyRewardBaseFieldXp", definition.RewardMetadata.baseFieldXp)
	model:SetAttribute("EnemyRewardLootProfileId", definition.RewardMetadata.lootProfileId)
	model:SetAttribute("EnemyEliteEligible", definition.EliteEligible)
	local weakPoint = definition.WeakPoint
	setOptionalAttribute(model, "EnemyWeakPointPartName", if weakPoint == nil then nil else weakPoint.partName)
	setOptionalAttribute(model, "EnemyWeakPointDamageMultiplier", if weakPoint == nil then nil else weakPoint.damageMultiplier)
	local affixId = model:GetAttribute(AttributeNames.EliteAffixId)
	model:SetAttribute("EnemyIsElite", type(affixId) == "string" and affixId ~= "")
end

local function applyOrdinaryMovement(entityId: string, model: Model)
	local definition = ordinaryDefinition(entityId)
	if definition == nil then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local state = model:GetAttribute(AttributeNames.BehaviorStateId)
	local multiplier = model:GetAttribute(AttributeNames.EffectiveMovementSpeedMultiplier)
	if type(multiplier) ~= "number" or multiplier ~= multiplier then
		multiplier = 1
	end
	if state == "Pursuing" or state == "Attacking" then
		humanoid.WalkSpeed = definition.PursuitSpeedStudsPerSecond * multiplier
	elseif state == "Roaming" then
		humanoid.WalkSpeed = definition.RoamSpeedStudsPerSecond * multiplier
	elseif state == "WindingUp" or state == "StandDown" or state == "Dead" then
		humanoid.WalkSpeed = 0
	end

	if state == "WindingUp" then
		local startedAt = model:GetAttribute(AttributeNames.WindupStartedServerTimestamp)
		local cadence = model:GetAttribute(AttributeNames.EliteAttackCadenceMultiplier)
		if type(cadence) ~= "number" or cadence ~= cadence then
			cadence = 1
		end
		if type(startedAt) == "number" and startedAt > 0 then
			model:SetAttribute(AttributeNames.WindupCommitServerTimestamp, startedAt + definition.AttackWindupSeconds * cadence)
		end
	end
end

local function decorateDeath(entityId: string, model: Model)
	local metadata = RuntimeMetadata[entityId]
	local definition = definitionFor(entityId)
	if metadata == nil or definition == nil or metadata.deathHandled == true then
		return
	end
	local affixId = model:GetAttribute(AttributeNames.EliteAffixId)
	local bonusXp = model:GetAttribute(AttributeNames.EliteBonusFieldXp)
	if type(bonusXp) ~= "number" or bonusXp ~= bonusXp then
		bonusXp = 0
	end
	model:SetAttribute("EnemyDeathArchetypeId", metadata.archetypeId)
	model:SetAttribute("EnemyDeathIsElite", type(affixId) == "string" and affixId ~= "")
	setOptionalAttribute(model, "EnemyDeathEliteAffixId", affixId)
	setOptionalAttribute(model, "EnemyDeathEncounterId", metadata.encounterId)
	setOptionalAttribute(model, "EnemyDeathCompositionIdentity", metadata.compositionIdentity)
	setOptionalAttribute(model, "EnemyDeathKillerOperativeEntityId", metadata.lastDamagingOperativeEntityId)
	model:SetAttribute("EnemyDeathRewardBaseFieldXp", definition.RewardMetadata.baseFieldXp)
	model:SetAttribute("EnemyDeathRewardBonusFieldXp", bonusXp)
	model:SetAttribute("EnemyDeathLootProfileId", definition.RewardMetadata.lootProfileId)
	metadata.deathHandled = true
end

local function afterEvaluation()
	if installedDirector == nil then
		return
	end
	local facts = installedDirector.readEnemyCombatFacts()
	if type(facts) == "table" then
		for _, fact in facts do
			if type(fact) == "table" and nonemptyString(fact.entityId) and fact.model ~= nil then
				local entityId = fact.entityId :: string
				if trackedIds[entityId] == true and fact.model:IsA("Model") then
					decorateAliveModel(entityId, fact.model)
					applyOrdinaryMovement(entityId, fact.model)
				end
			end
		end
	end

	for entityId in trackedIds do
		local underlying = originalReadHealthState(entityId)
		if underlying == nil then
			local metadata = RuntimeMetadata[entityId]
			if metadata ~= nil and metadata.deathHandled == true then
				trackedIds[entityId] = nil
				modelsByEntityId[entityId] = nil
				RuntimeMetadata[entityId] = nil
			end
			continue
		end
		if underlying.isAlive ~= true then
			local model = modelsByEntityId[entityId]
			if model ~= nil and model.Parent ~= nil then
				decorateDeath(entityId, model)
			end
		end
	end
end

function Bridge.install(director: any): boolean
	if installed then
		return director == installedDirector
	end
	if
		type(director) ~= "table"
		or type(director.readHealthState) ~= "function"
		or type(director.commitHealthState) ~= "function"
		or type(director.evaluateAt) ~= "function"
		or type(director.readEnemyCombatFacts) ~= "function"
		or type(director.stop) ~= "function"
	then
		return false
	end

	installed = true
	installedDirector = director
	originalReadHealthState = director.readHealthState
	originalCommitHealthState = director.commitHealthState
	originalEvaluateAt = director.evaluateAt
	originalStop = director.stop

	director.readHealthState = function(entityId: string)
		local read = originalReadHealthState(entityId)
		if read == nil then
			return nil
		end
		return copyHealthRead(read, healthScale(entityId))
	end

	director.commitHealthState = function(
		entityId: string,
		expectedRevision: number,
		healthStateAfter: any,
		serverTimestamp: number,
		damagingOperativeEntityId: string?
	)
		local scale = healthScale(entityId)
		if scale == 1 then
			local didCommit, committedDamage = originalCommitHealthState(entityId, expectedRevision, healthStateAfter, serverTimestamp)
			if didCommit and nonemptyString(damagingOperativeEntityId) and RuntimeMetadata[entityId] ~= nil then
				RuntimeMetadata[entityId].lastDamagingOperativeEntityId = damagingOperativeEntityId
			end
			return didCommit, committedDamage
		end

		local underlying = originalReadHealthState(entityId)
		if
			underlying == nil
			or type(healthStateAfter) ~= "table"
			or type(healthStateAfter.currentHealth) ~= "number"
			or type(healthStateAfter.processedShotIds) ~= "table"
		then
			return false, nil
		end
		local virtualCurrent = underlying.healthState.currentHealth * scale
		local requestedDamage = virtualCurrent - healthStateAfter.currentHealth
		local translatedAfter = {
			entityId = healthStateAfter.entityId,
			currentHealth = underlying.healthState.currentHealth - requestedDamage / scale,
			processedShotIds = healthStateAfter.processedShotIds,
		}
		local didCommit, committedDamage = originalCommitHealthState(entityId, expectedRevision, translatedAfter, serverTimestamp)
		if didCommit and nonemptyString(damagingOperativeEntityId) and RuntimeMetadata[entityId] ~= nil then
			RuntimeMetadata[entityId].lastDamagingOperativeEntityId = damagingOperativeEntityId
		end
		return didCommit, if committedDamage == nil then nil else committedDamage * scale
	end

	director.evaluateAt = function(serverTimestamp: number)
		local summary = originalEvaluateAt(serverTimestamp)
		afterEvaluation()
		return summary
	end

	director.stop = function(...)
		local result = originalStop(...)
		for entityId in trackedIds do
			RuntimeMetadata[entityId] = nil
		end
		table.clear(trackedIds)
		table.clear(modelsByEntityId)
		return result
	end

	return true
end

function Bridge.registerSpawn(request: any): boolean
	if
		type(request) ~= "table"
		or not nonemptyString(request.entityId)
		or not nonemptyString(request.archetypeId)
		or RuntimeMetadata[request.entityId] ~= nil
	then
		return false
	end
	local definition = EnemyArchetypeConfig.get(request.archetypeId)
	if definition == nil then
		return false
	end
	RuntimeMetadata[request.entityId] = {
		archetypeId = request.archetypeId,
		encounterId = request.encounterId,
		compositionIdentity = request.compositionIdentity,
		eliteChance = request.eliteChance,
		requestedEliteAffixId = request.requestedEliteAffixId,
		hordeRoleId = request.hordeRoleId,
		eliteEligible = definition.EliteEligible,
		lastDamagingOperativeEntityId = nil,
		deathHandled = false,
	}
	trackedIds[request.entityId] = true
	return true
end

function Bridge.unregisterSpawn(entityId: string): boolean
	trackedIds[entityId] = nil
	modelsByEntityId[entityId] = nil
	if RuntimeMetadata[entityId] == nil then
		return false
	end
	RuntimeMetadata[entityId] = nil
	return true
end

function Bridge.noteDamagingOperative(entityId: string, operativeEntityId: string): boolean
	local metadata = RuntimeMetadata[entityId]
	if metadata == nil or not nonemptyString(operativeEntityId) then
		return false
	end
	metadata.lastDamagingOperativeEntityId = operativeEntityId
	return true
end

function Bridge.readRewardContext(entityId: string): any?
	local metadata = RuntimeMetadata[entityId]
	local definition = definitionFor(entityId)
	if metadata == nil or definition == nil then
		return nil
	end
	local model = modelsByEntityId[entityId]
	local affixId = if model == nil then nil else model:GetAttribute(AttributeNames.EliteAffixId)
	local bonusXp = if model == nil then 0 else model:GetAttribute(AttributeNames.EliteBonusFieldXp)
	if type(bonusXp) ~= "number" or bonusXp ~= bonusXp then
		bonusXp = 0
	end
	local healthRead = if installedDirector == nil then nil else installedDirector.readHealthState(entityId)
	return table.freeze({
		entityId = entityId,
		archetypeId = metadata.archetypeId,
		encounterId = metadata.encounterId,
		compositionIdentity = metadata.compositionIdentity,
		isElite = type(affixId) == "string" and affixId ~= "",
		eliteAffixId = affixId,
		baseFieldXp = definition.RewardMetadata.baseFieldXp,
		bonusFieldXp = bonusXp,
		lootProfileId = definition.RewardMetadata.lootProfileId,
		lastDamagingOperativeEntityId = metadata.lastDamagingOperativeEntityId,
		isAlive = healthRead ~= nil and healthRead.isAlive == true,
	})
end

return Bridge
