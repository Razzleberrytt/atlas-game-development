--!strict

--[[
	P8-0101 shared objective-chain vocabulary. The server owns every objective
	fact — which objective is active, how far it has progressed, whether it is
	decaying, and when it completes. Clients declare nothing; they receive only
	the safe objective snapshot shape validated here and render it.

	This module is intentionally self-contained (it requires nothing) so the
	authored configuration, the pure runtime resolver, the mission director, and
	the client controller can all share one vocabulary without a dependency cycle.
]]

export type InteractionKindId = "HeldChannel" | "DecayingCharge" | "EquipmentRepair"
export type ObjectiveStateId = "Locked" | "Active" | "Completed"

export type SafeObjectiveSnapshot = {
	objectiveId: string,
	displayText: string,
	stateId: ObjectiveStateId,
	progressRatio: number,
	decaying: boolean,
	isOptional: boolean,
	destinationDisplayName: string,
}

local ObjectiveContracts = {}

ObjectiveContracts.ObjectiveIds = table.freeze({
	RestoreRelay = "objective.restore-lookout-relay",
	ChargeBooster = "objective.charge-roadblock-booster",
	RestoreFloodlights = "objective.restore-extraction-floodlights",
})

ObjectiveContracts.InteractionKindIds = table.freeze({
	HeldChannel = "HeldChannel" :: "HeldChannel",
	DecayingCharge = "DecayingCharge" :: "DecayingCharge",
	EquipmentRepair = "EquipmentRepair" :: "EquipmentRepair",
})

ObjectiveContracts.ObjectiveStateIds = table.freeze({
	Locked = "Locked" :: "Locked",
	Active = "Active" :: "Active",
	Completed = "Completed" :: "Completed",
})

ObjectiveContracts.RejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidPhase = "InvalidPhase",
	InvalidTimestamp = "InvalidTimestamp",
	InvalidDelta = "InvalidDelta",
	StaleRevision = "StaleRevision",
	UnknownObjective = "UnknownObjective",
	InvalidPrerequisite = "InvalidPrerequisite",
	ObjectiveAlreadyCompleted = "ObjectiveAlreadyCompleted",
})

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeFiniteNumber(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0
end

local function isPositiveFiniteNumber(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) > 0
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

function ObjectiveContracts.isInteractionKindId(value: unknown): boolean
	return value == ObjectiveContracts.InteractionKindIds.HeldChannel
		or value == ObjectiveContracts.InteractionKindIds.DecayingCharge
		or value == ObjectiveContracts.InteractionKindIds.EquipmentRepair
end

-- One authored objective definition. Validated so a malformed chain fails loudly
-- at configuration time, never silently at runtime.
function ObjectiveContracts.validateObjectiveDefinition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local definition = value :: { [string]: unknown }
	if not isNonEmptyString(definition.objectiveId) then
		return false
	end
	if not isNonEmptyString(definition.landmarkId) then
		return false
	end
	if not isNonEmptyString(definition.displayText) then
		return false
	end
	if not isNonEmptyString(definition.destinationDisplayName) then
		return false
	end
	if not ObjectiveContracts.isInteractionKindId(definition.interactionKindId) then
		return false
	end
	-- activePhaseIds declares the mission phases in which this objective can
	-- progress. It must be a non-empty map of phase id -> true.
	if type(definition.activePhaseIds) ~= "table" then
		return false
	end
	local hasActivePhase = false
	for phaseId, enabled in definition.activePhaseIds :: { [string]: unknown } do
		if not isNonEmptyString(phaseId) or enabled ~= true then
			return false
		end
		hasActivePhase = true
	end
	if not hasActivePhase then
		return false
	end
	if type(definition.center) ~= "table" then
		return false
	end
	local center = definition.center :: { [string]: unknown }
	if not (isFiniteNumber(center.x) and isFiniteNumber(center.y) and isFiniteNumber(center.z)) then
		return false
	end
	if not isPositiveFiniteNumber(definition.interactionRadiusStuds) then
		return false
	end
	if not isPositiveFiniteNumber(definition.completionUnits) then
		return false
	end
	if not isNonNegativeFiniteNumber(definition.decayRatePerSecond) then
		return false
	end
	if not isPositiveFiniteNumber(definition.baseRatePerSecond) then
		return false
	end
	-- The engineer-assisted rate multiplier is >= 1 (assistance is never slower);
	-- a decaying charge with no assistance path keeps it at exactly 1.
	if not isFiniteNumber(definition.assistedRateMultiplier) or (definition.assistedRateMultiplier :: number) < 1 then
		return false
	end
	if type(definition.isOptional) ~= "boolean" then
		return false
	end
	-- prerequisiteObjectiveId is optional; when present it must be a non-empty string.
	if definition.prerequisiteObjectiveId ~= nil and not isNonEmptyString(definition.prerequisiteObjectiveId) then
		return false
	end
	-- isRequiredForExtraction gates whether completing it unlocks exfiltration.
	if type(definition.isRequiredForExtraction) ~= "boolean" then
		return false
	end
	-- waveIndexOnComplete is optional; when present it is a positive integer.
	if definition.waveIndexOnComplete ~= nil then
		local waveIndex = definition.waveIndexOnComplete
		if not isPositiveFiniteNumber(waveIndex) or (waveIndex :: number) % 1 ~= 0 then
			return false
		end
	end
	-- radioLineIdOnComplete is optional presentation text; when present, non-empty.
	if definition.radioLineIdOnComplete ~= nil and not isNonEmptyString(definition.radioLineIdOnComplete) then
		return false
	end
	return true
end

function ObjectiveContracts.validateSafeObjectiveSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: { [string]: unknown }
	if not isNonEmptyString(snapshot.objectiveId) then
		return false
	end
	if not isNonEmptyString(snapshot.displayText) then
		return false
	end
	if not isNonEmptyString(snapshot.destinationDisplayName) then
		return false
	end
	if
		not isNonEmptyString(snapshot.stateId)
		or ObjectiveContracts.ObjectiveStateIds[snapshot.stateId :: string] == nil
	then
		return false
	end
	local progressRatio = snapshot.progressRatio
	if not isFiniteNumber(progressRatio) or (progressRatio :: number) < 0 or (progressRatio :: number) > 1 then
		return false
	end
	if type(snapshot.decaying) ~= "boolean" then
		return false
	end
	if type(snapshot.isOptional) ~= "boolean" then
		return false
	end
	return true
end

return table.freeze(ObjectiveContracts)
