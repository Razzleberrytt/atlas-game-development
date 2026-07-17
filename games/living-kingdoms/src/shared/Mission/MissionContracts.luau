--!strict

--[[
	P5-0103 shared mission vocabulary. The server owns every phase transition,
	objective fact, extraction fact, timer, and outcome; clients receive only the
	safe snapshot shape validated here and may never establish mission truth.
]]

export type MissionPhaseId = "Insertion" | "Infiltration" | "Exfiltration" | "Holdout" | "Resolved"
export type MissionOutcomeId = "Success" | "Failure"
export type ObjectiveStateId = "Inactive" | "Active" | "Completed"

export type SafeRadioTransmission = {
	lineId: string,
	text: string,
	serverTimestamp: number,
}

export type SafeMissionSnapshot = {
	operationId: string,
	revision: number,
	phaseId: MissionPhaseId,
	objectiveStateId: ObjectiveStateId,
	objectiveText: string,
	extractionUnlocked: boolean,
	escalationLevel: number,
	holdoutDeadlineServerTimestamp: number?,
	outcomeId: MissionOutcomeId?,
	radio: SafeRadioTransmission?,
}

local MissionContracts = {}

MissionContracts.MissionPhaseIds = table.freeze({
	Insertion = "Insertion" :: "Insertion",
	Infiltration = "Infiltration" :: "Infiltration",
	Exfiltration = "Exfiltration" :: "Exfiltration",
	Holdout = "Holdout" :: "Holdout",
	Resolved = "Resolved" :: "Resolved",
})

MissionContracts.MissionOutcomeIds = table.freeze({
	Success = "Success" :: "Success",
	Failure = "Failure" :: "Failure",
})

MissionContracts.ObjectiveStateIds = table.freeze({
	Inactive = "Inactive" :: "Inactive",
	Active = "Active" :: "Active",
	Completed = "Completed" :: "Completed",
})

MissionContracts.RejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidPhase = "InvalidPhase",
	AlreadyCompleted = "AlreadyCompleted",
	UnknownOperative = "UnknownOperative",
	InvalidLifeState = "InvalidLifeState",
	MissingPosition = "MissingPosition",
	OutOfRange = "OutOfRange",
	InvalidTimestamp = "InvalidTimestamp",
})

MissionContracts.RadioLineIds = table.freeze({
	InsertionComplete = "InsertionComplete",
	ProceedToObjective = "ProceedToObjective",
	ObjectiveComplete = "ObjectiveComplete",
	PressureRising = "PressureRising",
	HoldPosition = "HoldPosition",
	MissionSuccess = "MissionSuccess",
	MissionFailure = "MissionFailure",
})

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeFiniteNumber(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) >= 0
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

function MissionContracts.validateSafeRadioTransmission(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local radio = value :: { [string]: unknown }
	return isNonEmptyString(radio.lineId)
		and MissionContracts.RadioLineIds[radio.lineId :: string] ~= nil
		and isNonEmptyString(radio.text)
		and isNonNegativeFiniteNumber(radio.serverTimestamp)
end

function MissionContracts.validateSafeMissionSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: { [string]: unknown }
	if not isNonEmptyString(snapshot.operationId) then
		return false
	end
	if not isNonNegativeFiniteNumber(snapshot.revision) then
		return false
	end
	if
		not isNonEmptyString(snapshot.phaseId)
		or MissionContracts.MissionPhaseIds[snapshot.phaseId :: string] == nil
	then
		return false
	end
	if
		not isNonEmptyString(snapshot.objectiveStateId)
		or MissionContracts.ObjectiveStateIds[snapshot.objectiveStateId :: string] == nil
	then
		return false
	end
	if not isNonEmptyString(snapshot.objectiveText) then
		return false
	end
	if type(snapshot.extractionUnlocked) ~= "boolean" then
		return false
	end
	if not isNonNegativeFiniteNumber(snapshot.escalationLevel) then
		return false
	end
	if
		snapshot.holdoutDeadlineServerTimestamp ~= nil
		and not isNonNegativeFiniteNumber(snapshot.holdoutDeadlineServerTimestamp)
	then
		return false
	end
	if snapshot.outcomeId ~= nil then
		if
			not isNonEmptyString(snapshot.outcomeId)
			or MissionContracts.MissionOutcomeIds[snapshot.outcomeId :: string] == nil
		then
			return false
		end
		if snapshot.phaseId ~= MissionContracts.MissionPhaseIds.Resolved then
			return false
		end
	elseif snapshot.phaseId == MissionContracts.MissionPhaseIds.Resolved then
		return false
	end
	if snapshot.radio ~= nil and not MissionContracts.validateSafeRadioTransmission(snapshot.radio) then
		return false
	end
	return true
end

return table.freeze(MissionContracts)
