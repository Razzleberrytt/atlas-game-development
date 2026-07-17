--!strict

--[[
	P5-0105 pure pressure-pacing rules. This module owns no Roblox instances,
	schedulers, mission state, or enemy state. It only decides whether authored
	pressure may release at a deterministic evaluation boundary.
]]

export type PressureFacts = {
	missionResolved: boolean,
	requestedWaveIndex: number,
	completedWaveCount: number,
	activeEnemyCount: number,
	maximumConcurrentEnemies: number,
	serverTimestamp: number,
	lastWaveReleasedServerTimestamp: number?,
	minimumSecondsBetweenWaves: number,
	recoveryUntilServerTimestamp: number?,
}

export type PressureDecision = {
	shouldReleaseWave: boolean,
	reasonId: string,
}

local Domain = {}

Domain.DecisionReasonIds = table.freeze({
	Accepted = "Accepted",
	MissionResolved = "MissionResolved",
	InvalidFacts = "InvalidFacts",
	AlreadyReleased = "AlreadyReleased",
	ConcurrentBudgetReached = "ConcurrentBudgetReached",
	MinimumIntervalActive = "MinimumIntervalActive",
	RecoveryWindowActive = "RecoveryWindowActive",
})

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0 and (value :: number) % 1 == 0
end

function Domain.validateFacts(facts: unknown): boolean
	if type(facts) ~= "table" then
		return false
	end
	local value = facts :: any
	if type(value.missionResolved) ~= "boolean" then
		return false
	end
	if not isNonNegativeInteger(value.requestedWaveIndex) or value.requestedWaveIndex < 1 then
		return false
	end
	if not isNonNegativeInteger(value.completedWaveCount) then
		return false
	end
	if not isNonNegativeInteger(value.activeEnemyCount) then
		return false
	end
	if
		not isNonNegativeInteger(value.maximumConcurrentEnemies)
		or value.maximumConcurrentEnemies < 1
	then
		return false
	end
	if not isFiniteNumber(value.serverTimestamp) or value.serverTimestamp < 0 then
		return false
	end
	if value.lastWaveReleasedServerTimestamp ~= nil then
		if
			not isFiniteNumber(value.lastWaveReleasedServerTimestamp)
			or value.lastWaveReleasedServerTimestamp < 0
		then
			return false
		end
	end
	if
		not isFiniteNumber(value.minimumSecondsBetweenWaves)
		or value.minimumSecondsBetweenWaves < 0
	then
		return false
	end
	if value.recoveryUntilServerTimestamp ~= nil then
		if
			not isFiniteNumber(value.recoveryUntilServerTimestamp)
			or value.recoveryUntilServerTimestamp < 0
		then
			return false
		end
	end
	return true
end

function Domain.evaluate(facts: PressureFacts): PressureDecision
	if not Domain.validateFacts(facts) then
		return {
			shouldReleaseWave = false,
			reasonId = Domain.DecisionReasonIds.InvalidFacts,
		}
	end
	if facts.missionResolved then
		return {
			shouldReleaseWave = false,
			reasonId = Domain.DecisionReasonIds.MissionResolved,
		}
	end
	if facts.requestedWaveIndex <= facts.completedWaveCount then
		return {
			shouldReleaseWave = false,
			reasonId = Domain.DecisionReasonIds.AlreadyReleased,
		}
	end
	if facts.activeEnemyCount >= facts.maximumConcurrentEnemies then
		return {
			shouldReleaseWave = false,
			reasonId = Domain.DecisionReasonIds.ConcurrentBudgetReached,
		}
	end
	if
		facts.recoveryUntilServerTimestamp ~= nil
		and facts.serverTimestamp < facts.recoveryUntilServerTimestamp
	then
		return {
			shouldReleaseWave = false,
			reasonId = Domain.DecisionReasonIds.RecoveryWindowActive,
		}
	end
	if
		facts.lastWaveReleasedServerTimestamp ~= nil
		and facts.serverTimestamp < facts.lastWaveReleasedServerTimestamp + facts.minimumSecondsBetweenWaves
	then
		return {
			shouldReleaseWave = false,
			reasonId = Domain.DecisionReasonIds.MinimumIntervalActive,
		}
	end
	return {
		shouldReleaseWave = true,
		reasonId = Domain.DecisionReasonIds.Accepted,
	}
end

return table.freeze(Domain)
