--!strict

-- Pure character-XP math. This module has no Roblox services and owns no save
-- state, which keeps curve rebalance, migration, boundary behavior, and large
-- awards deterministic and cheap to test.

local Resolver = {}

local MAX_SAFE_INTEGER = 9007199254740991

export type ProgressionConfig = {
	Version: string,
	MinimumLevel: number,
	MaximumLevel: number,
	BaseXPToNextLevel: number,
	LinearXPPerLevel: number,
	QuadraticXPPerLevelSquared: number,
}

export type CharacterProgressionState = {
	Version: string,
	Level: number,
	TotalXP: number,
	XPIntoLevel: number,
	XPRequiredForNextLevel: number,
	XPRemainingToNextLevel: number,
	IsLevelCap: boolean,
	RecoveredState: boolean,
	RecoveryReasonId: string?,
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isInteger(value: any): boolean
	return isFiniteNumber(value) and value % 1 == 0
end

local function validConfig(config: any): boolean
	if type(config) ~= "table" then
		return false
	end
	if type(config.Version) ~= "string" or config.Version == "" then
		return false
	end
	if not isInteger(config.MinimumLevel) or config.MinimumLevel ~= 1 then
		return false
	end
	if not isInteger(config.MaximumLevel) or config.MaximumLevel <= config.MinimumLevel then
		return false
	end
	if not isInteger(config.BaseXPToNextLevel) or config.BaseXPToNextLevel <= 0 then
		return false
	end
	if not isInteger(config.LinearXPPerLevel) or config.LinearXPPerLevel < 0 then
		return false
	end
	if not isInteger(config.QuadraticXPPerLevelSquared) or config.QuadraticXPPerLevelSquared < 0 then
		return false
	end

	local steps = config.MaximumLevel - config.MinimumLevel
	local total = steps * config.BaseXPToNextLevel
		+ config.LinearXPPerLevel * steps * (steps - 1) / 2
		+ config.QuadraticXPPerLevelSquared * steps * (steps - 1) * (2 * steps - 1) / 6
	return isInteger(total) and total >= 0 and total <= MAX_SAFE_INTEGER
end

local function totalXPUnchecked(level: number, config: ProgressionConfig): number
	local steps = level - config.MinimumLevel
	return steps * config.BaseXPToNextLevel
		+ config.LinearXPPerLevel * steps * (steps - 1) / 2
		+ config.QuadraticXPPerLevelSquared * steps * (steps - 1) * (2 * steps - 1) / 6
end

function Resolver.xpToNextLevel(level: any, config: any): number?
	if not validConfig(config) or not isInteger(level) then
		return nil
	end
	if level < config.MinimumLevel or level >= config.MaximumLevel then
		return nil
	end
	local n = level - config.MinimumLevel
	return config.BaseXPToNextLevel + config.LinearXPPerLevel * n + config.QuadraticXPPerLevelSquared * n * n
end

function Resolver.totalXPForLevel(level: any, config: any): number?
	if not validConfig(config) or not isInteger(level) then
		return nil
	end
	if level < config.MinimumLevel or level > config.MaximumLevel then
		return nil
	end
	return totalXPUnchecked(level, config)
end

local function levelForTotalXP(totalXP: number, config: ProgressionConfig): number
	local low = config.MinimumLevel
	local high = config.MaximumLevel
	local resolved = config.MinimumLevel

	while low <= high do
		local middle = math.floor((low + high) / 2)
		if totalXPUnchecked(middle, config) <= totalXP then
			resolved = middle
			low = middle + 1
		else
			high = middle - 1
		end
	end

	return resolved
end

local function stateFromTotalXP(
	totalXP: number,
	config: ProgressionConfig,
	recoveredState: boolean,
	recoveryReasonId: string?
): CharacterProgressionState
	local capXP = totalXPUnchecked(config.MaximumLevel, config)
	local boundedXP = math.clamp(math.floor(totalXP), 0, capXP)
	local level = levelForTotalXP(boundedXP, config)
	local levelThreshold = totalXPUnchecked(level, config)
	local isCap = level >= config.MaximumLevel
	local required = if isCap then 0 else Resolver.xpToNextLevel(level, config) :: number
	local intoLevel = if isCap then 0 else boundedXP - levelThreshold
	local remaining = if isCap then 0 else required - intoLevel

	return table.freeze({
		Version = config.Version,
		Level = level,
		TotalXP = boundedXP,
		XPIntoLevel = intoLevel,
		XPRequiredForNextLevel = required,
		XPRemainingToNextLevel = remaining,
		IsLevelCap = isCap,
		RecoveredState = recoveredState,
		RecoveryReasonId = recoveryReasonId,
	})
end

function Resolver.normalizeState(rawState: any, config: any): CharacterProgressionState
	if not validConfig(config) then
		error("invalid character progression config", 2)
	end
	local typedConfig = config :: ProgressionConfig
	if rawState == nil then
		return stateFromTotalXP(0, typedConfig, false, nil)
	end
	if type(rawState) ~= "table" then
		return stateFromTotalXP(0, typedConfig, true, "MalformedState")
	end

	for _, fieldName in { "TotalXP", "XP", "Experience", "TotalExperience" } do
		local value = rawState[fieldName]
		if value ~= nil then
			if not isFiniteNumber(value) or value < 0 then
				return stateFromTotalXP(0, typedConfig, true, "InvalidTotalXP")
			end
			return stateFromTotalXP(
				value,
				typedConfig,
				fieldName ~= "TotalXP",
				if fieldName ~= "TotalXP" then "LegacyXPField" else nil
			)
		end
	end

	-- Legacy level-only state is recoverable. We seed it at the exact threshold
	-- for that level rather than trusting any stale derived progress fields.
	local legacyLevel = rawState.Level or rawState.CharacterLevel or rawState.Rank
	if legacyLevel ~= nil then
		if not isFiniteNumber(legacyLevel) or legacyLevel < typedConfig.MinimumLevel then
			return stateFromTotalXP(0, typedConfig, true, "InvalidLegacyLevel")
		end
		local boundedLevel = math.clamp(math.floor(legacyLevel), typedConfig.MinimumLevel, typedConfig.MaximumLevel)
		return stateFromTotalXP(totalXPUnchecked(boundedLevel, typedConfig), typedConfig, true, "LegacyLevelOnly")
	end

	return stateFromTotalXP(0, typedConfig, true, "MissingProgressionFields")
end

function Resolver.serializeState(rawState: any, config: any?): any
	-- Persistence already normalizes with the configured curve before serializing.
	-- Allow that canonical state to serialize without running the curve a second
	-- time, while all non-canonical callers must still provide a valid config.
	if config == nil then
		if
			type(rawState) ~= "table"
			or type(rawState.Version) ~= "string"
			or rawState.Version == ""
			or not isFiniteNumber(rawState.TotalXP)
			or rawState.TotalXP < 0
		then
			error("canonical character progression state required when config is omitted", 2)
		end
		return table.freeze({
			Version = rawState.Version,
			TotalXP = math.floor(rawState.TotalXP),
		})
	end
	local state = Resolver.normalizeState(rawState, config)
	return table.freeze({
		Version = state.Version,
		TotalXP = state.TotalXP,
	})
end

function Resolver.awardXP(rawState: any, amount: any, config: any): any
	local before = Resolver.normalizeState(rawState, config)
	if not isFiniteNumber(amount) or amount <= 0 then
		return table.freeze({
			Accepted = false,
			ReasonId = "InvalidXPAward",
			RequestedXP = 0,
			AwardedXP = 0,
			LevelsGained = 0,
			LevelUps = table.freeze({}),
			PreviousState = before,
			State = before,
		})
	end

	local requested = math.floor(amount)
	if requested < 1 then
		return table.freeze({
			Accepted = false,
			ReasonId = "InvalidXPAward",
			RequestedXP = 0,
			AwardedXP = 0,
			LevelsGained = 0,
			LevelUps = table.freeze({}),
			PreviousState = before,
			State = before,
		})
	end
	if before.IsLevelCap then
		return table.freeze({
			Accepted = false,
			ReasonId = "LevelCapReached",
			RequestedXP = requested,
			AwardedXP = 0,
			LevelsGained = 0,
			LevelUps = table.freeze({}),
			PreviousState = before,
			State = before,
		})
	end

	local typedConfig = config :: ProgressionConfig
	local capXP = totalXPUnchecked(typedConfig.MaximumLevel, typedConfig)
	local remainingToCap = capXP - before.TotalXP
	local awarded = math.min(requested, remainingToCap)
	local after = stateFromTotalXP(before.TotalXP + awarded, typedConfig, false, nil)
	local levelUps = {}
	for level = before.Level + 1, after.Level do
		table.insert(levelUps, level)
	end

	return table.freeze({
		Accepted = true,
		ReasonId = if awarded < requested then "XPClampedAtLevelCap" else "XPAwarded",
		RequestedXP = requested,
		AwardedXP = awarded,
		LevelsGained = after.Level - before.Level,
		LevelUps = table.freeze(levelUps),
		PreviousState = before,
		State = after,
	})
end

return table.freeze(Resolver)
