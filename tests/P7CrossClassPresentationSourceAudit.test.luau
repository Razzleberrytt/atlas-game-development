--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local squad = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassSquadPresentationController.luau")
local owner = fs.readFile("games/living-kingdoms/src/client/Controllers/ClassActionController.luau")
local resolver = fs.readFile("games/living-kingdoms/src/shared/Classes/ClassPresentationResolver.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local combined = squad .. "\n" .. owner .. "\n" .. resolver

assertThat(string.find(squad, 'WaitForChild("State")', 1, true) ~= nil, "reuse safe class state remote")
assertThat(string.find(squad, 'WaitForChild("ReadState")', 1, true) ~= nil, "reuse safe initial snapshot")
assertThat(string.find(squad, "validateSafeClassSelectionSnapshot", 1, true) ~= nil, "validate every snapshot")
assertThat(string.find(squad, "BillboardGui", 1, true) ~= nil, "teammate world cue required")
assertThat(string.find(squad, "MaxDistance = 72", 1, true) ~= nil, "world cue range must be bounded")
assertThat(string.find(squad, "removeCue", 1, true) ~= nil, "character/rejoin cleanup required")
assertThat(string.find(squad, ":Disconnect()", 1, true) ~= nil, "connection cleanup required")
assertThat(not string.find(squad, "FireServer", 1, true), "presentation must submit no authority")
assertThat(not string.find(squad, 'Instance.new("RemoteEvent")', 1, true), "presentation must create no network")
assertThat(string.find(owner, "resourceLabel", 1, true) ~= nil, "owner resources must be explicit")
assertThat(string.find(owner, "READY IN", 1, true) == nil, "countdown copy belongs to pure resolver")
assertThat(string.find(owner, "task.wait(0.1)", 1, true) ~= nil, "owner countdown must use one bounded 10 Hz task")
assertThat(
	string.find(owner, "lifecycleGeneration", 1, true) ~= nil,
	"countdown task must stop across lifecycle changes"
)
assertThat(string.find(resolver, "READY IN %.1fs", 1, true) ~= nil, "numeric cooldown copy required")
for _, token in { "[SHIELD]", "[CROSS]", "[TOOL]", "roleSummary", "actionLabel" } do
	assertThat(string.find(combined, token, 1, true) ~= nil, "redundant cue missing " .. token)
end
assertThat(
	string.find(bootstrap, "ClassSquadPresentationController.start()", 1, true) ~= nil,
	"cross-class presentation must start in production"
)

print("P7-0106 source audit: safe squad identity, action cues, owner disclosure, accessibility, and cleanup passed")
