--!strict

-- Server-owned terminal party decision. Every active frozen participant may cast
-- one current vote; the party resolves only when all remaining participants agree.
-- Snapshots carry a monotonic Revision and deterministic ParticipantUserIds so
-- clients can reconcile disconnect-driven state changes without guessing.

export type Service = {
	cast: (self: Service, playerId: number, decisionId: string) -> any,
	removeParticipant: (self: Service, playerId: number) -> any,
	readSnapshot: (self: Service) -> any,
	destroy: (self: Service) -> (),
}

local VALID = { Replay = true, ReturnToPreparation = true }
local Service = {}
Service.__index = Service

local function advanceRevision(selfAny: any)
	selfAny._revision += 1
end

local function snapshot(selfAny: any): any
	local votes = {}
	local participantUserIds = {}
	local replay = 0
	local returned = 0
	for _, playerId in selfAny._participants do
		table.insert(participantUserIds, playerId)
	end
	for playerId, decisionId in selfAny._votes do
		votes[playerId] = decisionId
		if decisionId == "Replay" then
			replay += 1
		else
			returned += 1
		end
	end
	local participantCount = #selfAny._participants
	local resolved = "Undecided"
	if participantCount > 0 and replay == participantCount then
		resolved = "Replay"
	end
	if participantCount > 0 and returned == participantCount then
		resolved = "ReturnToPreparation"
	end
	return table.freeze({
		Revision = selfAny._revision,
		ParticipantCount = participantCount,
		ParticipantUserIds = table.freeze(participantUserIds),
		VoteCount = replay + returned,
		ReplayVotes = replay,
		ReturnVotes = returned,
		ResolvedDecisionId = resolved,
		VotesByPlayerId = table.freeze(votes),
	})
end

local function result(accepted: boolean, reasonId: string, current: any)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Snapshot = current })
end

function Service.new(participantUserIds: { number }): Service
	assert(type(participantUserIds) == "table" and #participantUserIds >= 1, "participants required")
	local seen = {}
	local participants = {}
	for _, playerId in participantUserIds do
		assert(type(playerId) == "number" and playerId > 0 and playerId % 1 == 0, "invalid participant")
		if not seen[playerId] then
			seen[playerId] = true
			table.insert(participants, playerId)
		end
	end
	table.sort(participants)
	return setmetatable(
		{ _participants = participants, _participantSet = seen, _votes = {}, _revision = 0, _destroyed = false },
		Service
	) :: any
end

function Service:cast(playerId: number, decisionId: string): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end
	if not selfAny._participantSet[playerId] then
		return result(false, "NotParticipant", snapshot(selfAny))
	end
	if not VALID[decisionId] then
		return result(false, "InvalidDecision", snapshot(selfAny))
	end
	if snapshot(selfAny).ResolvedDecisionId ~= "Undecided" then
		return result(false, "DecisionResolved", snapshot(selfAny))
	end
	local previousDecisionId = selfAny._votes[playerId]
	if previousDecisionId == decisionId then
		return result(true, "VoteUnchanged", snapshot(selfAny))
	end
	selfAny._votes[playerId] = decisionId
	advanceRevision(selfAny)
	return result(true, if previousDecisionId == nil then "VoteRecorded" else "VoteChanged", snapshot(selfAny))
end

function Service:removeParticipant(playerId: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end
	if not selfAny._participantSet[playerId] then
		return result(false, "NotParticipant", snapshot(selfAny))
	end
	if snapshot(selfAny).ResolvedDecisionId ~= "Undecided" then
		return result(false, "DecisionResolved", snapshot(selfAny))
	end
	selfAny._participantSet[playerId] = nil
	selfAny._votes[playerId] = nil
	for index, existingId in selfAny._participants do
		if existingId == playerId then
			table.remove(selfAny._participants, index)
			break
		end
	end
	advanceRevision(selfAny)
	local current = snapshot(selfAny)
	if current.ParticipantCount == 0 then
		return result(true, "PartyEmpty", current)
	end
	if current.ResolvedDecisionId ~= "Undecided" then
		return result(true, "ResolvedAfterParticipantRemoved", current)
	end
	return result(true, "ParticipantRemoved", current)
end

function Service:readSnapshot(): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return nil
	end
	return snapshot(selfAny)
end

function Service:destroy()
	local selfAny = self :: any
	if selfAny._destroyed then
		return
	end
	selfAny._destroyed = true
	table.clear(selfAny._votes)
	table.clear(selfAny._participants)
	table.clear(selfAny._participantSet)
end

return table.freeze(Service)
