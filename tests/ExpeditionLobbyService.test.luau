--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "lobby assertion failed", 2) end
end

local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLobbyService.luau"), {
	debugName = "ExpeditionLobbyService",
	environment = {},
	injectGlobals = true,
})()

local lobby = module.new(1, 4)
assert(lobby:join(30).Accepted, "first player should join")
assert(lobby:join(10).Accepted and lobby:join(20).Accepted, "additional players should join")
assert(not lobby:join(10).Accepted, "duplicate join should fail")

local snapshot = lobby:readSnapshot()
assert(snapshot.MemberCount == 3, "three players should be present")
assert(snapshot.Members[1].PlayerId == 10 and snapshot.Members[3].PlayerId == 30, "members should be deterministic")
assert(not snapshot.AllReady, "lobby should not launch before readiness")

assert(lobby:setReady(10, true).Accepted, "player 10 should ready")
assert(lobby:setReady(20, true).Accepted, "player 20 should ready")
local finalReady = lobby:setReady(30, true)
assert(finalReady.Accepted and finalReady.Snapshot.AllReady and finalReady.Snapshot.LaunchPending, "all ready should arm launch")
assert(not lobby:join(40).Accepted, "membership must freeze while launch is pending")

local launch = lobby:consumeLaunch()
assert(launch.Accepted and launch.Snapshot.MemberCount == 3, "launch should consume frozen party")
assert(not lobby:consumeLaunch().Accepted, "launch cannot be consumed twice")
assert(not lobby:readSnapshot().AllReady, "ready state should reset after launch")

assert(lobby:leave(20).Accepted, "members should be removable")
assert(lobby:readSnapshot().MemberCount == 2, "leave should update count")

local bounded = module.new(1, 2)
assert(bounded:join(1).Accepted and bounded:join(2).Accepted, "bounded lobby should fill")
assert(not bounded:join(3).Accepted and bounded:join(3).ReasonId == "LobbyFull", "capacity should be enforced")

lobby:destroy()
assert(lobby:readSnapshot() == nil, "destroyed lobby should disclose no state")
print("ExpeditionLobbyService.test.luau passed")
