--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "lobby assertion failed", 2)
	end
end

local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLobbyService.luau"), {
	debugName = "ExpeditionLobbyService",
	environment = {},
	injectGlobals = true,
})()

local lobby = module.new(1, 4)
assert(lobby:readSnapshot().Revision == 0, "new lobby should begin at revision zero")
assert(lobby:join(30).Accepted, "first player should join")
assert(lobby:join(10).Accepted and lobby:join(20).Accepted, "additional players should join")
local afterJoins = lobby:readSnapshot()
assert(afterJoins.Revision == 3, "each authoritative join should advance revision")
local duplicateJoin = lobby:join(10)
assert(not duplicateJoin.Accepted, "duplicate join should fail")
assert(duplicateJoin.Snapshot.Revision == afterJoins.Revision, "rejected join must not advance revision")

local snapshot = lobby:readSnapshot()
assert(snapshot.MemberCount == 3, "three players should be present")
assert(snapshot.Members[1].PlayerId == 10 and snapshot.Members[3].PlayerId == 30, "members should be deterministic")
assert(not snapshot.AllReady, "lobby should not launch before readiness")

local firstReady = lobby:setReady(10, true)
assert(firstReady.Accepted and firstReady.ReasonId == "PlayerReady", "player 10 should ready")
local repeatedReady = lobby:setReady(10, true)
assert(repeatedReady.Accepted and repeatedReady.ReasonId == "PlayerAlreadyReady", "same readiness should be idempotent")
assert(repeatedReady.Snapshot.Revision == firstReady.Snapshot.Revision, "idempotent readiness must not advance revision")
assert(lobby:setReady(20, true).Accepted, "player 20 should ready")
local finalReady = lobby:setReady(30, true)
assert(
	finalReady.Accepted and finalReady.Snapshot.AllReady and finalReady.Snapshot.LaunchPending,
	"all ready should arm launch"
)
assert(finalReady.Snapshot.Revision == 7, "final ready plus launch arming should both be observable state transitions")
assert(not lobby:join(40).Accepted, "membership must freeze while launch is pending")

local launch = lobby:consumeLaunch()
assert(launch.Accepted and launch.Snapshot.MemberCount == 3, "launch should consume frozen party")
assert(launch.Snapshot.LaunchPending, "consumed launch should preserve the exact launched snapshot")
assert(lobby:readSnapshot().Revision == launch.Snapshot.Revision + 1, "launch reset should advance authoritative revision")
assert(not lobby:consumeLaunch().Accepted, "launch cannot be consumed twice")
assert(not lobby:readSnapshot().AllReady, "ready state should reset after launch")

assert(lobby:leave(20).Accepted, "members should be removable")
assert(lobby:readSnapshot().MemberCount == 2, "leave should update count")

local reconnect = lobby:join(20)
assert(reconnect.Accepted and not reconnect.Snapshot.Members[2].Ready, "pre-launch reconnect should rejoin cleanly as unready")

local bounded = module.new(1, 2)
assert(bounded:join(1).Accepted and bounded:join(2).Accepted, "bounded lobby should fill")
assert(not bounded:join(3).Accepted and bounded:join(3).ReasonId == "LobbyFull", "capacity should be enforced")

lobby:destroy()
assert(lobby:readSnapshot() == nil, "destroyed lobby should disclose no state")
print("ExpeditionLobbyService.test.luau passed")
