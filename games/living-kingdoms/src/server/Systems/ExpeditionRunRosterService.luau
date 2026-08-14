--!strict

-- Server-owned immutable participant roster for the active expedition run.
-- The lobby binds the exact consumed launch party after the runtime mints a run
-- id. Downstream reward/result owners read this roster instead of reconstructing
-- participation from whichever Players happen to be connected later.

local Service = {}

local activeRunId: string? = nil
local participantUserIds: { number }? = nil
local revision = 0

local function validUserId(userId: any): boolean
	return type(userId) == "number" and userId > 0 and userId % 1 == 0
end

local function result(accepted: boolean, reasonId: string, snapshot: any?)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Snapshot = snapshot })
end

local function snapshot(): any?
	if activeRunId == nil or participantUserIds == nil then
		return nil
	end
	local copy = table.clone(participantUserIds)
	return table.freeze({
		Revision = revision,
		RunId = activeRunId,
		ParticipantCount = #copy,
		ParticipantUserIds = table.freeze(copy),
	})
end

function Service.bind(runId: string, userIds: { number }): any
	if type(runId) ~= "string" or #runId == 0 then
		return result(false, "InvalidRunId", snapshot())
	end
	if type(userIds) ~= "table" or #userIds == 0 then
		return result(false, "ParticipantsRequired", snapshot())
	end

	local seen = {}
	local normalized = {}
	for _, userId in userIds do
		if not validUserId(userId) then
			return result(false, "InvalidParticipantUserId", snapshot())
		end
		if not seen[userId] then
			seen[userId] = true
			table.insert(normalized, userId)
		end
	end
	table.sort(normalized)
	if #normalized == 0 then
		return result(false, "ParticipantsRequired", snapshot())
	end

	if activeRunId == runId and participantUserIds ~= nil then
		if #participantUserIds ~= #normalized then
			return result(false, "RunRosterConflict", snapshot())
		end
		for index, userId in normalized do
			if participantUserIds[index] ~= userId then
				return result(false, "RunRosterConflict", snapshot())
			end
		end
		return result(true, "RosterAlreadyBound", snapshot())
	end

	activeRunId = runId
	participantUserIds = normalized
	revision += 1
	return result(true, "RosterBound", snapshot())
end

function Service.read(runId: string): any?
	if activeRunId ~= runId then
		return nil
	end
	return snapshot()
end

function Service.clear(runId: string?): any
	if activeRunId == nil then
		return result(true, "RosterAlreadyClear", nil)
	end
	if runId ~= nil and runId ~= activeRunId then
		return result(false, "RunIdMismatch", snapshot())
	end
	activeRunId = nil
	participantUserIds = nil
	revision += 1
	return result(true, "RosterCleared", nil)
end

function Service.resetForTests()
	activeRunId = nil
	participantUserIds = nil
	revision = 0
end

return table.freeze(Service)
