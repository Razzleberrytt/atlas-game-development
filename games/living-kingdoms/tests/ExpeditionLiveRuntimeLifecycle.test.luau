--!strict

--[[
	Patch 0.6 live-runtime lifecycle fixture.

	The live runtime owns the launch validation boundary (seed, party size, run
	id) and the single-active-expedition rule. Every gate before this fixture was
	a source audit, so a regression that widened a bound or dropped the
	already-active guard would have passed CI. This exercises the real service
	against stubbed collaborators instead.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function loadPure(path: string, debugName: string): any
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/" .. path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadPure("Expeditions/ExpeditionContracts.luau", "ExpeditionContracts")
local debugSchema = loadPure("Expeditions/RunVariationDebugSchema.luau", "RunVariationDebugSchema")

local CONTRACTS_TOKEN = {}
local expeditionConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/ExpeditionConfig.luau"), {
	debugName = "ExpeditionConfig",
	environment = {
		script = { Parent = { Parent = { Expeditions = { ExpeditionContracts = CONTRACTS_TOKEN } } } },
		require = function(): any
			return contracts
		end,
	},
	injectGlobals = true,
})()

local limits = expeditionConfig.RuntimeLimits
local definition = expeditionConfig.Definitions.FirstExpedition

-- Stubbed collaborators ------------------------------------------------------

local createdBootstrapCount = 0
local destroyedBootstrapCount = 0
local steppedCount = 0
local placementAccepted = true
local barrierResetCount = 0
local placementDestroyCount = 0

local function newRoomPlan(seed: number): any
	return {
		Seed = seed,
		PlanIdentity = "room-plan|" .. tostring(seed),
		Nodes = {
			{ Index = 1, RoomId = "entry", Role = "Entry" },
			{ Index = 2, RoomId = "warden-barracks", Role = "Combat" },
			{ Index = 3, RoomId = "keeper-core", Role = "Boss" },
		},
	}
end

local bootstrapStub = {
	new = function(_director: any, options: any): any
		createdBootstrapCount += 1
		local roomPlan = newRoomPlan(options.Seed)
		local snapshot = {
			RunId = options.RunId,
			Seed = options.Seed,
			PartySize = options.PartySize,
			PhaseId = contracts.PhaseIds.Approach,
			OutcomeId = contracts.OutcomeIds.InProgress,
			SecretDiscovered = false,
		}
		return {
			Runtime = nil,
			Coordinator = nil,
			CombatAdapter = nil,
			getRoomPlan = function(): any
				return roomPlan
			end,
			getSnapshot = function(): any
				return snapshot
			end,
			getActiveEncounterContext = function(): any
				return nil
			end,
			step = function(): any
				steppedCount += 1
				return { Accepted = false, ReasonId = "PhaseMinimumDuration" }
			end,
			destroy = function()
				destroyedBootstrapCount += 1
			end,
		}
	end,
}

local placementStub = {
	place = function(): any
		if placementAccepted then
			return { Accepted = true, ReasonId = "RoomsPlaced" }
		end
		return { Accepted = false, ReasonId = "RoomPlacementFailed" }
	end,
	destroy = function()
		placementDestroyCount += 1
	end,
}

local barrierStub = {
	reset = function()
		barrierResetCount += 1
	end,
	update = function() end,
}

local variationPlannerStub = {
	plan = function(roomPlan: any): any
		return {
			Seed = roomPlan.Seed,
			RoomPlanIdentity = roomPlan.PlanIdentity,
			VariationIdentity = "variation|" .. roomPlan.PlanIdentity,
			SecretBranch = nil,
			OptionalObjective = nil,
			RunModifier = nil,
		}
	end,
}

local encounterViewStub = {
	build = function(roomPlan: any): any
		return { Seed = roomPlan.Seed, Records = {} }
	end,
}

local compositionReadbackStub = {
	build = function(roomPlan: any): any
		return {
			Seed = roomPlan.Seed,
			RoomPlanIdentity = roomPlan.PlanIdentity,
			RunModifierId = nil,
			CompositionIdentity = "composition|" .. roomPlan.PlanIdentity,
		}
	end,
}

local heartbeatCallback: ((number) -> ())? = nil
local heartbeatConnectCount = 0
local heartbeatDisconnectCount = 0
local connectedPlayers = { {} }
local studioMode = false

