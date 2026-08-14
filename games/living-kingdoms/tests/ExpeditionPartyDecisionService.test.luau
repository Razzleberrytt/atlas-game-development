--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "party decision assertion failed", 2)
	end
end

local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionPartyDecisionService.luau"), {
	debugName = "ExpeditionPartyDecisionService",
	injectGlobals = true,
})()

local service = module.new({ 202, 101, 202 })
local initial = service:readSnapshot()
assert(initial.Revision == 0, "new party decision should begin at revision zero")
assert(initial.ParticipantCount == 2 and initial.ResolvedDecisionId == "Undecided", "participants should deduplicate")
assert(initial.ParticipantUserIds[1] == 101 and initial.ParticipantUserIds[2] == 202, "participants should be deterministic")
assert(not service:cast(999, "Replay").Accepted, "outsiders cannot vote")
assert(not service:cast(101, "Anything").Accepted, "invalid decisions fail")
local firstVote = service:cast(101, "Replay")
assert(firstVote.Accepted and firstVote.ReasonId == "VoteRecorded", "participant may vote")
local unchangedVote = service:cast(101, "Replay")
assert(unchangedVote.Accepted and unchangedVote.ReasonId == "VoteUnchanged", "same vote should be idempotent")
assert(unchangedVote.Snapshot.Revision == firstVote.Snapshot.Revision, "unchanged vote must not advance revision")
local split = service:cast(202, "ReturnToPreparation")
assert(split.Accepted and split.Snapshot.ResolvedDecisionId == "Undecided", "split vote remains unresolved")
local resolved = service:cast(202, "Replay")
assert(resolved.Accepted and resolved.ReasonId == "VoteChanged", "changing an existing vote should be explicit")
assert(resolved.Snapshot.Revision == 3 and resolved.Snapshot.ResolvedDecisionId == "Replay", "unanimous replay resolves")
assert(not service:removeParticipant(101).Accepted, "resolved decisions are immutable")
service:destroy()
assert(service:readSnapshot() == nil, "destroyed service discloses no state")

local disconnectService = module.new({ 3, 1, 2 })
disconnectService:cast(1, "Replay")
disconnectService:cast(2, "Replay")
local removed = disconnectService:removeParticipant(3)
assert(removed.Accepted and removed.Snapshot.ParticipantCount == 2, "disconnect should shrink active participant set")
assert(removed.ReasonId == "ResolvedAfterParticipantRemoved", "disconnect-driven resolution should be explicit")
assert(removed.Snapshot.Revision == 3, "disconnect should advance revision exactly once")
assert(removed.Snapshot.ParticipantUserIds[1] == 1 and removed.Snapshot.ParticipantUserIds[2] == 2, "disconnect snapshot should expose remaining participants")
assert(removed.Snapshot.ResolvedDecisionId == "Replay", "remaining unanimous votes should resolve")

local emptyService = module.new({ 10 })
local emptied = emptyService:removeParticipant(10)
assert(emptied.Accepted and emptied.ReasonId == "PartyEmpty", "last disconnect should report empty party")
assert(emptied.Snapshot.Revision == 1, "emptying the party should advance revision")
assert(emptied.Snapshot.ResolvedDecisionId == "Undecided", "empty party must not resolve accidentally")

local returnService = module.new({ 1, 2 })
returnService:cast(1, "ReturnToPreparation")
local returned = returnService:cast(2, "ReturnToPreparation")
assert(returned.Snapshot.ResolvedDecisionId == "ReturnToPreparation", "unanimous return resolves")

print("ExpeditionPartyDecisionService.test.luau passed")
