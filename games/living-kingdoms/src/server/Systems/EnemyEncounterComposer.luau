--!strict

--[[
	Wave 2 pure encounter composer. Converts a server-authored encounter request,
	seed, and safe spawn-point set into a deterministic bounded spawn plan.

	RequiredCounts express exact tactical anchors (for example one Brute plus two
	Runners). Remaining budget is filled by weighted eligible archetypes. No
	Roblox instances, remotes, timers, or runtime combat state are touched here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyArchetypeConfig = require(ReplicatedStorage.Shared.Config.EnemyArchetypeConfig)

export type SpawnPoint = {
	x: number,
	y: number,
	z: number,
}

export type EncounterConfig = {
	Id: string,
	Budget: number,
	MinimumCount: number?,
	MaximumCount: number?,
	ArchetypeIds: { string }?,
	RequiredCounts: { [string]: number }?,
	SpawnWeights: { [string]: number }?,
	EliteChance: number?,
	RequestedEliteAffixId: string?,
	DifficultyMultiplier: number?,
}

export type EncounterContext = {
	Seed: number,
	CompositionIdentity: string?,
}

export type PlannedSpawn = {
	entityId: string,
	archetypeId: string,
	displayName: string,
	position: SpawnPoint,
	spawnCost: number,
	eliteChance: number,
	requestedEliteAffixId: string?,
}

export type ComposeResult = {
	isValid: boolean,
	rejectionReasonId: string?,
	usedBudget: number,
	effectiveBudget: number,
	compositionIdentity: string?,
	spawns: { PlannedSpawn },
}

local EnemyEncounterComposer = {}

local function finiteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function nonemptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function validSpawnPoint(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local point = value :: any
	return finiteNumber(point.x) and finiteNumber(point.y) and finiteNumber(point.z)
end

local function invalid(reasonId: string): ComposeResult
	return table.freeze({
		isValid = false,
		rejectionReasonId = reasonId,
		usedBudget = 0,
		effectiveBudget = 0,
		compositionIdentity = nil,
		spawns = table.freeze({}),
	})
end

local function stableHash(text: string): number
	local hash = 2166136261
	for index = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, index))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

local function deterministicFraction(seed: number, salt: string): number
	local normalizedSeed = math.floor(seed)
	local hash = stableHash(tostring(normalizedSeed) .. ":" .. salt)
	return (hash % 1000000) / 1000000
end

local function readAllowedArchetypes(config: EncounterConfig): ({ string }?, string?)
	local source = config.ArchetypeIds or EnemyArchetypeConfig.EncounterArchetypeIds
	if type(source) ~= "table" or #source == 0 then
		return nil, "NoEligibleArchetypes"
	end
	local result = {}
	local seen = {}
	for _, archetypeId in source do
		if
			not nonemptyString(archetypeId)
			or seen[archetypeId] == true
			or not EnemyArchetypeConfig.isEncounterEligible(archetypeId)
		then
			return nil, "InvalidArchetypeRestriction"
		end
		seen[archetypeId] = true
		table.insert(result, archetypeId)
	end
	return result, nil
end

local function validateOverrides(config: EncounterConfig, allowedSet: { [string]: boolean }): string?
	local required = config.RequiredCounts
	if required ~= nil then
		if type(required) ~= "table" then
			return "InvalidRequiredCounts"
		end
		for archetypeId, count in required do
			if
				not nonemptyString(archetypeId)
				or allowedSet[archetypeId] ~= true
				or not finiteNumber(count)
				or count < 0
				or count % 1 ~= 0
			then
				return "InvalidRequiredCounts"
			end
		end
	end
	local weights = config.SpawnWeights
	if weights ~= nil then
		if type(weights) ~= "table" then
			return "InvalidSpawnWeights"
		end
		for archetypeId, weight in weights do
			if
				not nonemptyString(archetypeId)
				or allowedSet[archetypeId] ~= true
				or not finiteNumber(weight)
				or weight <= 0
			then
				return "InvalidSpawnWeights"
			end
		end
	end
	return nil
end

local function chooseWeighted(
	allowedIds: { string },
	remainingBudget: number,
	weights: { [string]: number }?,
	seed: number,
	salt: string
): string?
	local feasible = {}
	local totalWeight = 0
	for _, archetypeId in allowedIds do
		local definition = EnemyArchetypeConfig.get(archetypeId)
		if definition ~= nil and definition.SpawnCost <= remainingBudget then
			local weight = if weights ~= nil and weights[archetypeId] ~= nil
				then weights[archetypeId]
				else definition.EncounterWeight
			if weight > 0 then
				totalWeight += weight
				table.insert(feasible, { archetypeId = archetypeId, cumulativeWeight = totalWeight })
			end
		end
	end
	if #feasible == 0 or totalWeight <= 0 then
		return nil
	end
	local roll = deterministicFraction(seed, salt) * totalWeight
	for _, candidate in feasible do
		if roll < candidate.cumulativeWeight then
			return candidate.archetypeId
		end
	end
	return feasible[#feasible].archetypeId
end

function EnemyEncounterComposer.compose(
	config: EncounterConfig,
	spawnPoints: { SpawnPoint },
	context: EncounterContext
): ComposeResult
	if
		type(config) ~= "table"
		or not nonemptyString(config.Id)
		or not finiteNumber(config.Budget)
		or config.Budget <= 0
		or type(spawnPoints) ~= "table"
		or #spawnPoints == 0
		or type(context) ~= "table"
		or not finiteNumber(context.Seed)
		or (context.CompositionIdentity ~= nil and not nonemptyString(context.CompositionIdentity))
	then
		return invalid("InvalidEncounterDefinition")
	end
	for _, point in spawnPoints do
		if not validSpawnPoint(point) then
			return invalid("InvalidSpawnPoint")
		end
	end

	local minimumCount = config.MinimumCount or 1
	local maximumCount = config.MaximumCount or #spawnPoints
	if
		not finiteNumber(minimumCount)
		or minimumCount < 0
		or minimumCount % 1 ~= 0
		or not finiteNumber(maximumCount)
		or maximumCount < minimumCount
		or maximumCount % 1 ~= 0
		or maximumCount <= 0
		or minimumCount > #spawnPoints
	then
		return invalid("InvalidCountBounds")
	end
	maximumCount = math.min(maximumCount, #spawnPoints)

	local difficultyMultiplier = config.DifficultyMultiplier or 1
	if not finiteNumber(difficultyMultiplier) or difficultyMultiplier <= 0 or difficultyMultiplier > 4 then
		return invalid("InvalidDifficultyMultiplier")
	end
	local effectiveBudget = math.max(1, math.floor(config.Budget * difficultyMultiplier + 0.5))

	local eliteChance = config.EliteChance or 0
	if not finiteNumber(eliteChance) or eliteChance < 0 or eliteChance > 1 then
		return invalid("InvalidEliteChance")
	end
	if config.RequestedEliteAffixId ~= nil and not nonemptyString(config.RequestedEliteAffixId) then
		return invalid("InvalidEliteAffix")
	end

	local allowedIds, allowedReason = readAllowedArchetypes(config)
	if allowedIds == nil then
		return invalid(allowedReason or "NoEligibleArchetypes")
	end
	local allowedSet = {}
	for _, archetypeId in allowedIds do
		allowedSet[archetypeId] = true
	end
	local overrideReason = validateOverrides(config, allowedSet)
	if overrideReason ~= nil then
		return invalid(overrideReason)
	end

	local requiredCountTotal = 0
	local requiredBudget = 0
	for _, archetypeId in allowedIds do
		local count = if config.RequiredCounts == nil then 0 else config.RequiredCounts[archetypeId] or 0
		local definition = EnemyArchetypeConfig.get(archetypeId)
		assert(definition ~= nil, "eligible encounter archetype must have a definition")
		requiredCountTotal += count
		requiredBudget += definition.SpawnCost * count
	end
	if requiredCountTotal > maximumCount then
		return invalid("RequiredCountExceedsMaximum")
	end
	if requiredBudget > effectiveBudget then
		return invalid("RequiredCountExceedsBudget")
	end
	if requiredCountTotal > #spawnPoints then
		return invalid("RequiredCountExceedsSpawnPoints")
	end

	local spawns = {}
	local usedBudget = 0
	local spawnIndex = 0
	local function appendSpawn(archetypeId: string)
		local definition = EnemyArchetypeConfig.get(archetypeId)
		assert(definition ~= nil, "planned encounter archetype must exist")
		spawnIndex += 1
		usedBudget += definition.SpawnCost
		local point = spawnPoints[spawnIndex]
		local authoredEliteChance = if definition.EliteEligible then eliteChance else 0
		table.insert(
			spawns,
			table.freeze({
				entityId = string.format("encounter:%s:%d:%d", config.Id, math.floor(context.Seed), spawnIndex),
				archetypeId = archetypeId,
				displayName = definition.DisplayName,
				position = table.freeze({ x = point.x, y = point.y, z = point.z }),
				spawnCost = definition.SpawnCost,
				eliteChance = authoredEliteChance,
				requestedEliteAffixId = if definition.EliteEligible then config.RequestedEliteAffixId else nil,
			})
		)
	end

	-- Exact requested anchors are emitted in the caller's allowed-archetype order,
	-- making the plan stable without relying on Lua table iteration order.
	for _, archetypeId in allowedIds do
		local count = if config.RequiredCounts == nil then 0 else config.RequiredCounts[archetypeId] or 0
		for _ = 1, count do
			appendSpawn(archetypeId)
		end
	end

	while spawnIndex < maximumCount do
		local remainingBudget = effectiveBudget - usedBudget
		local nextId = chooseWeighted(
			allowedIds,
			remainingBudget,
			config.SpawnWeights,
			context.Seed,
			config.Id .. ":fill:" .. tostring(spawnIndex + 1)
		)
		if nextId == nil then
			break
		end
		appendSpawn(nextId)
	end

	if #spawns < minimumCount then
		return invalid("MinimumCountUnsatisfied")
	end
	return table.freeze({
		isValid = true,
		rejectionReasonId = nil,
		usedBudget = usedBudget,
		effectiveBudget = effectiveBudget,
		compositionIdentity = context.CompositionIdentity or config.Id,
		spawns = table.freeze(spawns),
	})
end

return table.freeze(EnemyEncounterComposer)