-- Module environment ---------------------------------------------------------

local tokens = {}
local function token(name: string): any
	local value = {}
	tokens[value] = name
	return value
end

local replicatedStorage = {
	Shared = {
		Config = {
			ExpeditionConfig = token("ExpeditionConfig"),
			FirstDungeonRewardDecisionConfig = token("FirstDungeonRewardDecisionConfig"),
		},
		Expeditions = {
			ExpeditionContracts = token("ExpeditionContracts"),
			RunVariationPlanner = token("RunVariationPlanner"),
			RunVariationEncounterView = token("RunVariationEncounterView"),
			RunVariationCompositionDebugReadback = token("RunVariationCompositionDebugReadback"),
			RunVariationDebugSchema = token("RunVariationDebugSchema"),
		},
	},
}

local scriptParent = {
	ExpeditionServerBootstrap = token("ExpeditionServerBootstrap"),
	ExpeditionRoomPlacementService = token("ExpeditionRoomPlacementService"),
	ExpeditionRoomBarrierStateService = token("ExpeditionRoomBarrierStateService"),
	ExpeditionBossRewardTransitionResolver = token("ExpeditionBossRewardTransitionResolver"),
	EnemyDirectorService = token("EnemyDirectorService"),
	RunBuildService = token("RunBuildService"),
}

local moduleByName: { [string]: any } = {
	ExpeditionConfig = expeditionConfig,
	FirstDungeonRewardDecisionConfig = { DecisionByRoomId = { ["keeper-core"] = { DecisionId = "keeper-core" } } },
	ExpeditionContracts = contracts,
	RunVariationPlanner = variationPlannerStub,
	RunVariationEncounterView = encounterViewStub,
	RunVariationCompositionDebugReadback = compositionReadbackStub,
	RunVariationDebugSchema = debugSchema,
	ExpeditionServerBootstrap = bootstrapStub,
	ExpeditionRoomPlacementService = placementStub,
	ExpeditionRoomBarrierStateService = barrierStub,
	ExpeditionBossRewardTransitionResolver = {
		resolve = function(): any
			return nil
		end,
	},
	EnemyDirectorService = { Name = "EnemyDirectorService" },
	RunBuildService = {
		offerRelicRewardToParticipants = function() end,
	},
}

local services: { [string]: any } = {
	ReplicatedStorage = replicatedStorage,
	HttpService = {
		GenerateGUID = function(): string
			return "0123456789abcdef0123456789abcdef"
		end,
	},
	Players = {
		GetPlayers = function(): { any }
			return connectedPlayers
		end,
	},
	RunService = {
		IsStudio = function(): boolean
			return studioMode
		end,
		Heartbeat = {
			Connect = function(_self: any, callback: (number) -> ()): any
				heartbeatConnectCount += 1
				heartbeatCallback = callback
				return {
					Disconnect = function()
						heartbeatDisconnectCount += 1
						heartbeatCallback = nil
					end,
				}
			end,
		},
	},
}

local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLiveRuntimeService.luau"), {
	debugName = "ExpeditionLiveRuntimeService",
	environment = {
		script = { Parent = scriptParent },
		game = {
			GetService = function(_self: any, name: string): any
				local found = services[name]
				if found == nil then
					error("unexpected service request: " .. name)
				end
				return found
			end,
		},
		workspace = {
			GetServerTimeNow = function(): number
				return 1_700_000_000
			end,
		},
		warn = function() end,
		require = function(value: any): any
			local name = tokens[value]
			if name == nil then
				error("unexpected live runtime dependency")
			end
			return moduleByName[name]
		end,
	},
	injectGlobals = true,
})()

-- Service-stopped boundary ---------------------------------------------------

check(service.startExpedition({ Seed = 5 }).ReasonId == "ServiceStopped", "a stopped service must refuse launches")

service.start()
check(heartbeatConnectCount == 1, "starting the service must bind exactly one heartbeat")

-- Rank 81: seed boundary fixtures --------------------------------------------

local function startWith(options: any): any
	return service.startExpedition(options)
end

local function stopIfActive()
	service.stopExpedition("FixtureReset")
end

