--!strict

-- Pure deterministic stat aggregation. Every gameplay system should consume
-- resolved stats (or provide modifiers) through this contract rather than
-- inventing its own modifier order.

local Resolver = {}

export type StatModifier = {
	SourceId: string,
	SourceCategory: string,
	StatId: string,
	Operation: string,
	Value: number,
	Priority: number?,
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function hasValue(dictionary: any, value: any): boolean
	if type(dictionary) ~= "table" then
		return false
	end
	for _, candidate in dictionary do
		if candidate == value then
			return true
		end
	end
	return false
end

function Resolver.isKnownStat(statId: any, config: any): boolean
	return type(statId) == "string" and type(config) == "table" and type(config.Stats) == "table" and type(config.Stats[statId]) == "table"
end

function Resolver.validateModifier(modifier: any, config: any): (boolean, string?)
	if type(modifier) ~= "table" then
		return false, "InvalidModifier"
	end
	if type(modifier.SourceId) ~= "string" or modifier.SourceId == "" then
		return false, "InvalidSourceId"
	end
	if not hasValue(config.SourceCategories, modifier.SourceCategory) then
		return false, "InvalidSourceCategory"
	end
	if not Resolver.isKnownStat(modifier.StatId, config) then
		return false, "InvalidStatId"
	end
	if not hasValue(config.OperationIds, modifier.Operation) then
		return false, "InvalidOperation"
	end
	if not isFiniteNumber(modifier.Value) then
		return false, "InvalidValue"
	end
	if modifier.Priority ~= nil and not isFiniteNumber(modifier.Priority) then
		return false, "InvalidPriority"
	end
	return true, nil
end

local function stableLess(left: StatModifier, right: StatModifier): boolean
	local leftPriority = left.Priority or 0
	local rightPriority = right.Priority or 0
	if leftPriority ~= rightPriority then
		return leftPriority < rightPriority
	end
	if left.SourceCategory ~= right.SourceCategory then
		return left.SourceCategory < right.SourceCategory
	end
	if left.SourceId ~= right.SourceId then
		return left.SourceId < right.SourceId
	end
	if left.Operation ~= right.Operation then
		return left.Operation < right.Operation
	end
	if left.Value ~= right.Value then
		return left.Value < right.Value
	end
	return left.StatId < right.StatId
end

local function clamp(value: number, minimumValue: number, maximumValue: number): number
	return math.max(minimumValue, math.min(maximumValue, value))
end

function Resolver.resolveStat(statId: any, modifiers: any, config: any): number?
	if not Resolver.isKnownStat(statId, config) then
		return nil
	end
	if modifiers ~= nil and type(modifiers) ~= "table" then
		return nil
	end

	local definition = config.Stats[statId]
	if not isFiniteNumber(definition.BaseValue)
		or not isFiniteNumber(definition.MinimumValue)
		or not isFiniteNumber(definition.MaximumValue)
		or definition.MinimumValue > definition.MaximumValue
	then
		return nil
	end

	local relevant: { StatModifier } = {}
	for _, modifier in modifiers or {} do
		local valid = Resolver.validateModifier(modifier, config)
		if not valid then
			return nil
		end
		if modifier.StatId == statId then
			table.insert(relevant, modifier)
		end
	end
	table.sort(relevant, stableLess)

	local additive = 0
	local multiplicative = 1
	for _, modifier in relevant do
		if modifier.Operation == config.OperationIds.Add then
			additive += modifier.Value
		elseif modifier.Operation == config.OperationIds.Multiply then
			multiplicative *= modifier.Value
		end
	end

	local resolved = (definition.BaseValue + additive) * multiplicative
	if not isFiniteNumber(resolved) then
		return nil
	end
	return clamp(resolved, definition.MinimumValue, definition.MaximumValue)
end

function Resolver.resolveAll(modifiers: any, config: any): { [string]: number }?
	if type(config) ~= "table" or type(config.Stats) ~= "table" then
		return nil
	end

	local resolved = {}
	for statId in config.Stats do
		local value = Resolver.resolveStat(statId, modifiers, config)
		if value == nil then
			return nil
		end
		resolved[statId] = value
	end
	return resolved
end

return table.freeze(Resolver)
