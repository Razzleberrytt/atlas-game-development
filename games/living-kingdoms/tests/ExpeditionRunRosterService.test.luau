--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "run roster assertion failed", 2)
	end
end

local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRunRosterService.luau"), {
	debugName = "ExpeditionRunRosterService",
	injectGlobals = true,
})()

module.resetForTests()
assert(module.read("run-a") == nil, "unbound run should disclose no roster")
assert(not module.bind("", { 1 }).Accepted, "blank run id should fail")
assert(not module.bind("run-a", {}).Accepted, "empty roster should fail")
assert(not module.bind("run-a", { 0 }).Accepted, "invalid participant should fail")

local bound = module.bind("run-a", { 30, 10, 20, 10 })
assert(bound.Accepted and bound.ReasonId == "RosterBound", "valid roster should bind")
assert(bound.Snapshot.Revision == 1, "first bind should advance revision")
assert(bound.Snapshot.ParticipantCount == 3, "roster should deduplicate participants")
assert(
	bound.Snapshot.ParticipantUserIds[1] == 10 and bound.Snapshot.ParticipantUserIds[3] == 30,
	"roster should be deterministic"
)

local same = module.bind("run-a", { 20, 30, 10 })
assert(same.Accepted and same.ReasonId == "RosterAlreadyBound", "same run roster should be idempotent")
assert(same.Snapshot.Revision == 1, "idempotent bind must not advance revision")
assert(not module.bind("run-a", { 10, 20 }).Accepted, "same run id cannot be rebound to a different party")
assert(module.read("other-run") == nil, "roster must be scoped to exact run id")

local nextRun = module.bind("run-b", { 99 })
assert(nextRun.Accepted and nextRun.Snapshot.Revision == 2, "new run should replace prior active roster")
assert(module.read("run-a") == nil, "prior run should no longer be active")
assert(not module.clear("run-a").Accepted, "stale run cannot clear active roster")
assert(module.clear("run-b").Accepted, "active run may clear its roster")
assert(module.read("run-b") == nil, "cleared roster should disclose no state")

print("ExpeditionRunRosterService.test.luau passed")
