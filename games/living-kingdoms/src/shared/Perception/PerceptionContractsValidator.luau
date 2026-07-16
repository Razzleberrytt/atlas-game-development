--!strict

-- Pure record validation only. The caller supplies the authoritative server
-- evaluation timestamp; this module performs no clock read, timer, runtime
-- lookup, spatial query, line-of-sight test, raycast, or input mutation.
local PerceptionContracts = require(script.Parent.PerceptionContracts)
local PerceptionConfig = require(script.Parent.Parent.Config.PerceptionConfig)

local PerceptionContractsValidator = {}

local function accepted()
	return table.freeze({
		isValid = true,
		rejectionReasonId = nil,
	})
end

local function rejected(rejectionReasonId: string)
	return table.freeze({
		isValid = false,
		rejectionReasonId = rejectionReasonId,
	})
end

local function isNonemptyString(value: unknown): boolean
	return typeof(value) == "string" and #value > 0
end

local function isFiniteNonnegativeNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function isKnownValue(values: { [string]: string }, value: unknown): boolean
	if typeof(value) ~= "string" then
		return false
	end

	return values[value] == value
end

-- Stable first failure: record, entity, source, disclosure, perception,
-- memory, confidence, timestamp, then age.
function PerceptionContractsValidator.validate(record: unknown, evaluationServerTimestamp: unknown)
	if typeof(record) ~= "table" then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.InvalidRecord)
	end
	if not isNonemptyString(record.observedEntityId) then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.InvalidEntity)
	end
	if not isKnownValue(PerceptionContracts.ObservationSourceIds, record.observationSourceId) then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.InvalidSource)
	end
	if not isKnownValue(PerceptionContracts.DisclosureStateIds, record.disclosureStateId) then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.InvalidDisclosure)
	end
	if not isKnownValue(PerceptionContracts.PerceptionStateIds, record.perceptionStateId) then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.InvalidPerception)
	end
	if not isKnownValue(PerceptionContracts.MemoryStateIds, record.memoryStateId) then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.InvalidMemory)
	end
	if not isKnownValue(PerceptionContracts.ObservationConfidenceIds, record.confidenceId) then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.InvalidConfidence)
	end
	if
		not isFiniteNonnegativeNumber(record.observedAtServerTimestamp)
		or not isFiniteNonnegativeNumber(evaluationServerTimestamp)
		or record.observedAtServerTimestamp > evaluationServerTimestamp
	then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.InvalidTimestamp)
	end
	if evaluationServerTimestamp - record.observedAtServerTimestamp > PerceptionConfig.MaximumObservationAgeSeconds then
		return rejected(PerceptionContracts.PerceptionRejectionReasonIds.StaleObservation)
	end

	return accepted()
end

return table.freeze(PerceptionContractsValidator)
