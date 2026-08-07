--!strict

local fs = require("@lune/fs")

local server = fs.readFile("games/living-kingdoms/src/server/expedition-replay-decision.server.luau")
local client = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionReplayDecisionController.luau")

assert(string.find(server, "player.UserId", 1, true), "server must derive voter identity from invoking player")
assert(string.find(server, "startExpedition", 1, true), "server owns replay launch")
assert(string.find(server, "stopExpedition", 1, true), "server owns terminal cleanup")
assert(not string.find(client, "PartySize", 1, true), "client must not choose party size")
assert(not string.find(client, "Seed", 1, true), "client must not choose seed")
assert(not string.find(client, "RunId", 1, true), "client must not choose run id")

print("ExpeditionReplayDecisionAuthority.test.luau passed")
