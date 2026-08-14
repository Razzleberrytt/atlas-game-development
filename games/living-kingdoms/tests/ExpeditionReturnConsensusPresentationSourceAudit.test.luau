--!strict

local fs = require("@lune/fs")
local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionReturnController.luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "return consensus presentation audit failed", 2)
	end
end
local function contains(token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

assert(
	contains("lobbyState.OnClientEvent:Connect(applyDecision)"),
	"return UI must reconcile server party-decision state"
)
assert(contains("decision.VotesByPlayerId[player.UserId]"), "return UI must derive own vote from server snapshot")
assert(contains("WAITING FOR SQUAD  %d/%d"), "return UI must expose quorum progress")
assert(contains('result.ReasonId == "AwaitingPartyReturn"'), "partial return consensus must remain visible")
assert(
	not contains("screen.Enabled = false\n\t\telse\n\t\t\treturnButton.Active"),
	"accepted partial vote must not be treated as completed teardown"
)

print("ExpeditionReturnConsensusPresentationSourceAudit.test.luau passed")
