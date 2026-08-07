--!strict

--[[
	RPG-0106 pure elite assignment and modifier resolver. The server supplies
	spawn identity, source, elapsed operation time, and the retained elite
	population. A stable entity-ID hash replaces client-influenceable randomness,
	so retries resolve identically and can never reroll an elite.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)

local EliteAffixResolver = {}

export type AssignmentFacts = {
	entityId: string,
	spawnSourceId: string,
	operationElapsedSeconds: number,
	activeEliteCount: number,
	isBoss: boolean,
	isHordePulse: boolean,
	hordeRoleId: string,
}

export type Assignment = {
	affixId: string?,
	movementSpeedMultiplier: number,
	attackCadenceMultiplier: number,
	maximumHealthMultiplier: number,
	bonusFieldXp: number,
}

local function neutral(): Assignment
	return table.freeze({
		affixId = nil,
		movementSpeedMultiplier = 1,
		attackCadenceMultiplier = 1,
		maximumHealthMultiplier = 1,
		bonusFieldXp = 0,
	})
end

local AffixIds = RunRpgContracts.EliteAffixIds
local ORDERED_AFFIX_IDS = table.freeze({
	AffixIds.Armored,
	AffixIds.Frenzied,
	AffixIds.Regenerator,
	AffixIds.Volatile,
	AffixIds.Commander,
})

local function stableRoll(entityId: string, salt: string): number
	local resolution = RunRpgConfig.EliteAssignmentPlanning.deterministicRollResolution
	local hash = 2166136261
	local value = entityId .. ":" .. salt
	for index = 1, #value do
		hash = bit32.bxor(hash, string.byte(value, index))
		hash = (hash * 16777619) % 4294967296
	end
	return hash % resolution
end

local function isCompatible(affixId: string, hordeRoleId: string): boolean
	local runtime = RunRpgConfig.EliteAffixRuntimeById[affixId]
	if runtime == nil then
		return false
	end
	for _, compatibleRoleId in runtime.compatibleHordeRoleIds do
		if compatibleRoleId == hordeRoleId then
			return true
		end
	end
	return false
end

function EliteAffixResolver.readCompatibleAffixIds(hordeRoleId: unknown): { string }
	if type(hordeRoleId) ~= "string" or hordeRoleId == "" then
		return table.freeze({})
	end
	local result = {}
	for _, affixId in ORDERED_AFFIX_IDS do
		if isCompatible(affixId, hordeRoleId) then
			table.insert(result, affixId)
		end
	end
	return table.freeze(result)
end

function EliteAffixResolver.resolveAssignment(facts: AssignmentFacts): Assignment
	if
		type(facts) ~= "table"
		or type(facts.entityId) ~= "string"
		or facts.entityId == ""
		or type(facts.spawnSourceId) ~= "string"
		or (facts.spawnSourceId ~= EnemyContracts.EnemySpawnSourceIds.AuthoredWave and facts.spawnSourceId ~= EnemyContracts.EnemySpawnSourceIds.RoamingPressure)
		or type(facts.operationElapsedSeconds) ~= "number"
		or facts.operationElapsedSeconds ~= facts.operationElapsedSeconds
		or type(facts.activeEliteCount) ~= "number"
		or facts.activeEliteCount % 1 ~= 0
		or type(facts.isHordePulse) ~= "boolean"
		or type(facts.hordeRoleId) ~= "string"
		or facts.hordeRoleId == ""
	then
		return neutral()
	end
	local planning = RunRpgConfig.EliteAssignmentPlanning
	if
		not planning.isRuntimeEnabled
		or facts.isBoss
		or facts.operationElapsedSeconds < planning.protectedOpeningSeconds
		or facts.activeEliteCount < 0
		or facts.activeEliteCount >= RunRpgConfig.Limits.maximumSimultaneousElites
	then
		return neutral()
	end
	local probability = if facts.isHordePulse
		then planning.hordePulseProbability
		else planning.ordinaryPressureProbability
	local threshold = math.floor(probability * planning.deterministicRollResolution)
	if stableRoll(facts.entityId, "elite") >= threshold then
		return neutral()
	end
	local compatibleAffixIds = EliteAffixResolver.readCompatibleAffixIds(facts.hordeRoleId)
	if #compatibleAffixIds == 0 then
		return neutral()
	end
	local affixRoll = stableRoll(facts.entityId, "affix")
	local affixId = compatibleAffixIds[(affixRoll % #compatibleAffixIds) + 1]
	local runtime = RunRpgConfig.EliteAffixRuntimeById[affixId]
	local movementSpeedMultiplier = runtime.movementSpeedMultiplier or 1
	local attackCadenceMultiplier = runtime.attackCadenceMultiplier or 1
	local maximumHealthMultiplier = runtime.maximumHealthMultiplier or 1
	return table.freeze({
		affixId = affixId,
		movementSpeedMultiplier = movementSpeedMultiplier,
		attackCadenceMultiplier = attackCadenceMultiplier,
		maximumHealthMultiplier = maximumHealthMultiplier,
		bonusFieldXp = runtime.bonusFieldXp,
	})
end

return table.freeze(EliteAffixResolver)
