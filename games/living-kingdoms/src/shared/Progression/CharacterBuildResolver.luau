--!strict

-- Pure build/reward math. Persistence and remotes remain server-owned; this
-- module only answers what a level has earned and how allocated attributes map
-- into canonical stat modifiers.

local Resolver = {}

export type CharacterBuildState = {
	Version: string,
	AllocatedAttributes: { [string]: number },
	RecoveredState: boolean,
	RecoveryReasonId: string?,
}

export type LevelRewardSummary = {
	FromLevel: number,
	ToLevel: number,
	LevelsCrossed: number,
	AttributePointsAwarded: number,
	PerkPointsAwarded: number,
	TotalEarnedAttributePoints: number,
	TotalEarnedPerkPoints: number,
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isInteger(value: any): boolean
	return isFiniteNumber(value) and value % 1 == 0
end

local function validConfig(config: any): boolean
	return type(config) == "table"
		and type(config.Version) == "string"
		and type(config.Attributes) == "table"
		and type(config.Rewards) == "table"
		and isInteger(config.Rewards.AttributePointsPerLevel)
		and config.Rewards.AttributePointsPerLevel >= 0
		and isInteger(config.Rewards.MaximumEarnedAttributePoints)
		and config.Rewards.MaximumEarnedAttributePoints >= 0
		and isInteger(config.Rewards.PerkPointInterval)
		and config.Rewards.PerkPointInterval > 0
		and isInteger(config.Rewards.MaximumEarnedPerkPoints)
		and config.Rewards.MaximumEarnedPerkPoints >= 0
end

local function sortedAttributeIds(config: any): { string }
	local ids = {}
	for attributeId in config.Attributes do
		table.insert(ids, attributeId)
	end
	table.sort(ids)
	return ids
end

local function emptyAllocations(config: any): { [string]: number }
	local allocations = {}
	for attributeId in config.Attributes do
		allocations[attributeId] = 0
	end
	return allocations
end

local function cloneAllocations(allocations: { [string]: number }): { [string]: number }
	local clone = {}
	for attributeId, points in allocations do
		clone[attributeId] = points
	end
	return clone
end

function Resolver.defaultState(config: any): CharacterBuildState?
	if not validConfig(config) then
		return nil
	end
	return {
		Version = config.Version,
		AllocatedAttributes = emptyAllocations(config),
		RecoveredState = false,
		RecoveryReasonId = nil,
	}
end

function Resolver.normalizeState(rawState: any, config: any): CharacterBuildState?
	local defaultState = Resolver.defaultState(config)
	if defaultState == nil then
		return nil
	end
	if rawState == nil then
		return defaultState
	end
	if type(rawState) ~= "table" or type(rawState.AllocatedAttributes) ~= "table" then
		defaultState.RecoveredState = true
		defaultState.RecoveryReasonId = "InvalidBuildState"
		return defaultState
	end

	local allocations = emptyAllocations(config)
	local recovered = rawState.Version ~= config.Version
	local reasonId = if recovered then "VersionNormalized" else nil
	for attributeId, definition in config.Attributes do
		local points = rawState.AllocatedAttributes[attributeId]
		if points == nil then
			points = 0
		end
		if not isInteger(points) or points < 0 or points > definition.MaximumAllocatedPoints then
			points = 0
			recovered = true
			reasonId = "InvalidAllocation"
		end
		allocations[attributeId] = points
	end

	return {
		Version = config.Version,
		AllocatedAttributes = allocations,
		RecoveredState = recovered,
		RecoveryReasonId = reasonId,
	}
end

function Resolver.totalEarnedAttributePoints(level: any, config: any): number?
	if not validConfig(config) or not isInteger(level) or level < 1 then
		return nil
	end
	return math.min((level - 1) * config.Rewards.AttributePointsPerLevel, config.Rewards.MaximumEarnedAttributePoints)
end

function Resolver.totalEarnedPerkPoints(level: any, config: any): number?
	if not validConfig(config) or not isInteger(level) or level < 1 then
		return nil
	end
	return math.min(math.floor((level - 1) / config.Rewards.PerkPointInterval), config.Rewards.MaximumEarnedPerkPoints)
end

function Resolver.summarizeLevelRewards(fromLevel: any, toLevel: any, config: any): LevelRewardSummary?
	if not validConfig(config)
		or not isInteger(fromLevel)
		or not isInteger(toLevel)
		or fromLevel < 1
		or toLevel < fromLevel
	then
		return nil
	end

	local fromAttributes = Resolver.totalEarnedAttributePoints(fromLevel, config) :: number
	local toAttributes = Resolver.totalEarnedAttributePoints(toLevel, config) :: number
	local fromPerks = Resolver.totalEarnedPerkPoints(fromLevel, config) :: number
	local toPerks = Resolver.totalEarnedPerkPoints(toLevel, config) :: number
	return {
		FromLevel = fromLevel,
		ToLevel = toLevel,
		LevelsCrossed = toLevel - fromLevel,
		AttributePointsAwarded = toAttributes - fromAttributes,
		PerkPointsAwarded = toPerks - fromPerks,
		TotalEarnedAttributePoints = toAttributes,
		TotalEarnedPerkPoints = toPerks,
	}
end

function Resolver.allocatedPointCount(state: any, config: any): number?
	local normalized = Resolver.normalizeState(state, config)
	if normalized == nil then
		return nil
	end
	local total = 0
	for _, points in normalized.AllocatedAttributes do
		total += points
	end
	return total
end

function Resolver.availableAttributePoints(state: any, level: any, config: any): number?
	local earned = Resolver.totalEarnedAttributePoints(level, config)
	local allocated = Resolver.allocatedPointCount(state, config)
	if earned == nil or allocated == nil then
		return nil
	end
	return math.max(0, earned - allocated)
end

function Resolver.allocate(state: any, level: any, attributeId: any, amount: any, config: any): any
	local normalized = Resolver.normalizeState(state, config)
	if normalized == nil then
		return { Accepted = false, ReasonId = "InvalidConfig" }
	end
	if type(attributeId) ~= "string" or config.Attributes[attributeId] == nil then
		return { Accepted = false, ReasonId = "InvalidAttribute", State = normalized }
	end
	if not isInteger(amount) or amount <= 0 then
		return { Accepted = false, ReasonId = "InvalidAmount", State = normalized }
	end
	local available = Resolver.availableAttributePoints(normalized, level, config)
	if available == nil then
		return { Accepted = false, ReasonId = "InvalidLevel", State = normalized }
	end
	if amount > available then
		return { Accepted = false, ReasonId = "InsufficientAttributePoints", State = normalized }
	end

	local definition = config.Attributes[attributeId]
	local current = normalized.AllocatedAttributes[attributeId]
	if current + amount > definition.MaximumAllocatedPoints then
		return { Accepted = false, ReasonId = "AttributeCapReached", State = normalized }
	end

	local allocations = cloneAllocations(normalized.AllocatedAttributes)
	allocations[attributeId] = current + amount
	return {
		Accepted = true,
		ReasonId = "Allocated",
		State = {
			Version = config.Version,
			AllocatedAttributes = allocations,
			RecoveredState = false,
			RecoveryReasonId = nil,
		},
		AvailableAttributePoints = available - amount,
	}
end

function Resolver.respec(state: any, level: any, config: any): any
	local normalized = Resolver.normalizeState(state, config)
	local earned = Resolver.totalEarnedAttributePoints(level, config)
	if normalized == nil or earned == nil then
		return { Accepted = false, ReasonId = "InvalidStateOrLevel" }
	end
	local refunded = Resolver.allocatedPointCount(normalized, config) :: number
	local reset = Resolver.defaultState(config) :: CharacterBuildState
	return {
		Accepted = true,
		ReasonId = "Respecced",
		State = reset,
		RefundedAttributePoints = refunded,
		AvailableAttributePoints = earned,
	}
end

function Resolver.progressionModifiers(state: any, level: any, config: any): { any }?
	local normalized = Resolver.normalizeState(state, config)
	if normalized == nil or not isInteger(level) or level < 1 then
		return nil
	end

	local modifiers = {}
	local automaticHealth = math.min(
		(level - 1) * config.Rewards.AutomaticMaxHealthPerLevel,
		config.Rewards.MaximumAutomaticMaxHealthBonus
	)
	if automaticHealth ~= 0 then
		table.insert(modifiers, {
			SourceId = "progression:auto-level",
			SourceCategory = config.SourceCategories.Progression,
			StatId = config.StatIds.MaxHealth,
			Operation = config.OperationIds.Add,
			Value = automaticHealth,
			Priority = 10,
		})
	end

	for _, attributeId in sortedAttributeIds(config) do
		local points = normalized.AllocatedAttributes[attributeId]
		if points > 0 then
			local attribute = config.Attributes[attributeId]
			for _, modifierPerPoint in attribute.ModifiersPerPoint do
				table.insert(modifiers, {
					SourceId = "progression:attribute:" .. attributeId,
					SourceCategory = config.SourceCategories.Progression,
					StatId = modifierPerPoint.StatId,
					Operation = modifierPerPoint.Operation,
					Value = modifierPerPoint.Value * points,
					Priority = 20,
				})
			end
		end
	end

	return modifiers
end

return table.freeze(Resolver)
