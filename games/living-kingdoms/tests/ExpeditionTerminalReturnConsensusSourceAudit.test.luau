--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "terminal return consensus source audit failed", 2)
	end
end

local source = fs.readFile("games/living-kingdoms/src/server/expedition-lobby.server.luau")

local function contains(token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

assert(contains("require(Systems.ExpeditionPartyDecisionService)"), "return flow must reuse the canonical party decision owner")
assert(contains("ExpeditionRunRosterService.read(expedition.RunId)"), "return quorum must derive from the frozen run roster")
assert(contains("decision:cast(player.UserId, \"ReturnToPreparation\")"), "client return intent must become a server-owned vote")
assert(contains("ResolvedDecisionId ~= \"ReturnToPreparation\""), "run teardown must wait for resolved return consensus")
assert(contains("\"AwaitingPartyReturn\""), "partial consensus must be explicit")
assert(contains("terminalDecision:removeParticipant(player.UserId)"), "disconnect must not leave a dead voter blocking the party")
assert(not contains("local stopped = ExpeditionLiveRuntimeService.stopExpedition(\"ReturnedToLobby\")\n\tif stopped.Accepted ~= true then\n\t\treturn response(false, stopped.ReasonId)\n\tend\n\tbroadcast()"), "a single return request must not directly stop the run")

print("ExpeditionTerminalReturnConsensusSourceAudit.test.luau passed")
