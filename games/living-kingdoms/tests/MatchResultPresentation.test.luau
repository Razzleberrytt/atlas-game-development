--!strict

-- P10-0104 part 2: the operation debrief. The client renders only the server's
-- validated result snapshot, requests nothing, and promises no XP, rank, unlock,
-- or replay that the server cannot honour.

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function count(source: string, token: string): number
	local total = 0
	local index = 1
	while true do
		local found = string.find(source, token, index, true)
		if found == nil then
			break
		end
		total += 1
		index = found + 1
	end
	return total
end

local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/MatchResultController.luau")
local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local bootstrapServer = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local bootstrapClient = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

-- The debrief is disclosure only: the mission owner accepts nothing, so the
-- result is pushed, never requested.
assertThat(
	contains(bootstrapServer, '{ "State", "Result" }'),
	"the mission network must carry the live snapshot and the one debrief"
)
for _, forbidden in { "OnServerEvent", "FireServer", "InvokeServer", "RemoteFunction" } do
	assertThat(not contains(mission, forbidden), "the mission owner must accept no client request: " .. forbidden)
	assertThat(not contains(controller, forbidden), "the debrief must send no client request: " .. forbidden)
end
assertThat(
	contains(mission, "resultRemote:FireAllClients(resultSnapshot)"),
	"resolution must disclose the frozen result"
)
assertThat(
	count(mission, "resultRemote:FireAllClients") == 1,
	"the debrief must be disclosed exactly once at resolution"
)
assertThat(
	contains(mission, "resultRemote:FireClient(player, frozenResult)"),
	"a client arriving after resolution must still be pushed the debrief"
)
assertThat(
	contains(mission, "local frozenResult = MatchResultService.readSafeResultSnapshot()"),
	"the join disclosure must read the frozen snapshot, not rebuild one"
)

-- Only a validated snapshot may render, and only once.
assertThat(
	contains(controller, "not MatchResultContracts.validateSafeMatchResultSnapshot(snapshot)"),
	"an unvalidated payload must never render"
)
assertThat(contains(controller, "if hasDisplayedResult or"), "the debrief must render exactly once per operation")
assertThat(count(controller, "OnClientEvent:Connect") == 1, "the debrief must use one disclosure connection")

-- Outcome and cause are carried by text, and every authored cause has plain
-- language rather than a raw identifier.
for _, causeId in { "Extracted", "SquadWipe", "Abandoned" } do
	assertThat(
		contains(controller, causeId .. ' = "'),
		"every authored cause needs a plain-language headline and explanation: " .. causeId
	)
end
assertThat(
	contains(controller, "EXTRACTION COMPLETE")
		and contains(controller, "SQUAD LOST")
		and contains(controller, "OPERATION ABANDONED"),
	"the outcome must read as plain language, not an identifier"
)

-- Key operation events and per-operative contribution facts are shown.
for _, field in
	{
		"result.durationSeconds",
		"result.phaseReachedId",
		"result.objectivesCompleted",
		"result.wavesSurvived",
		"result.bossDefeated",
	}
do
	assertThat(contains(controller, field), "the debrief must explain the key operation event: " .. field)
end
for _, field in
	{
		"contribution.kills",
		"contribution.damageDealt",
		"contribution.revivesPerformed",
		"contribution.objectivesContributed",
		"contribution.classActionsCommitted",
		"contribution.bossExposureHits",
	}
do
	assertThat(contains(controller, field), "the debrief must show the contribution fact: " .. field)
end
assertThat(
	contains(controller, "contribution.operativeEntityId == localOperativeEntityId"),
	"the operative must be able to find their own contribution"
)
assertThat(
	contains(controller, "SURVIVAL_TEXT_BY_STATE_ID"),
	"survival state must read as words rather than a raw life-state identifier"
)

-- No promise the server cannot honour. Rather than grepping prose -- the module
-- explains in comments that it shows none of these -- assert the two things that
-- would actually make a promise: reading an award field that does not exist, and
-- offering a control that does nothing.
for _, forbidden in { ".xp", ".rank", ".unlock", ".rewards", "awarded" } do
	assertThat(
		not contains(string.lower(controller), "result" .. forbidden)
			and not contains(string.lower(controller), "contribution" .. forbidden),
		"the debrief must read no award field off the snapshot: " .. forbidden
	)
end
assertThat(
	not contains(controller, "TextButton") and not contains(controller, "Activated"),
	"the debrief must offer no control: the server drives replay"
)
assertThat(
	contains(controller, "No rewards are recorded yet."),
	"the debrief must say plainly that nothing has been awarded"
)
assertThat(
	contains(controller, "MatchResultConfig.ReplayDebriefSeconds"),
	"the announced restart must come from the same configured window the server uses"
)

assertThat(contains(bootstrapClient, "MatchResultController.start()"), "the debrief must be bootstrapped")

print("MatchResultPresentation: push-only debrief, validated rendering, readable causes, and no false promises passed")
