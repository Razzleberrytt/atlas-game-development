--!strict

local Contracts = {}

export type CategoryId = "Location" | "Teammate" | "Objective" | "ObservedHostile"
export type LifecycleId = "Active" | "Expired" | "Removed"

Contracts.CategoryIds = table.freeze({
	Location = "Location",
	Teammate = "Teammate",
	Objective = "Objective",
	ObservedHostile = "ObservedHostile",
})

Contracts.ImplementedCategoryIds = table.freeze({
	Location = "Location",
})

Contracts.LifecycleIds = table.freeze({
	Active = "Active",
	Expired = "Expired",
	Removed = "Removed",
})

-- This is the only rejection vocabulary. Keep every fixture, server path, and
-- P4 document on these exact PascalCase identifiers.
Contracts.RejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidSender = "InvalidSender",
	UnknownOperative = "UnknownOperative",
	InvalidLifeState = "InvalidLifeState",
	IncapacitatedSender = "IncapacitatedSender",
	DeadSender = "DeadSender",
	InvalidSquad = "InvalidSquad",
	MalformedIntent = "MalformedIntent",
	StaleIntent = "StaleIntent",
	InvalidCategory = "InvalidCategory",
	InvalidPayload = "InvalidPayload",
	InvalidLocation = "InvalidLocation",
	OutOfRangeLocation = "OutOfRangeLocation",
	InvalidEntityReference = "InvalidEntityReference",
	UndisclosedReference = "UndisclosedReference",
	InvalidObservationState = "InvalidObservationState",
	StaleObservation = "StaleObservation",
	MissingDirectSight = "MissingDirectSight",
	StaleDirectSight = "StaleDirectSight",
	RateLimited = "RateLimited",
	SenderLimitExceeded = "SenderLimitExceeded",
	SquadLimitExceeded = "SquadLimitExceeded",
	InternalError = "InternalError",
	RecipientUnavailable = "RecipientUnavailable",
	StateMismatch = "StateMismatch",
})

Contracts.StateOperationIds = table.freeze({
	Snapshot = "Snapshot",
	Rejected = "Rejected",
})

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonnegativeInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0 and (value :: number) % 1 == 0
end

local function hasExactKeys(value: any, allowed: { [string]: boolean }, expectedCount: number): boolean
	local count = 0
	for key in value do
		if type(key) ~= "string" or not allowed[key] then
			return false
		end
		count += 1
	end
	return count == expectedCount
end

function Contracts.validateClientIntent(intent: unknown): (boolean, string?)
	if type(intent) ~= "table" then
		return false, Contracts.RejectionReasonIds.MalformedIntent
	end
	local payload = intent :: any
	if not hasExactKeys(payload, { categoryId = true, candidatePosition = true }, 2) then
		return false, Contracts.RejectionReasonIds.MalformedIntent
	end
	if type(payload.categoryId) ~= "string" then
		return false, Contracts.RejectionReasonIds.InvalidCategory
	end
	if Contracts.CategoryIds[payload.categoryId] ~= payload.categoryId then
		return false, Contracts.RejectionReasonIds.InvalidCategory
	end
	if Contracts.ImplementedCategoryIds[payload.categoryId] ~= payload.categoryId then
		return false, Contracts.RejectionReasonIds.InvalidCategory
	end
	return true, nil
end

local function validatePosition(position: unknown): boolean
	if typeof(position) ~= "Vector3" then
		return false
	end
	local value = position :: Vector3
	return isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)
end

function Contracts.validateSafeSnapshot(payload: unknown): boolean
	if type(payload) ~= "table" then
		return false
	end
	local snapshot = payload :: any
	if snapshot.operationId == Contracts.StateOperationIds.Rejected then
		return hasExactKeys(snapshot, { operationId = true, revision = true, rejectionReasonId = true }, 3)
			and isNonnegativeInteger(snapshot.revision)
			and type(snapshot.rejectionReasonId) == "string"
			and Contracts.RejectionReasonIds[snapshot.rejectionReasonId] == snapshot.rejectionReasonId
	end
	if snapshot.operationId ~= Contracts.StateOperationIds.Snapshot then
		return false
	end
	if not hasExactKeys(snapshot, { operationId = true, revision = true, pings = true }, 3) then
		return false
	end
	if not isNonnegativeInteger(snapshot.revision) or type(snapshot.pings) ~= "table" then
		return false
	end
	local previousSequence = 0
	for index, ping in snapshot.pings do
		if type(index) ~= "number" or index % 1 ~= 0 or type(ping) ~= "table" then
			return false
		end
		if
			not hasExactKeys(ping, {
				pingId = true,
				categoryId = true,
				position = true,
				senderOperativeEntityId = true,
				expiresAtServerTimestamp = true,
				revision = true,
				sequence = true,
			}, 7)
		then
			return false
		end
		if
			type(ping.pingId) ~= "string"
			or ping.categoryId ~= Contracts.CategoryIds.Location
			or type(ping.senderOperativeEntityId) ~= "string"
			or ping.senderOperativeEntityId == ""
			or not validatePosition(ping.position)
			or not isFiniteNumber(ping.expiresAtServerTimestamp)
			or not isNonnegativeInteger(ping.revision)
			or not isNonnegativeInteger(ping.sequence)
			or ping.sequence <= previousSequence
		then
			return false
		end
		previousSequence = ping.sequence
	end
	return true
end

function Contracts.reconcileSnapshot(currentRevision: number, payload: unknown): (boolean, { any }?, number?)
	if not Contracts.validateSafeSnapshot(payload) then
		return false, nil, nil
	end
	local snapshot = payload :: any
	if snapshot.operationId ~= Contracts.StateOperationIds.Snapshot or snapshot.revision < currentRevision then
		return false, nil, nil
	end
	return true, snapshot.pings, snapshot.revision
end

return table.freeze(Contracts)
