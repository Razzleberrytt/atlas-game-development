--!strict

-- Structural fixture for the live lobby boundary. Runtime execution remains a
-- Studio concern, but these assertions guard the allowed client action surface.

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")

local function assert(condition: unknown, message: string)
	if not condition then error(message, 2) end
end

assert(string.find(source, 'action == "Join"', 1, true) ~= nil, "join action should exist")
assert(string.find(source, 'action == "Leave"', 1, true) ~= nil, "leave action should exist")
assert(string.find(source, 'action == "SetReady"', 1, true) ~= nil, "ready action should exist")
assert(string.find(source, "player.UserId", 1, true) ~= nil, "requests must use invoking player identity")
assert(string.find(source, "startExpedition", 1, true) ~= nil, "authoritative launch should call live runtime")
assert(string.find(source, "consumeLaunch", 1, true) ~= nil, "launch should be consumed exactly once")
assert(string.find(source, "Seed =", 1, true) == nil, "clients must not supply expedition seeds through lobby")
assert(string.find(source, "RunId =", 1, true) == nil, "clients must not supply run IDs through lobby")

print("ExpeditionLobbyNetworkBoundary.test.luau passed")