local function mustRejectStart(options: any, expectedReasonId: string, message: string)
	local outcome = startWith(options)
	check(outcome.Accepted == false, message)
	check(outcome.ReasonId == expectedReasonId, message .. " (reason " .. tostring(outcome.ReasonId) .. ")")
	local failure = service.readLastStartFailure()
	check(failure ~= nil and failure.ReasonId == expectedReasonId, message .. " must record a start failure")
end

local function mustAcceptStart(options: any, message: string)
	local outcome = startWith(options)
	check(outcome.Accepted == true and outcome.ReasonId == "ExpeditionStarted", message)
	check(service.readLastStartFailure() == nil, message .. " must clear the last start failure")
	stopIfActive()
end

mustAcceptStart({ Seed = limits.MinimumSeed }, "the minimum seed must launch")
mustAcceptStart({ Seed = limits.MaximumSeed }, "the maximum seed must launch")
mustRejectStart({ Seed = limits.MinimumSeed - 1 }, "InvalidSeed", "a seed below the minimum must fail closed")
mustRejectStart({ Seed = limits.MaximumSeed + 1 }, "InvalidSeed", "a seed above the maximum must fail closed")
mustRejectStart({ Seed = 12.5 }, "InvalidSeed", "a fractional seed must fail closed")
mustRejectStart({ Seed = 0 / 0 }, "InvalidSeed", "a non-numeric seed must fail closed")
mustRejectStart({ Seed = "421337" }, "InvalidSeed", "a string seed must fail closed")

check(createdBootstrapCount == 2, "a rejected launch must never construct an expedition")

-- Rank 82: party-size boundary fixtures --------------------------------------

mustAcceptStart({ Seed = 421337, PartySize = definition.MinimumPlayers }, "the minimum party size must launch")
mustAcceptStart({ Seed = 421337, PartySize = definition.MaximumPlayers }, "the maximum party size must launch")
mustRejectStart(
	{ Seed = 421337, PartySize = definition.MinimumPlayers - 1 },
	"InvalidPartySize",
	"a party below the minimum must fail closed"
)
mustRejectStart(
	{ Seed = 421337, PartySize = definition.MaximumPlayers + 1 },
	"InvalidPartySize",
	"a party above the maximum must fail closed"
)
mustRejectStart({ Seed = 421337, PartySize = 2.5 }, "InvalidPartySize", "a fractional party size must fail closed")
mustRejectStart({ Seed = 421337, PartySize = "2" }, "InvalidPartySize", "a string party size must fail closed")

connectedPlayers = { {}, {}, {}, {}, {}, {} }
local overflowParty = startWith({ Seed = 421337 })
check(overflowParty.Accepted == true, "a lobby larger than the definition must clamp instead of failing")
check(overflowParty.Snapshot.PartySize == definition.MaximumPlayers, "the clamped party must respect the maximum")
stopIfActive()
connectedPlayers = { {} }

mustRejectStart({ Seed = 421337, RunId = "short" }, "InvalidRunId", "an undersized run id must fail closed")
mustRejectStart({ Seed = 421337, RunId = string.rep("x", 97) }, "InvalidRunId", "an oversized run id must fail closed")
mustRejectStart({ Seed = 421337, RunId = "   " }, "InvalidRunId", "a whitespace-only run id must fail closed")

-- Rank 83: repeated start idempotency ----------------------------------------

local createdBefore = createdBootstrapCount
local first = startWith({ Seed = 777, RunId = "expedition:first-run" })
check(first.Accepted == true, "the first launch must be accepted")
check(createdBootstrapCount == createdBefore + 1, "the first launch must construct exactly one expedition")

local second = startWith({ Seed = 888, RunId = "expedition:second-run" })
check(second.Accepted == false and second.ReasonId == "ExpeditionAlreadyActive", "a repeated launch must be refused")
check(createdBootstrapCount == createdBefore + 1, "a refused repeat launch must not construct a second expedition")
check(
	second.Snapshot ~= nil and second.Snapshot.RunId == "expedition:first-run",
	"the refusal must report the active run"
)
check(service.readSnapshot().Seed == 777, "a refused repeat launch must not replace the active run")
check(service.readRunVariationPlan() ~= nil, "a refused repeat launch must not clear active variation state")

