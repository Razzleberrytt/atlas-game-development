--!strict

local Contracts = require(script.Parent.EquipmentAffixContracts)

local ReasonIds = Contracts.ReasonIds

local MODULUS = 2_147_483_647
local MULTIPLIER = 48_271

local Resolver = {}

local function nextSeed(seed: number): number
	return (seed * MULTIPLIER) % MODULUS
end

local function mixSeed(seed: number, text: string, salt: number): number
	local value = math.max(1, seed + salt)
	for index = 1, #text do
		value = nextSeed(value + string.byte(text, index) + salt + index)
	end
	return math.max(1, value)
end

local function contains(list: { string }, value: string): boolean
	for _, entry in list do
		if entry == value then
			return true
		end
	end
	return false
end

local function hasRequiredTags(itemTags: { string }, requiredTags: { string }): boolean
	for _, tag in requiredTags do
		if not contains(itemTags, tag) then
			return false
		end
	end
	return true
end

local function reject(reasonId: string)
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		Affixes = table.freeze({}),
		Signature = "affix-v1:none",
	})
end

local function validateConfig(config: any): boolean
	if type(config) ~= "table" or type(config.Version) ~= "string" then
		return false
	end
	if type(config.Definitions) ~= "table" or type(config.AffixCountByRarity) ~= "table" then
		return false
	end
	local seen = {}
	for _, definition in config.Definitions do
		if
			type(definition) ~= "table"
			or type(definition.Id) ~= "string"
			or type(definition.Version) ~= "string"
			or type(definition.DisplayName) ~= "string"
			or type(definition.EffectId) ~= "string"
			or type(definition.MinimumValue) ~= "number"
			or type(definition.MaximumValue) ~= "number"
			or definition.MinimumValue % 1 ~= 0
			or definition.MaximumValue % 1 ~= 0
			or definition.MinimumValue <= 0
			or definition.MaximumValue < definition.MinimumValue
			or type(definition.AllowedSlots) ~= "table"
			or #definition.AllowedSlots < 1
			or type(definition.RequiredTags) ~= "table"
			or seen[definition.Id] == true
		then
			return false
		end
		seen[definition.Id] = true
	end
	for rarityId, count in config.AffixCountByRarity do
		if
			type(rarityId) ~= "string"
			or type(count) ~= "number"
			or count % 1 ~= 0
			or count < 0
			or count > 3
		then
			return false
		end
	end
	return true
end

local function validateContext(context: any): boolean
	if type(context) ~= "table" then
		return false
	end
	return type(context.DefinitionId) == "string"
		and type(context.Slot) == "string"
		and type(context.Rarity) == "string"
		and type(context.Tags) == "table"
		and type(context.Seed) == "number"
		and context.Seed % 1 == 0
		and context.Seed >= 1
		and context.Seed < MODULUS
end

local function copyEligible(config: any, context: any): { any }
	local eligible = {}
	for _, definition in config.Definitions do
		if contains(definition.AllowedSlots, context.Slot) and hasRequiredTags(context.Tags, definition.RequiredTags) then
			table.insert(eligible, definition)
		end
	end
	table.sort(eligible, function(left, right)
		return left.Id < right.Id
	end)
	return eligible
end

local function copyRoll(definition: any, value: number)
	return table.freeze({
		Id = definition.Id,
		Version = definition.Version,
		DisplayName = definition.DisplayName,
		EffectId = definition.EffectId,
		Value = value,
	})
end

function Resolver.resolve(config: any, context: any)
	if not validateConfig(config) then
		return reject(ReasonIds.InvalidConfig)
	end
	if not validateContext(context) then
		return reject(ReasonIds.InvalidContext)
	end

	local targetCount = config.AffixCountByRarity[context.Rarity]
	if type(targetCount) ~= "number" then
		return reject(ReasonIds.InvalidContext)
	end
	if targetCount == 0 then
		return table.freeze({
			Accepted = true,
			ReasonId = ReasonIds.Resolved,
			Affixes = table.freeze({}),
			Signature = "affix-v1:none",
		})
	end

	local eligible = copyEligible(config, context)
	if #eligible < targetCount then
		return reject(ReasonIds.InsufficientEligibleAffixes)
	end

	local selected = {}
	local selectionSeed = mixSeed(context.Seed, context.DefinitionId .. "|" .. context.Rarity, 97)
	for selectionIndex = 1, targetCount do
		selectionSeed = nextSeed(selectionSeed + selectionIndex * 131)
		local choiceIndex = (selectionSeed % #eligible) + 1
		local definition = table.remove(eligible, choiceIndex)
		local valueSeed = mixSeed(context.Seed, definition.Id, 193 + selectionIndex)
		local value = definition.MinimumValue + (valueSeed % (definition.MaximumValue - definition.MinimumValue + 1))
		table.insert(selected, copyRoll(definition, value))
	end

	table.sort(selected, function(left, right)
		return left.Id < right.Id
	end)
	local signatureParts = { "affix-v1" }
	for _, roll in selected do
		table.insert(signatureParts, string.format("%s@%s=%d", roll.Id, roll.Version, roll.Value))
	end

	return table.freeze({
		Accepted = true,
		ReasonId = ReasonIds.Resolved,
		Affixes = table.freeze(selected),
		Signature = table.concat(signatureParts, "|"),
	})
end

return table.freeze(Resolver)
