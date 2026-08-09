--!strict

-- P10-0105 deterministic cleanup for deliberate replay. A terminal result holds
-- at Resolved until the server-owned lobby consumes a fresh launch; only then
-- does this owner execute the configured cleanup/start sequence.

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

local calls: { string } = {}
local terminalListeners: { [number]: (causeId: string) -> () } = {}
local nextListenerId = 0
local primaryCombatModeResetCount = 0
local operativeCombatResetCount = 0
local survivalLootResetCount = 0
local runBuildResetCount = 0
local runProgressionResetCount = 0

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

local operativeLife = owner("OperativeLife")
operativeLife.resetForReplay = function()
	table.insert(calls, "OperativeLife.resetForReplay")
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
	OperativeCombatRuntimeService = {},
	OperativeLifeService = {},
	PrimaryCombatModeService = {},
	RunBuildService = {},
	RunProgressionService = {},
	OperativeReviveSessionService = {},
	SquadFailureService = {},
	SurvivalLootService = {},
}
local modulesByToken = {
	[TOKENS.MatchResultConfig] = matchResultConfig,
	[TOKENS.MatchResultContracts] = matchResultContracts,
	[TOKENS.AmmunitionCacheService] = owner("AmmunitionCaches"),
	[TOKENS.ClassService] = owner("Classes"),
	[TOKENS.EnemyDirectorService] = owner("EnemyDirector"),
	[TOKENS.MatchResultService] = owner("ContributionRecord"),
	[TOKENS.MissionDirectorService] = missionDirector,
	[TOKENS.OperativeCombatRuntimeService] = {
		resetForReplay = function()
			operativeCombatResetCount += 1
		end,
	},
	[TOKENS.OperativeLifeService] = operativeLife,
	[TOKENS.PrimaryCombatModeService] = {
		resetAllToMelee = function()
			primaryCombatModeResetCount += 1
		end,
	},
	[TOKENS.RunBuildService] = {
		resetOperation = function()
			runBuildResetCount += 1
		end,
	},
	[TOKENS.RunProgressionService] = {
		resetOperation = function()
			runProgressionResetCount += 1
		end,
	},
	[TOKENS.OperativeReviveSessionService] = owner("ReviveSessions"),
	[TOKENS.SquadFailureService] = owner("SquadFailure"),
	[TOKENS.SurvivalLootService] = {
		resetForReplay = function()
			survivalLootResetCount += 1
		end,
	},
}

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
	},
	injectGlobals = true,
})()

local function fireResolved()
	for _, listener in terminalListeners do
		listener("Extracted")
	end
end

