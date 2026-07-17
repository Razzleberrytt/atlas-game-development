--!strict

--[[
	Pure P7-0102 selection eligibility and transition logic. The caller supplies
	server-derived participation, mission, rate-limit, availability, and replay
	facts. This module owns no Player, RemoteEvent, timer, roster, or assignment
	state and never mutates its inputs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local MissionContracts = require(ReplicatedStorage.Shared.Mission.MissionContracts)

local RejectionReasonIds = ClassContracts.ClassActionRejectionReasonIds
local SelectionStateIds = ClassContracts.ClassSelectionStateIds

export type SelectionAuthorityFacts = {
	isParticipant: boolean,
	missionPhaseId: string,
	insertionDeadlineServerTimestamp: number?,
	serverTimestamp: number,
	availableClassIds: { [string]: boolean },
	isDuplicateRequest: boolean,
	isRateLimited: boolean,
}

export type SelectionResult = {
	didSelect: boolean,
	rejectionReasonId: string?,
	requestId: string?,
	assignmentAfter: ClassContracts.AuthoritativeClassAssignment,
}

local Resolver = {}

local function copyAssignment(
	assignment: ClassContracts.AuthoritativeClassAssignment
): ClassContracts.AuthoritativeClassAssignment
	return table.freeze({
		operativeEntityId = assignment.operativeEntityId,
		classId = assignment.classId,
		selectionStateId = assignment.selectionStateId,
		revision = assignment.revision,
	})
end

local function rejected(
	assignment: ClassContracts.AuthoritativeClassAssignment,
	reasonId: string,
	requestId: string?
): SelectionResult
	return table.freeze({
		didSelect = false,
		rejectionReasonId = reasonId,
		requestId = requestId,
		assignmentAfter = copyAssignment(assignment),
	})
end

local function isFiniteNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function validFacts(facts: unknown): boolean
	if type(facts) ~= "table" then
		return false
	end
	local candidate = facts :: any
	return type(candidate.isParticipant) == "boolean"
		and type(candidate.missionPhaseId) == "string"
		and isFiniteNonnegative(candidate.serverTimestamp)
		and (candidate.insertionDeadlineServerTimestamp == nil or isFiniteNonnegative(
			candidate.insertionDeadlineServerTimestamp
		))
		and type(candidate.availableClassIds) == "table"
		and type(candidate.isDuplicateRequest) == "boolean"
		and type(candidate.isRateLimited) == "boolean"
end

function Resolver.resolve(
	currentAssignment: ClassContracts.AuthoritativeClassAssignment,
	rawIntent: unknown,
	facts: SelectionAuthorityFacts
): SelectionResult
	if not ClassContracts.validateAuthoritativeClassAssignment(currentAssignment) or not validFacts(facts) then
		return rejected(currentAssignment, RejectionReasonIds.InvalidIntent, nil)
	end
	if not ClassContracts.validateClassSelectionIntent(rawIntent) then
		return rejected(currentAssignment, RejectionReasonIds.InvalidIntent, nil)
	end
	local intent = rawIntent :: any
	local requestId = intent.requestId :: string
	local requestedClassId = intent.classId :: string
	if not ClassContracts.isKnownClassId(requestedClassId) then
		return rejected(currentAssignment, RejectionReasonIds.UnknownClass, requestId)
	end
	if not facts.isParticipant then
		return rejected(currentAssignment, RejectionReasonIds.NotParticipant, requestId)
	end
	if facts.missionPhaseId == MissionContracts.MissionPhaseIds.Resolved then
		return rejected(currentAssignment, RejectionReasonIds.OperationResolved, requestId)
	end
	if facts.missionPhaseId ~= ClassConfig.Selection.openMissionPhaseId then
		return rejected(currentAssignment, RejectionReasonIds.SelectionClosed, requestId)
	end
	local deadline = facts.insertionDeadlineServerTimestamp
	if deadline == nil or facts.serverTimestamp >= deadline then
		return rejected(currentAssignment, RejectionReasonIds.SelectionClosed, requestId)
	end
	if currentAssignment.selectionStateId == SelectionStateIds.Locked then
		return rejected(currentAssignment, RejectionReasonIds.ClassLocked, requestId)
	end
	if facts.availableClassIds[requestedClassId] ~= true then
		return rejected(currentAssignment, RejectionReasonIds.ClassUnavailable, requestId)
	end
	if facts.isDuplicateRequest then
		return rejected(currentAssignment, RejectionReasonIds.DuplicateRequest, requestId)
	end
	if facts.isRateLimited then
		return rejected(currentAssignment, RejectionReasonIds.RateLimited, requestId)
	end
	return table.freeze({
		didSelect = true,
		rejectionReasonId = nil,
		requestId = requestId,
		assignmentAfter = table.freeze({
			operativeEntityId = currentAssignment.operativeEntityId,
			classId = requestedClassId,
			selectionStateId = SelectionStateIds.Open,
			revision = currentAssignment.revision + 1,
		}),
	})
end

return table.freeze(Resolver)
