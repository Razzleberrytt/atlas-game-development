--!strict

-- Contract-only pre-launch operation selection. No network or server owner is
-- bound to this module yet. It defines the smallest safe client/server payloads
-- needed before an expedition can eventually consume a validated operation ID.

local Contracts = {}

Contracts.SelectionStateIds = table.freeze({
	Held = "Held",
	Open = "Open",
	Locked = "Locked",
})

Contracts.NetworkOperationIds = table.freeze({
	Snapshot = "operation-selection.snapshot",
	Rejected = "operation-selection.rejected",
})

Contracts.RejectionReasonIds = table.freeze({
	RuntimeDisabled = "RuntimeDisabled",
	UnknownOperation = "UnknownOperation",
	SelectionLocked = "SelectionLocked",
	RevisionMismatch = "RevisionMismatch",
	PermissionDenied = "PermissionDenied",
	PlayerNotInLobby = "PlayerNotInLobby",
	InvalidRequest = "InvalidRequest",
})

export type SelectionStateId = "Held" | "Open" | "Locked"

export type SafeOperationSummary = {
	operationId: string,
	displayName: string,
	minimumPlayers: number,
	maximumPlayers: number,
	targetDurationSeconds: number,
	launchCompatible: boolean,
}

export type SafeSelectionSnapshot = {
	networkOperationId: string,
	catalogRevision: number,
	selectionRevision: number,
	selectionStateId: SelectionStateId,
	selectedOperationId: string?,
	operations: { SafeOperationSummary },
}

export type SelectionIntent = {
	requestId: string,
	operationId: string,
	expectedSelectionRevision: number,
}

export type SafeSelectionRejection = {
	networkOperationId: string,
	requestId: string?,
	selectionRevision: number,
	rejectionReasonId: string,
}

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonnegativeInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0 and (value :: number) % 1 == 0
end

local function isPositiveInteger(value: unknown): boolean
	return isNonnegativeInteger(value) and (value :: number) >= 1
end

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

local function hasOnlyKeys(value: { [any]: any }, permittedKeys: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or permittedKeys[key] ~= true then
			return false
		end
	end
	return true
end

local function containsValue(values: { [string]: string }, candidate: unknown): boolean
	if type(candidate) ~= "string" then
		return false
	end
	for _, value in values do
		if value == candidate then
			return true
		end
	end
	return false
end

function Contracts.validateSafeOperationSummary(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local summary = value :: { [any]: any }
	if
		not hasOnlyKeys(summary, {
			operationId = true,
			displayName = true,
			minimumPlayers = true,
			maximumPlayers = true,
			targetDurationSeconds = true,
			launchCompatible = true,
		})
	then
		return false
	end
	return isNonEmptyBoundedString(summary.operationId, 64)
		and isNonEmptyBoundedString(summary.displayName, 128)
		and isPositiveInteger(summary.minimumPlayers)
		and isPositiveInteger(summary.maximumPlayers)
		and summary.minimumPlayers <= summary.maximumPlayers
		and isPositiveInteger(summary.targetDurationSeconds)
		and type(summary.launchCompatible) == "boolean"
end

function Contracts.validateSelectionIntent(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local intent = value :: { [any]: any }
	if not hasOnlyKeys(intent, {
		requestId = true,
		operationId = true,
		expectedSelectionRevision = true,
	}) then
		return false
	end
	return isNonEmptyBoundedString(intent.requestId, 128)
		and isNonEmptyBoundedString(intent.operationId, 64)
		and isNonnegativeInteger(intent.expectedSelectionRevision)
end

function Contracts.validateSafeSelectionSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: { [any]: any }
	if
		not hasOnlyKeys(snapshot, {
			networkOperationId = true,
			catalogRevision = true,
			selectionRevision = true,
			selectionStateId = true,
			selectedOperationId = true,
			operations = true,
		})
	then
		return false
	end
	if snapshot.networkOperationId ~= Contracts.NetworkOperationIds.Snapshot then
		return false
	end
	if
		not isNonnegativeInteger(snapshot.catalogRevision)
		or not isNonnegativeInteger(snapshot.selectionRevision)
		or not containsValue(Contracts.SelectionStateIds, snapshot.selectionStateId)
		or (snapshot.selectedOperationId ~= nil and not isNonEmptyBoundedString(snapshot.selectedOperationId, 64))
		or type(snapshot.operations) ~= "table"
	then
		return false
	end

	local seenOperationIds = {}
	local selectedFound = snapshot.selectedOperationId == nil
	for index, summary in snapshot.operations :: { [any]: any } do
		if
			type(index) ~= "number"
			or index % 1 ~= 0
			or index < 1
			or not Contracts.validateSafeOperationSummary(summary)
		then
			return false
		end
		local operationId = summary.operationId
		if seenOperationIds[operationId] then
			return false
		end
		seenOperationIds[operationId] = true
		if operationId == snapshot.selectedOperationId then
			selectedFound = true
		end
	end
	return selectedFound
end

function Contracts.validateSafeSelectionRejection(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local rejection = value :: { [any]: any }
	if
		not hasOnlyKeys(rejection, {
			networkOperationId = true,
			requestId = true,
			selectionRevision = true,
			rejectionReasonId = true,
		})
	then
		return false
	end
	return rejection.networkOperationId == Contracts.NetworkOperationIds.Rejected
		and (rejection.requestId == nil or isNonEmptyBoundedString(rejection.requestId, 128))
		and isNonnegativeInteger(rejection.selectionRevision)
		and containsValue(Contracts.RejectionReasonIds, rejection.rejectionReasonId)
end

return table.freeze(Contracts)
