--!strict

local PersonalFlashlightContracts = {}

export type FlashlightStateId = "Inactive" | "Active"
export type ToggleResultStatusId = "Changed" | "Equivalent" | "Rejected"
export type CoverageProfileId = "Standard" | "Focused"

export type SafeFlashlightState = {
	stateId: FlashlightStateId,
	revision: number,
	resultStatusId: ToggleResultStatusId,
	rejectionReasonId: string?,
	coverageProfileId: CoverageProfileId?,
}

PersonalFlashlightContracts.StateIds = table.freeze({
	Inactive = "Inactive",
	Active = "Active",
})

-- The server derives the operative's coverage profile from durable progression
-- and discloses it only to that operative, so the local presenter can match the
-- authoritative cone. A client never selects or asserts a profile, and an absent
-- field means the standard profile.
PersonalFlashlightContracts.CoverageProfileIds = table.freeze({
	Standard = "Standard",
	Focused = "Focused",
})

PersonalFlashlightContracts.ToggleResultStatusIds = table.freeze({
	Changed = "Changed",
	Equivalent = "Equivalent",
	Rejected = "Rejected",
})

PersonalFlashlightContracts.RejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidPlayer = "InvalidPlayer",
	UnknownOperative = "UnknownOperative",
	DuplicateOperative = "DuplicateOperative",
	PlayerAlreadyRegistered = "PlayerAlreadyRegistered",
	OwnershipMismatch = "OwnershipMismatch",
	Ineligible = "Ineligible",
	NotAlive = "NotAlive",
	MalformedRequest = "MalformedRequest",
	Cooldown = "Cooldown",
	LightingRejected = "LightingRejected",
	StaleLifecycle = "StaleLifecycle",
})

local function knownValue(values: { [string]: string }, value: unknown): boolean
	return type(value) == "string" and values[value :: string] == value
end

local function isRevision(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 0
		and value % 1 == 0
end

function PersonalFlashlightContracts.validateSafeState(payload: unknown): boolean
	if type(payload) ~= "table" then
		return false
	end
	local state = payload :: any
	local fieldCount = 0
	for key in state do
		if
			key ~= "stateId"
			and key ~= "revision"
			and key ~= "resultStatusId"
			and key ~= "rejectionReasonId"
			and key ~= "coverageProfileId"
		then
			return false
		end
		fieldCount += 1
	end
	if fieldCount < 3 or fieldCount > 5 then
		return false
	end
	if not knownValue(PersonalFlashlightContracts.StateIds, state.stateId) or not isRevision(state.revision) then
		return false
	end
	if not knownValue(PersonalFlashlightContracts.ToggleResultStatusIds, state.resultStatusId) then
		return false
	end
	if
		state.coverageProfileId ~= nil
		and not knownValue(PersonalFlashlightContracts.CoverageProfileIds, state.coverageProfileId)
	then
		return false
	end
	if state.resultStatusId == PersonalFlashlightContracts.ToggleResultStatusIds.Rejected then
		return type(state.rejectionReasonId) == "string" and state.rejectionReasonId ~= ""
	end
	return state.rejectionReasonId == nil
end

function PersonalFlashlightContracts.reconcilePresentation(
	currentRevision: number,
	payload: unknown
): (boolean, FlashlightStateId?, number?, CoverageProfileId?)
	if not PersonalFlashlightContracts.validateSafeState(payload) then
		return false, nil, nil, nil
	end
	local state = payload :: SafeFlashlightState
	if state.revision < currentRevision then
		return false, nil, nil, nil
	end
	local coverageProfileId = state.coverageProfileId or PersonalFlashlightContracts.CoverageProfileIds.Standard
	return true, state.stateId, state.revision, coverageProfileId
end

return table.freeze(PersonalFlashlightContracts)
