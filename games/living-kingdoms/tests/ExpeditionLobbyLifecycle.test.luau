--!strict

--[[
	Patch 0.8 Batch 1 lobby lifecycle.

	The lobby is the only thing that decides a party is launchable, so its state
	machine is the gate every co-op run passes through. The failure that matters
	is not a rejected join -- it is a lobby that ends up in a state from which no
	launch is possible, because that is indistinguishable from the game being
	broken.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local lobbyModule = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLobbyService.luau"), {
	debugName = "ExpeditionLobbyService",
	injectGlobals = true,
})()

local MINIMUM, MAXIMUM = 1, 4

local function newLobby(): any
	return lobbyModule.new(MINIMUM, MAXIMUM)
end

-- #4: membership across the bounded party size --------------------------------

local lobby = newLobby()
check(lobby:readSnapshot().MemberCount == 0, "a fresh lobby holds nobody")

for playerId = 101, 104 do
	local joined = lobby:join(playerId)
	check(joined.Accepted, "player " .. playerId .. " must join a lobby with room")
end
check(lobby:readSnapshot().MemberCount == MAXIMUM, "every joined member must be counted")

-- #8: a full party rejects further joins.
local overflow = lobby:join(105)
check(not overflow.Accepted and overflow.ReasonId == "LobbyFull", "a full lobby must refuse another member")
check(lobby:readSnapshot().MemberCount == MAXIMUM, "a refused join must not change membership")

local rejoin = lobby:join(101)
check(not rejoin.Accepted and rejoin.ReasonId == "AlreadyJoined", "a member must not be able to join twice")

check(lobby:leave(105).ReasonId == "PlayerNotJoined", "a non-member cannot leave")
check(lobby:leave(104).Accepted, "a member may leave")
check(lobby:readSnapshot().MemberCount == 3, "leaving must reduce membership")
check(lobby:join(105).Accepted, "a freed slot must be usable")

--[[
	Readiness is per member and the party is only launchable when everyone
	present is ready. A single unready member must hold the launch.
]]
local partial = newLobby()
check(partial:join(201).Accepted and partial:join(202).Accepted, "two members join")
check(partial:setReady(201, true).Accepted, "the first member readies")
check(not partial:readSnapshot().AllReady, "one ready member does not make a party ready")
check(not partial:readSnapshot().LaunchPending, "a partly ready party must not arm a launch")
check(partial:setReady(202, true).Accepted, "the second member readies")
check(partial:readSnapshot().AllReady, "an all-ready party is ready")
check(partial:readSnapshot().LaunchPending, "an all-ready party arms the launch")

-- #5: no second launch while one is in flight ---------------------------------

local firstConsume = partial:consumeLaunch()
check(firstConsume.Accepted and firstConsume.ReasonId == "LaunchConsumed", "the armed launch is consumed once")
check(firstConsume.Snapshot.MemberCount == 2, "the consumed launch must report the party it launched with")

local secondConsume = partial:consumeLaunch()
check(not secondConsume.Accepted, "a consumed launch must not be consumable twice")
check(secondConsume.ReasonId == "LaunchNotReady", "the second consume must say the launch is not armed")

-- #7: a consumed launch clears readiness so a stale ready cannot relaunch.
local afterConsume = partial:readSnapshot()
check(not afterConsume.LaunchPending, "a consumed launch must disarm")
check(not afterConsume.AllReady, "a consumed launch must clear readiness")
for _, member in afterConsume.Members do
	check(not member.Ready, "member " .. member.PlayerId .. " must not stay ready after a launch")
end

-- #9: readiness is refused while a launch is armed ----------------------------

local armed = newLobby()
check(armed:join(301).Accepted, "a solo member joins")
check(armed:setReady(301, true).Accepted, "the solo member readies")
check(armed:readSnapshot().LaunchPending, "a solo minimum party arms the launch")
check(not armed:setReady(301, false).Accepted, "readiness must not change while a launch is armed")
check(not armed:join(302).Accepted, "a member must not join while a launch is armed")

--[[
	#6: the case that can strand a lobby. A member leaving while the launch is
	armed disarms it, which is correct -- the party that armed it no longer
	exists. What must not happen is the lobby becoming permanently unlaunchable,
	so the remaining party has to be able to arm a launch again.
]]
local stranded = newLobby()
check(stranded:join(401).Accepted and stranded:join(402).Accepted, "two members join")
check(stranded:setReady(401, true).Accepted and stranded:setReady(402, true).Accepted, "both ready")
check(stranded:readSnapshot().LaunchPending, "the pair arms a launch")

check(stranded:leave(402).Accepted, "one member leaves while the launch is armed")
local afterLeave = stranded:readSnapshot()
check(not afterLeave.LaunchPending, "the departed party's launch must be disarmed")
check(afterLeave.MemberCount == 1, "the remaining member is still present")

--[[
	The remaining member is still marked ready from before, so re-arming has to
	be reachable. If it were not, this lobby would sit ready-but-unlaunchable
	forever with no way for a player to correct it.
]]
check(stranded:setReady(401, false).Accepted, "the remaining member may clear their readiness")
check(stranded:setReady(401, true).Accepted, "the remaining member may ready again")
check(stranded:readSnapshot().LaunchPending, "the remaining party must be able to arm a launch again")
check(stranded:consumeLaunch().Accepted, "the re-armed launch must be consumable")

-- Malformed input fails closed rather than corrupting membership --------------

local guarded = newLobby()
for _, invalid in { 0, -1, 1.5, "101" } do
	local refused = guarded:join(invalid :: any)
	check(not refused.Accepted and refused.ReasonId == "InvalidPlayerId", "a malformed player id must fail closed")
end
check(guarded:join(501).Accepted, "a valid member still joins after refusals")
check(not guarded:setReady(501, "yes" :: any).Accepted, "a malformed ready state must fail closed")
check(not guarded:setReady(999, true).Accepted, "a non-member cannot ready")
check(guarded:readSnapshot().MemberCount == 1, "refusals must not have changed membership")

-- A destroyed lobby refuses everything and discloses nothing.
guarded:destroy()
check(guarded:readSnapshot() == nil, "a destroyed lobby discloses no snapshot")
for _, outcome in
	{
		guarded:join(502),
		guarded:leave(501),
		guarded:setReady(501, true),
		guarded:consumeLaunch(),
	}
do
	check(not outcome.Accepted and outcome.ReasonId == "ServiceDestroyed", "a destroyed lobby refuses every request")
end

print("ExpeditionLobbyLifecycle: membership, readiness, launch arming, and no unlaunchable state")
