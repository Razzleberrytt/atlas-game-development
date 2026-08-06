--!strict

-- Server-owned terminal party decision. Every frozen participant may cast one
-- current vote; the party resolves only when all participants agree.

export type Service = {
	cast: (self: Service, playerId: number, decisionId: string) -> any,
	readSnapshot: (self: Service) -> any,
	destroy: (self: Service) -> (),
}

local VALID = { Replay = true, ReturnToPreparation = true }
local Service = {}
Service.__index = Service

local function snapshot(selfAny: any): any
	local votes = {}
	local replay = 0
	local returned = 0
	for playerId, decisionId in selfAny._votes do
		votes[playerId] = decisionId
		if decisionId == "Replay" then replay += 1 else returned += 1 end
	end
	local resolved = "Undecided"
	if replay == #selfAny._participants then resolved = "Replay" end
	if returned == #selfAny._participants then resolved = "ReturnToPreparation" end
	return table.freeze({
		ParticipantCount = #selfAny._participants,
		VoteCount = replay + returned,
		ReplayVotes = replay,
		ReturnVotes = returned,
		ResolvedDecisionId = resolved,
		VotesByPlayerId = table.freeze(votes),
	})
end

function Service.new(participantUserIds: { number }): Service
	assert(type(participantUserIds) == "table" and #participantUserIds >= 1, "participants required")
	local seen = {}
	local participants = {}
	for _, playerId in participantUserIds do
		assert(type(playerId) == "number" and playerId > 0 and playerId % 1 == 0, "invalid participant")
		if not seen[playerId] then seen[playerId] = true; table.insert(participants, playerId) end
	end
	table.sort(participants)
	return setmetatable({ _participants = participants, _participantSet = seen, _votes = {}, _destroyed = false }, Service) :: any
end

function Service:cast(playerId: number, decisionId: string): any
	local selfAny = self :: any
	if selfAny._destroyed then return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Snapshot = nil }) end
	if not selfAny._participantSet[playerId] then return table.freeze({ Accepted = false, ReasonId = "NotParticipant", Snapshot = snapshot(selfAny) }) end
	if not VALID[decisionId] then return table.freeze({ Accepted = false, ReasonId = "InvalidDecision", Snapshot = snapshot(selfAny) }) end
	if snapshot(selfAny).ResolvedDecisionId ~= "Undecided" then return table.freeze({ Accepted = false, ReasonId = "DecisionResolved", Snapshot = snapshot(selfAny) }) end
	selfAny._votes[playerId] = decisionId
	return table.freeze({ Accepted = true, ReasonId = "VoteRecorded", Snapshot = snapshot(selfAny) })
end

function Service:readSnapshot(): any
	local selfAny = self :: any
	if selfAny._destroyed then return nil end
	return snapshot(selfAny)
end

function Service:destroy()
	local selfAny = self :: any
	if selfAny._destroyed then return end
	selfAny._destroyed = true
	table.clear(selfAny._votes)
end

return table.freeze(Service)