local destroyedBefore = destroyedBootstrapCount
local placementDestroyBefore = placementDestroyCount
local third = startWith({ Seed = 777, RunId = "expedition:first-run" })
check(
	third.Accepted == false and third.ReasonId == "ExpeditionAlreadyActive",
	"relaunching the identical run must still be refused"
)
check(createdBootstrapCount == createdBefore + 1, "an identical repeat launch must not construct a second expedition")
check(destroyedBootstrapCount == destroyedBefore, "a refused repeat launch must not destroy the active expedition")
check(placementDestroyCount == placementDestroyBefore, "a refused repeat launch must not tear down placed rooms")
check(barrierResetCount > 0, "launching must reset encounter barrier state")

-- Rank 89: heartbeat catch-up pacing -----------------------------------------

local function beat(deltaTime: number): number
	local before = steppedCount
	local callback = heartbeatCallback
	check(callback ~= nil, "the heartbeat must stay bound while the service runs");
	(callback :: (number) -> ())(deltaTime)
	return steppedCount - before
end

check(beat(0.1) == 0, "a partial interval must not step")
check(beat(0.1) == 0, "two partial intervals below the step interval must not step")
check(beat(0.1) == 1, "crossing the step interval must step exactly once")
--[[
	Rank 87 regression: the third beat left 0.05s of credit. Zeroing the
	accumulator instead of carrying the remainder would make this 0.2s beat fall
	short and silently stretch the expedition cadence.
]]
check(beat(0.2) == 1, "the carried remainder must complete the next step")
check(beat(0.24) == 0, "the remainder must not manufacture an extra step")
check(beat(0.01) == 1, "an exact interval boundary must step once")

-- Rank 88 regression: a long hitch may only be repaid up to the catch-up cap.
check(beat(1) == 4, "a one-second hitch must run the full four-step catch-up")
check(beat(0.25) == 1, "a full catch-up must leave no residual credit")
check(beat(60) == 4, "a long stall must stay capped at the catch-up bound")
check(beat(0.24) == 0, "an abandoned backlog must not carry into the next beat")
check(beat(0.01) == 1, "pacing must resume normally after an abandoned backlog")

local ignoredSteps = beat(0) + beat(-5)
check(ignoredSteps == 0, "non-positive heartbeat deltas must be ignored")

-- Rank 84: repeated expedition stop ------------------------------------------

local destroyedBeforeStop = destroyedBootstrapCount
local firstStop = service.stopExpedition("FixtureComplete")
check(firstStop.Accepted == true and firstStop.ReasonId == "FixtureComplete", "the first stop must be accepted")
check(firstStop.Snapshot ~= nil, "the first stop must report the stopped run")
check(destroyedBootstrapCount == destroyedBeforeStop + 1, "the first stop must destroy exactly one expedition")

local secondStop = service.stopExpedition("FixtureComplete")
check(
	secondStop.Accepted == false and secondStop.ReasonId == "NoActiveExpedition",
	"a repeated stop must report no active expedition"
)
check(destroyedBootstrapCount == destroyedBeforeStop + 1, "a repeated stop must not destroy anything a second time")
check(service.readSnapshot() == nil, "a stopped expedition must not leave a readable snapshot")
check(service.readRunVariationPlan() == nil, "a stopped expedition must clear variation state")
check(
	service.readRunVariationComposition("expedition:first-run").ReasonId == "NoActiveExpedition",
	"a stopped expedition must refuse composition reads"
)

-- Rank 85: repeated service start --------------------------------------------

local connectsBefore = heartbeatConnectCount
service.start()
service.start()
check(heartbeatConnectCount == connectsBefore, "restarting an already-started service must not rebind the heartbeat")

-- Rank 86: repeated service stop ---------------------------------------------

service.stop()
check(heartbeatDisconnectCount == 1, "stopping the service must release the heartbeat")
check(heartbeatCallback == nil, "a stopped service must not retain a heartbeat callback")
service.stop()
check(heartbeatDisconnectCount == 1, "a repeated service stop must not disconnect a second time")
check(service.startExpedition({ Seed = 421337 }).ReasonId == "ServiceStopped", "a stopped service must refuse launches")

print("Expedition live runtime lifecycle fixture passed")
