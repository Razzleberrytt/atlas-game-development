--!strict

-- P10-0105 deterministic cleanup and replay. The lifecycle owner executes the
-- documented stop and start orders against each system's existing lifecycle,
-- exactly once per owner, and a replayed operation is a fresh run rather than a
-- resume.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local missionContracts =
	loadSimple("games/living-kingdoms/src/shared/Mission/MissionContracts.luau", "MissionContracts")
local lifeContracts =
	loadSimple("games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau", "OperativeLifeContracts")

local M_MISSION_TOKEN = {}
local M_LIFE_TOKEN = {}
local matchResultContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Mission/MatchResultContracts.luau"), {
		debugName = "MatchResultContracts",
		environment = {
			script = {
				Parent = {
					MissionContracts = M_MISSION_TOKEN,
					Parent = { Health = { OperativeLifeContracts = M_LIFE_TOKEN } },
				},
			},
			require = function(token: unknown)
				return if token == M_MISSION_TOKEN then missionContracts else lifeContracts
			end,
		},
		injectGlobals = true,
	})()

local CONTRACTS_TOKEN = {}
local matchResultConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/MatchResultConfig.luau"), {
	debugName = "MatchResultConfig",
	environment = {
		script = { Parent = { Parent = { Mission = { MatchResultContracts = CONTRACTS_TOKEN } } } },
		require = function()
			return matchResultContracts
		end,
	},
	injectGlobals = true,
})()

-- Every owner is a recorder: the fixture proves the sequence, not each system.
local calls: { string } = {}
local terminalListeners: { [number]: (causeId: string) -> () } = {}
local nextListenerId = 0

local function owner(name: string)
	return {
		start = function()
			table.insert(calls, name .. ".start")
		end,
		stop = function()
			table.insert(calls, name .. ".stop")
		end,
	}
end

local missionDirector = {
	start = function()
		table.insert(calls, "MissionDirector.start")
	end,
	stop = function()
		table.insert(calls, "MissionDirector.stop")
	end,
	resetObjectiveRuntime = function()
		table.insert(calls, "Objectives.reset")
	end,
	subscribeResolved = function(listener)
		nextListenerId += 1
		local listenerId = nextListenerId
		terminalListeners[listenerId] = listener
		return {
			Disconnect = function()
				terminalListeners[listenerId] = nil
			end,
		}
	end,
}

local TOKENS = {
	MatchResultConfig = {},
	MatchResultContracts = {},
	AmmunitionCacheService = {},
	ClassService = {},
	EnemyDirectorService = {},
	MatchResultService = {},
	MissionDirectorService = {},
	OperativeLifeService = {},
	OperativeReviveSessionService = {},
	SquadFailureService = {},
}
local modulesByToken = {
	[TOKENS.MatchResultConfig] = matchResultConfig,
	[TOKENS.MatchResultContracts] = matchResultContracts,
	[TOKENS.AmmunitionCacheService] = owner("AmmunitionCaches"),
	[TOKENS.ClassService] = owner("Classes"),
	[TOKENS.EnemyDirectorService] = owner("EnemyDirector"),
	[TOKENS.MatchResultService] = owner("ContributionRecord"),
	[TOKENS.MissionDirectorService] = missionDirector,
	[TOKENS.OperativeLifeService] = owner("OperativeLife"),
	[TOKENS.OperativeReviveSessionService] = owner("ReviveSessions"),
	[TOKENS.SquadFailureService] = owner("SquadFailure"),
}

local scheduled: { { delaySeconds: number, callback: () -> () } } = {}
local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau"), {
	debugName = "OperationLifecycleService",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "the lifecycle owner requires only replicated modules")
				return {
					Shared = {
						Config = { MatchResultConfig = TOKENS.MatchResultConfig },
						Mission = { MatchResultContracts = TOKENS.MatchResultContracts },
					},
				}
			end,
		},
		script = { Parent = TOKENS },
		require = function(token: unknown)
			local module = modulesByToken[token :: any]
			assertThat(module ~= nil, "unexpected OperationLifecycleService dependency")
			return module
		end,
		task = {
			delay = function(delaySeconds: number, callback: () -> ())
				local handle = { delaySeconds = delaySeconds, callback = callback }
				table.insert(scheduled, handle)
				return handle
			end,
			cancel = function() end,
		},
	},
	injectGlobals = true,
})()

local function fireResolved()
	for _, listener in terminalListeners do
		listener("Extracted")
	end
end

