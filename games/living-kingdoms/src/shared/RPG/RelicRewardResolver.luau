--!strict

--[[
	RPG-0107 pure relic reward offer resolver.

	Deterministically derives the two distinct compatible relic choices that a
	reward event offers an operative. It owns no state, performs no I/O, and
	consumes only server-supplied facts: the operation generation, the reward
	sequence, the operative's weapon-derived compatibility tags, and the set of
	relics that operative has already equipped. The same facts always produce the
	same offer, so reopening a panel or reconnecting returns the stored choice
	rather than rerolling it. Relic effect mechanics remain owned by RPG-0108.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)

export type CompatibilityIdSet = { [string]: boolean }
export type RelicIdSet = { [string]: boolean }

local CompatibilityIds = RunRpgContracts.RelicCompatibilityIds

-- Stable catalog order. The reward pool is the declared relic catalog; a relic
-- does not need an active effect to be equippable framework state.
local orderedRelics: { any } = {}
for _, definition in RunRpgConfig.RelicCatalog do
	table.insert(orderedRelics, definition)
end

local RelicRewardResolver = {}

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number" and value == value and value > 0 and value % 1 == 0
end

local function isBooleanKeyedStringSet(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, flag in value :: { [any]: any } do
		if type(key) ~= "string" or type(flag) ~= "boolean" then
			return false
		end
	end
	return true
end

-- A relic is offerable to an operative when it is universally useful, a
-- cooperative effect (never weapon-gated), or its required weapon category is
-- present in the operative's loadout.
local function isRelicCompatible(compatibilityId: string, loadoutCompatibilityIds: CompatibilityIdSet): boolean
	if compatibilityId == CompatibilityIds.Any or compatibilityId == CompatibilityIds.Cooperative then
		return true
	end
	return loadoutCompatibilityIds[compatibilityId] == true
end

--[[
	Returns a frozen array of distinct, compatible, not-yet-equipped relic IDs of
	length `Limits.relicChoiceCountPerReward` (fewer only if the compatible pool
	is smaller). Returns an empty frozen array on malformed facts so callers fail
	closed without offering anything.
]]
function RelicRewardResolver.generateChoices(
	operationGeneration: number,
	rewardSequence: number,
	loadoutCompatibilityIds: CompatibilityIdSet,
	equippedRelicIds: RelicIdSet
): { string }
	if
		not isPositiveInteger(operationGeneration)
		or not isPositiveInteger(rewardSequence)
		or not isBooleanKeyedStringSet(loadoutCompatibilityIds)
		or not isBooleanKeyedStringSet(equippedRelicIds)
	then
		return table.freeze({})
	end

	local eligible: { string } = {}
	for _, definition in orderedRelics do
		if
			not equippedRelicIds[definition.relicId]
			and isRelicCompatible(definition.compatibilityId, loadoutCompatibilityIds)
		then
			table.insert(eligible, definition.relicId)
		end
	end

	local poolSize = #eligible
	if poolSize == 0 then
		return table.freeze({})
	end

	local count = math.min(RunRpgConfig.Limits.relicChoiceCountPerReward, poolSize)
	local first = ((operationGeneration * 7 + rewardSequence * 13) % poolSize) + 1
	local stride = 1
	if poolSize > 1 then
		stride = 1 + ((operationGeneration * 3 + rewardSequence * 5) % (poolSize - 1))
	end

	local choices: { string } = {}
	local chosen: { [string]: boolean } = {}

	local function collect(indexStride: number)
		for step = 0, poolSize - 1 do
			if #choices >= count then
				return
			end
			local index = ((first - 1 + step * indexStride) % poolSize) + 1
			local relicId = eligible[index]
			if not chosen[relicId] then
				chosen[relicId] = true
				table.insert(choices, relicId)
			end
		end
	end

	-- Strided pass spreads the pair across the catalog; the linear pass
	-- guarantees `count` distinct results even when the stride and pool size
	-- share a factor and the first pass cycles early.
	collect(stride)
	if #choices < count then
		collect(1)
	end

	return table.freeze(choices)
end

return table.freeze(RelicRewardResolver)
