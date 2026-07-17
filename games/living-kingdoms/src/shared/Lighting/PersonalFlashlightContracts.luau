--!strict

local PersonalFlashlightContracts = {}

export type FlashlightStateId = "Inactive" | "Active"
export type ToggleResultStatusId = "Changed" | "Equivalent" | "Rejected"

export type SafeFlashlightState = {
	stateId: FlashlightStateId,
	revision: number,
	resultStatusId: ToggleResultStatusId,
	rejectionReasonId: string?,
}

PersonalFlashlightContracts.StateIds = table.freeze({
	Inactive = "Inactive",
	Active = "Active",
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
		if key ~= "stateId" and key ~= "revision" and key ~= "resultStatusId" and key ~= "rejectionReasonId" then
			return false
		end
		fieldCount += 1
	end
	if fieldCount < 3 or fieldCount > 4 then
		return false
	end
	if not knownValue(PersonalFlashlightContracts.StateIds, state.stateId) or not isRevision(state.revision) then
		return false
	end
	if not knownValue(PersonalFlashlightContracts.ToggleResultStatusIds, state.resultStatusId) then
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
): (boolean, FlashlightStateId?, number?)
	if not PersonalFlashlightContracts.validateSafeState(payload) then
		return false, nil, nil
	end
	local state = payload :: SafeFlashlightState
	if state.revision < currentRevision then
		return false, nil, nil
	end
	return true, state.stateId, state.revision
end

return table.freeze(PersonalFlashlightContracts)
