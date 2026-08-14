--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "Patch 0.8 acceptance audit failed", 2) end
end
local function read(path: string): string
	assert(fs.isFile(path), "missing Patch 0.8 authority: " .. path)
	return fs.readFile(path)
end
local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local acceptance = read("docs/roadmap/PATCH-0.8-ACCEPTANCE.md")
local lobby = read("games/living-kingdoms/src/server/expedition-lobby.server.luau")
local roster = read("games/living-kingdoms/src/server/Systems/ExpeditionRunRosterService.luau")
local partyDecision = read("games/living-kingdoms/src/server/Systems/ExpeditionPartyDecisionService.luau")
local ping = read("games/living-kingdoms/src/server/Systems/SquadPingService.luau")
local revive = read("games/living-kingdoms/src/server/Systems/OperativeReviveSessionService.luau")
local returnUi = read("games/living-kingdoms/src/client/Controllers/ExpeditionReturnController.luau")

assert(contains(acceptance, "SOURCE COMPLETE — CONSOLIDATED STUDIO/DEVICE VERIFICATION PENDING"), "acceptance must not claim runtime verification")
assert(contains(lobby, "LateJoinClosed"), "late join policy missing")
assert(contains(lobby, "activeRunParticipant(player.UserId)"), "reconnect must use frozen participant identity")
assert(contains(roster, "RunRosterConflict"), "run roster must reject identity conflicts")
assert(contains(partyDecision, "ResolvedAfterParticipantRemoved"), "party decision must reconcile disconnects")
assert(contains(lobby, "decision:cast(player.UserId, \"ReturnToPreparation\")"), "terminal return must use party decision")
assert(contains(returnUi, "WAITING FOR SQUAD  %d/%d"), "return quorum must be visible")
assert(contains(ping, "publishedCategoryFor(player)"), "squad ping must remain server-owned")
assert(contains(ping, "publishSquads"), "squad ping recipients must remain squad-scoped")
assert(contains(revive, "distanceAndLineOfSight"), "revive validity must remain server-derived")
assert(contains(revive, "hasDamageChanged"), "revive interruption must remain server-derived")

print("Patch08AcceptanceSourceAudit.test.luau passed")
