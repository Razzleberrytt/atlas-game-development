--!strict

local Contracts = {}

export type SelectionStateId = "Open" | "Locked"
export type NetworkOperationId = "Snapshot" | "Rejected"
export type RejectionReasonId =
	"ServiceStopped"
	| "NotParticipant"
	| "SelectionClosed"
	| "InvalidIntent"
	| "UnknownWeapon"
	| "DuplicateRequest"
	| "RateLimited"

export type SelectionIntent = {
	requestId: string,
	weaponId: string,
}

export type AuthoritativeAssignment = {
	operativeEntityId: string,
	weaponId: string,
	selectionStateId: SelectionStateId,
	revision: number,
}

export type SafeSnapshot = {
	operationId: NetworkOperationId,
	rosterRevision: number,
	selectionStateId: SelectionStateId,
	ownerAssignment: AuthoritativeAssignment?,
}

Contracts.SelectionStateIds = table.freeze({ Open = "Open", Locked = "Locked" })
Contracts.NetworkOperationIds = table.freeze({ Snapshot = "Snapshot", Rejected = "Rejected" })
Contracts.RejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	NotParticipant = "NotParticipant",
	SelectionClosed = "SelectionClosed",
	InvalidIntent = "InvalidIntent",
	UnknownWeapon = "UnknownWeapon",
	DuplicateRequest = "DuplicateRequest",
	RateLimited = "RateLimited",
})

local function boundedString(value: unknown, maximum: number): boolean
	return type(value) == "string" and value ~= "" and #value <= maximum
end

function Contracts.validateIntent(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local candidate = value :: any
	for key in candidate do
		if key ~= "requestId" and key ~= "weaponId" then
			return false
		end
	end
	return boundedString(candidate.requestId, 128) and boundedString(candidate.weaponId, 80)
end

function Contracts.validateSafeSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local candidate = value :: any
	if
		candidate.operationId ~= Contracts.NetworkOperationIds.Snapshot
		or type(candidate.rosterRevision) ~= "number"
		or candidate.rosterRevision < 0
		or (candidate.selectionStateId ~= Contracts.SelectionStateIds.Open
			and candidate.selectionStateId ~= Contracts.SelectionStateIds.Locked)
	then
		return false
	end
	local assignment = candidate.ownerAssignment
	if assignment == nil then
		return true
	end
	return type(assignment) == "table"
		and boundedString(assignment.operativeEntityId, 160)
		and boundedString(assignment.weaponId, 80)
		and assignment.selectionStateId == candidate.selectionStateId
		and type(assignment.revision) == "number"
		and assignment.revision >= 1
end

return table.freeze(Contracts)