-- A stopped owner ignores everything.
fireResolved()
assertThat(#calls == 0, "a stopped lifecycle owner must not act")
assertThat(not service.replayNow(), "a stopped lifecycle owner must refuse a replay")

service.start()
assertThat(service.readReplayStateId() == "InProgress", "a running operation is in progress")
assertThat(service.readCompletedReplayCount() == 0, "no replay has completed yet")

-- Resolution schedules the debrief window rather than restarting immediately.
fireResolved()
assertThat(service.readReplayStateId() == "Resolved", "resolution moves the operation to Resolved")
assertThat(#calls == 0, "the squad must read the debrief before anything restarts")
assertThat(#scheduled == 1, "resolution must schedule exactly one replay")
assertThat(
	scheduled[1].delaySeconds == matchResultConfig.ReplayDebriefSeconds,
	"the debrief window must come from the shared configured value"
)

-- A second terminal notification cannot schedule a second replay.
fireResolved()
assertThat(#scheduled == 1, "a resolved operation must not schedule another replay")

scheduled[1].callback()
assertThat(service.readReplayStateId() == "InProgress", "a replayed operation is in progress again")
assertThat(service.readCompletedReplayCount() == 1, "the replay completed")

-- The stop order runs first, in the documented order, exactly once per owner;
-- then the start order, likewise.
local stopCalls = {}
local startCalls = {}
for _, call in calls do
	local name, action = string.match(call, "^(.+)%.(.+)$")
	if action == "stop" or action == "reset" then
		table.insert(stopCalls, name)
	else
		table.insert(startCalls, name)
	end
end
assertThat(
	#stopCalls == #matchResultConfig.CleanupStopOrder,
	"every declared cleanup owner must be stopped exactly once"
)
for index, ownerId in matchResultConfig.CleanupStopOrder do
	assertThat(stopCalls[index] == ownerId, "the stop order must follow the documented sequence at " .. tostring(index))
end
-- The objective runtime releases at its documented place, before the director
-- tears the rest of itself down last.
assertThat(
	(table.find(stopCalls, "Objectives") :: number) < (table.find(stopCalls, "MissionDirector") :: number),
	"objectives must stand down before the director tears itself down"
)
assertThat(stopCalls[1] == "EnemyDirector", "enemies and pressure stand down first")
assertThat(stopCalls[#stopCalls] == "MissionDirector", "the mission director tears itself down last")

-- The objective runtime returns with the director that owns it, so it is not a
-- separate start; every other owner starts exactly once, in order.
local expectedStarts = {}
for _, ownerId in matchResultConfig.ReplayStartOrder do
	if ownerId ~= "Objectives" then
		table.insert(expectedStarts, ownerId)
	end
end
assertThat(#startCalls == #expectedStarts, "every owner must restart exactly once")
for index, ownerId in expectedStarts do
	assertThat(
		startCalls[index] == ownerId,
		"the start order must follow the documented sequence at " .. tostring(index)
	)
end
assertThat(
	(table.find(startCalls, "OperativeLife") :: number) < (table.find(startCalls, "MissionDirector") :: number),
	"the life and roster owners must be running before the mission restarts"
)

-- The immediate server-only replay runs the same sequence.
table.clear(calls)
assertThat(service.replayNow(), "a running lifecycle owner performs an immediate replay")
assertThat(service.readCompletedReplayCount() == 2, "the immediate replay completed")
assertThat(#calls > 0, "the immediate replay must run the same documented sequence")

-- A scheduled replay cannot fire after teardown.
fireResolved()
local pending = scheduled[#scheduled]
service.stop()
pending.callback()
assertThat(service.readCompletedReplayCount() == 0, "teardown must release the pending replay")
assertThat(service.readReplayStateId() == "InProgress", "teardown resets the replay state")

-- Source audits: cleanup order lives in shared configuration, the owner holds no
-- gameplay state, and replay is server-driven.
local lifecycle = fs.readFile("games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau")
local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

assertThat(
	contains(lifecycle, "for _, ownerId in MatchResultConfig.CleanupStopOrder do")
		and contains(lifecycle, "for _, ownerId in MatchResultConfig.ReplayStartOrder do"),
	"the sequence must be driven by shared configuration, not hand-written here"
)
for _, forbidden in { "OnServerEvent", "FireServer", "InvokeServer", "RemoteEvent", "RemoteFunction" } do
	assertThat(not contains(lifecycle, forbidden), "replay must be server-driven: " .. forbidden)
end
assertThat(
	contains(lifecycle, "task.delay(MatchResultConfig.ReplayDebriefSeconds"),
	"the lifecycle owner must own exactly one configured replay timer"
)
assertThat(
	contains(lifecycle, "cancelScheduledReplay()") and contains(lifecycle, "terminalConnection:Disconnect()"),
	"teardown must release the timer and the subscription"
)

-- A replayed operation is a fresh run, never a resume.
assertThat(
	contains(mission, 'operationId = string.format("%s:run-%d", MissionConfig.OperationId, operationRunIndex)'),
	"every start must mint a fresh per-run operation identity"
)
assertThat(contains(mission, "operationRunIndex += 1"), "the run index must advance so a replay is a distinct result")
assertThat(
	not contains(mission, "operationId = MissionConfig.OperationId,"),
	"the published and recorded identity must be the per-run one"
)
assertThat(contains(bootstrap, "OperationLifecycleService.start()"), "the lifecycle owner must be bootstrapped")

print(
	"OperationLifecycleReplay: configuration-driven stop/start order, one replay timer, and fresh run identity passed"
)
