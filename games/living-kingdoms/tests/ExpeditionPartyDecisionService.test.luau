--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "party decision assertion failed", 2) end
end

local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionPartyDecisionService.luau"), {
	debugName = "ExpeditionPartyDecisionService",
	injectGlobals = true,
})()

local service = module.new({ 202, 101, 202 })
local initial = service:readSnapshot()
assert(initial.ParticipantCount == 2 and initial.ResolvedDecisionId == "Undecided", "participants should deduplicate")
assert(not service:cast(999, "Replay").Accepted, "outsiders cannot vote")
assert(not service:cast(101, "Anything").Accepted, "invalid decisions fail")
assert(service:cast(101, "Replay").Accepted, "participant may vote")
local split = service:cast(202, "ReturnToPreparation")
assert(split.Accepted and split.Snapshot.ResolvedDecisionId == "Undecided", "split vote remains unresolved")
local resolved = service:cast(202, "Replay")
assert(resolved.Accepted and resolved.Snapshot.ResolvedDecisionId == "Replay", "unanimous replay resolves")
assert(not service:cast(101, "ReturnToPreparation").Accepted, "resolved decisions are immutable")
service:destroy()
assert(service:readSnapshot() == nil, "destroyed service discloses no state")

local returnService = module.new({ 1, 2 })
returnService:cast(1, "ReturnToPreparation")
local returned = returnService:cast(2, "ReturnToPreparation")
assert(returned.Snapshot.ResolvedDecisionId == "ReturnToPreparation", "unanimous return resolves")

print("ExpeditionPartyDecisionService.test.luau passed")
