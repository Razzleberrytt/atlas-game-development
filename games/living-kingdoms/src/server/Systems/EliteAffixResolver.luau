--!strict

--[[
	RPG-0105 pure elite assignment and modifier resolver. The server supplies
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

local function stableRoll(entityId: string): number
	local resolution = RunRpgConfig.EliteAssignmentPlanning.deterministicRollResolution
	local hash = 2166136261
	for index = 1, #entityId do
		hash = bit32.bxor(hash, string.byte(entityId, index))
		hash = (hash * 16777619) % 4294967296
	end
	return hash % resolution
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
	if stableRoll(facts.entityId) >= threshold then
		return neutral()
	end
	local runtime = RunRpgConfig.FrenziedRuntime
	return table.freeze({
		affixId = RunRpgContracts.EliteAffixIds.Frenzied,
		movementSpeedMultiplier = runtime.movementSpeedMultiplier,
		attackCadenceMultiplier = runtime.attackCadenceMultiplier,
		maximumHealthMultiplier = runtime.maximumHealthMultiplier,
		bonusFieldXp = runtime.bonusFieldXp,
	})
end

return table.freeze(EliteAffixResolver)