-- A stopped owner cannot prepare a launch.
fireResolved()
assertThat(#calls == 0, "a stopped lifecycle owner must not act")
assertThat(not service.prepareForLaunch(), "a stopped lifecycle owner must reject launch preparation")

service.start()
assertThat(service.readReplayStateId() == "InProgress", "a fresh server starts in the in-progress lifecycle state")
assertThat(service.readCompletedReplayCount() == 0, "no fresh-run reset has completed yet")

-- The first deliberate launch is already fresh; lifecycle preparation is a no-op.
assertThat(service.prepareForLaunch(), "the initial deliberate launch must be allowed")
assertThat(#calls == 0, "the initial launch must not tear down freshly booted owners")
assertThat(service.readCompletedReplayCount() == 0, "the initial launch is not a replay reset")
assertThat(primaryCombatModeResetCount == 0, "the initial launch must not reset primary combat mode")
assertThat(operativeCombatResetCount == 0, "the initial launch must not reset firearm runtime state")
assertThat(survivalLootResetCount == 0, "the initial launch must not reset survival loot")
assertThat(runBuildResetCount == 0, "the initial launch must not reset temporary run build power")
assertThat(runProgressionResetCount == 0, "the initial launch must not reset Field XP progression")

-- A terminal result now holds indefinitely at Resolved. No timer or automatic
-- restart may execute the cleanup/start sequence.
fireResolved()
assertThat(service.readReplayStateId() == "Resolved", "terminal resolution must hold at Resolved")
assertThat(#calls == 0, "resolution alone must never restart operation owners")
fireResolved()
assertThat(#calls == 0, "duplicate terminal notification must remain inert")

-- The next deliberate lobby launch prepares exactly one fresh operation.
assertThat(service.prepareForLaunch(), "a resolved operation must prepare for the next deliberate launch")
assertThat(service.readReplayStateId() == "InProgress", "prepared fresh state must return to InProgress")
assertThat(service.readCompletedReplayCount() == 1, "one deliberate replay reset must be recorded")
assertThat(primaryCombatModeResetCount == 1, "fresh replay must restore melee primary combat mode exactly once")
assertThat(operativeCombatResetCount == 1, "fresh replay must reset firearm runtime state exactly once")
assertThat(survivalLootResetCount == 1, "fresh replay must rebuild survival loot exactly once")
assertThat(runBuildResetCount == 1, "fresh replay must clear temporary run build power exactly once")
assertThat(runProgressionResetCount == 1, "fresh replay must clear Field XP progression exactly once")

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

local expectedStops = {}
for _, ownerId in matchResultConfig.CleanupStopOrder do
	if ownerId ~= "OperativeLife" then
		table.insert(expectedStops, ownerId)
	end
end
assertThat(#stopCalls == #expectedStops, "every operation-scoped cleanup owner must stop exactly once")
for index, ownerId in expectedStops do
	assertThat(stopCalls[index] == ownerId, "cleanup order must match configuration at " .. tostring(index))
end
assertThat(not table.find(calls, "OperativeLife.stop"), "fresh-run reset must preserve application life subscribers")
assertThat(not table.find(calls, "OperativeLife.start"), "fresh-run reset must not rebuild application life bindings")
assertThat(table.find(calls, "OperativeLife.resetForReplay") ~= nil, "operation life state must reset for a fresh run")
assertThat(stopCalls[1] == "EnemyDirector", "enemy pressure must stand down first")
assertThat(stopCalls[#stopCalls] == "MissionDirector", "the mission director must tear down last")

local expectedStarts = {}
for _, ownerId in matchResultConfig.ReplayStartOrder do
	if ownerId ~= "Objectives" then
		table.insert(expectedStarts, ownerId)
	end
end
assertThat(#startCalls == #expectedStarts, "every restart owner must start exactly once")
for index, ownerId in expectedStarts do
	assertThat(startCalls[index] == ownerId, "restart order must match configuration at " .. tostring(index))
end

-- Preparing again while already fresh is idempotent and does not rerun cleanup.
table.clear(calls)
assertThat(service.prepareForLaunch(), "an already-fresh lifecycle must allow the launch")
assertThat(#calls == 0, "an already-fresh lifecycle must not reset twice")
assertThat(service.readCompletedReplayCount() == 1, "idempotent launch preparation must not increment reset count")
assertThat(primaryCombatModeResetCount == 1, "idempotent launch preparation must not reset melee mode twice")
assertThat(operativeCombatResetCount == 1, "idempotent launch preparation must not reset firearm state twice")
assertThat(survivalLootResetCount == 1, "idempotent launch preparation must not rebuild survival loot twice")
assertThat(runBuildResetCount == 1, "idempotent launch preparation must not reset run build twice")
assertThat(runProgressionResetCount == 1, "idempotent launch preparation must not reset run progression twice")

-- Teardown releases the terminal subscription and refuses future preparation.
fireResolved()
assertThat(service.readReplayStateId() == "Resolved", "second terminal result must also hold")
service.stop()
assertThat(service.readCompletedReplayCount() == 0, "service teardown resets diagnostic count")
assertThat(service.readReplayStateId() == "InProgress", "service teardown resets lifecycle state")
assertThat(not service.prepareForLaunch(), "stopped lifecycle must refuse future launch preparation")

local lifecycle = fs.readFile("games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau")
local mission = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

assertThat(
	contains(lifecycle, "for _, ownerId in MatchResultConfig.CleanupStopOrder do")
		and contains(lifecycle, "for _, ownerId in MatchResultConfig.ReplayStartOrder do"),
	"fresh-run reset must remain configuration-driven"
)
assertThat(
	contains(lifecycle, "function OperationLifecycleService.prepareForLaunch()"),
	"lifecycle must expose launch preparation"
)
assertThat(not contains(lifecycle, "task.delay("), "terminal resolution must not schedule an automatic replay")
assertThat(not contains(lifecycle, "task.cancel("), "deliberate replay requires no replay timer cancellation")
for _, forbidden in { "OnServerEvent", "FireServer", "InvokeServer", "RemoteEvent", "RemoteFunction" } do
	assertThat(not contains(lifecycle, forbidden), "lifecycle preparation must remain server-only: " .. forbidden)
end
assertThat(
	contains(lifecycle, "OperativeLifeService.resetForReplay()")
		and not contains(lifecycle, "OperativeLifeService.stop()")
		and not contains(lifecycle, "OperativeLifeService.start()"),
	"fresh-run reset must preserve the application-scoped life binding owner"
)
assertThat(
	contains(lifecycle, "PrimaryCombatModeService.resetAllToMelee()")
		and contains(lifecycle, "OperativeCombatRuntimeService.resetForReplay()")
		and contains(lifecycle, "SurvivalLootService.resetForReplay()")
		and contains(lifecycle, "RunBuildService.resetOperation()")
		and contains(lifecycle, "RunProgressionService.resetOperation()"),
	"fresh-run replay must reset opening state and all temporary run power"
)

assertThat(
	contains(mission, 'operationId = string.format("%s:run-%d", MissionConfig.OperationId, operationRunIndex)'),
	"every mission start must mint a fresh per-run operation identity"
)
assertThat(contains(mission, "operationRunIndex += 1"), "the run index must advance for each fresh operation")
assertThat(not contains(mission, "operationId = MissionConfig.OperationId,"), "published identity must remain per-run")
assertThat(contains(bootstrap, "OperationLifecycleService.start()"), "the lifecycle owner must remain bootstrapped")

print("OperationLifecycleReplay: resolved hold, deliberate preparation, cleanup order, and fresh identity passed")
