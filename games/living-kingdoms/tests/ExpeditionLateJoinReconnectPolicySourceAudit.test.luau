--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "late join/reconnect policy source audit failed", 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local lobby = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")
local roster = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRunRosterService.luau")
local rewards = fs.readFile("games/living-kingdoms/src/server/expedition-reward-results.server.luau")

assert(
	contains(lobby, "local function activeRunParticipant(playerId: number): boolean"),
	"lobby needs a roster-backed reconnect predicate"
)
assert(
	contains(lobby, "ExpeditionRunRosterService.read(expedition.RunId)"),
	"reconnect eligibility must use the exact active run roster"
)
assert(contains(lobby, 'return response(false, "LateJoinClosed")'), "non-participant active-run joins must fail closed")
assert(
	contains(lobby, 'return response(false, "ActiveExpeditionMembershipLocked")'),
	"client-requested membership removal must be locked during an active run"
)
--[[
	This pinned a comment, which is the most brittle thing an audit can hold: the
	guarantee survives any rewording and the assertion did not. What matters is
	that disconnect has its own server-owned cleanup path, distinct from the
	client-requested removal that stays locked during an active run.
]]
local disconnectAt = string.find(lobby, "Players.PlayerRemoving:Connect(function(player)", 1, true)
assert(disconnectAt ~= nil, "disconnect must retain a distinct server-owned cleanup path")
assert(
	string.find(lobby, "lobby:leave(player.UserId)", disconnectAt, true) ~= nil,
	"the disconnect path must release lobby membership itself, not rely on the locked client path"
)
assert(not contains(roster, "PlayerRemoving"), "disconnect must never mutate the immutable run roster")
assert(
	contains(rewards, "ExpeditionRunRosterService.read(snapshot.RunId)"),
	"reward distribution must continue to consume the frozen roster"
)
assert(
	not contains(rewards, "Players:GetPlayers()"),
	"reward recipients must never be reconstructed from currently connected players"
)

print("ExpeditionLateJoinReconnectPolicySourceAudit.test.luau passed")
