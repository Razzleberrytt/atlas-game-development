--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(v: unknown, m: string)
	if not v then
		error(m, 2)
	end
end

local CONFIG, REWARD, CONTRACTS, PLANNER, VIEW, READBACK, SCHEMA = {}, {}, {}, {}, {}, {}, {}
local BOOTSTRAP, PLACEMENT, BARRIER, REWARD_RESOLVER, DIRECTOR, RUN_BUILD = {}, {}, {}, {}, {}, {}
local roomPlan: any = nil
local activeContext: any = { PhaseId = "Approach", RoomId = nil }
local activeSnapshot: any =
	{ RunId = "run-observe-001", PhaseId = "Approach", OutcomeId = "InProgress", SecretDiscovered = false }
local destroyed, placementDestroyCount, barrierResetCount = false, 0, 0

local config = {
	RuntimeLimits = { MinimumSeed = 1, MaximumSeed = 10_000 },
	Definitions = { FirstExpedition = { MinimumPlayers = 1, MaximumPlayers = 4 } },
}
local rewardConfig = { DecisionByRoomId = { ["keeper-core"] = { Id = "reward" } } }
local contracts = { PhaseIds = { Approach = "Approach" }, OutcomeIds = { InProgress = "InProgress" } }
local planner = {
	plan = function(plan: any): any
		return {
			Seed = plan.Seed,
			VariationIdentity = "variation:" .. plan.PlanIdentity,
			SecretBranch = {},
			OptionalObjective = {},
		}
	end,
}
local view = {
	build = function(plan: any, variation: any): any
		return { Seed = plan.Seed, VariationIdentity = variation.VariationIdentity, Records = {} }
	end,
}
local readback = {
	build = function(plan: any): any
		return {
			Seed = plan.Seed,
			RoomPlanIdentity = plan.PlanIdentity,
			RunModifierId = "dense-test",
			CompositionIdentity = "composition:" .. plan.PlanIdentity,
			RecordByRoomId = { combat = { SelectedWaveIndex = 2 } },
		}
	end,
}
local bootstrap = {
	new = function(_director: any, p: any): any
		if p.Seed == 995 then
			error("intentional creation failure")
		end
		roomPlan = { Seed = p.Seed, PlanIdentity = "room-plan:" .. tostring(p.Seed), Nodes = {} }
		activeSnapshot = { RunId = p.RunId, PhaseId = "Approach", OutcomeId = "InProgress", SecretDiscovered = false }
		activeContext = { PhaseId = "Approach", RoomId = nil }
		destroyed = false
		return {
			getRoomPlan = function(): any
				return roomPlan
			end,
			getSnapshot = function(): any
				return activeSnapshot
			end,
			getActiveEncounterContext = function(): any
				return activeContext
			end,
			step = function(): any
				return { Accepted = false, ReasonId = "EncounterInProgress" }
			end,
			destroy = function()
				destroyed = true
			end,
			Runtime = {
				markSecretDiscovered = function(): boolean
					return true
				end,
			},
		}
	end,
}
local placement = {
	place = function(): any
		return { Accepted = true, ReasonId = "Placed" }
	end,
	destroy = function()
		placementDestroyCount += 1
	end,
}
local barrier = {
	reset = function()
		barrierResetCount += 1
	end,
	update = function(_context: any) end,
}
local rewardResolver = {
	resolve = function(): any
		return nil
	end,
}
local runBuild = {
	offerRelicRewardToParticipants = function()
		error("diagnostics must not grant rewards")
	end,
}
local heartbeat: any = nil
local schemaSource = fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationDebugSchema.luau")
local schema = luau.load(schemaSource, { injectGlobals = true })()
local services = {
	HttpService = {
		GenerateGUID = function(): string
			return "generated-run-id"
		end,
	},
	Players = {
		GetPlayers = function(): { any }
			return {}
		end,
	},
	RunService = {
		IsStudio = function(): boolean
			return true
		end,
		Heartbeat = {
			Connect = function(_self: any, cb: any): any
				heartbeat = cb
				return { Disconnect = function() end }
			end,
		},
	},
}
local replicated = {
	Shared = {
		Config = { ExpeditionConfig = CONFIG, FirstDungeonRewardDecisionConfig = REWARD },
		Expeditions = {
			ExpeditionContracts = CONTRACTS,
			RunVariationPlanner = PLANNER,
			RunVariationEncounterView = VIEW,
			RunVariationCompositionDebugReadback = READBACK,
			RunVariationDebugSchema = SCHEMA,
		},
	},
}
local serviceSource = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLiveRuntimeService.luau")
local service = luau.load(serviceSource, {
	environment = {
		game = {
			GetService = function(_self: any, name: string): any
				if name == "ReplicatedStorage" then
					return replicated
				end
				return services[name]
			end,
		},
		workspace = {
			GetServerTimeNow = function(): number
				return 100
			end,
		},
		script = {
			Parent = {
				ExpeditionServerBootstrap = BOOTSTRAP,
				ExpeditionRoomPlacementService = PLACEMENT,
				ExpeditionRoomBarrierStateService = BARRIER,
				ExpeditionBossRewardTransitionResolver = REWARD_RESOLVER,
				EnemyDirectorService = DIRECTOR,
				RunBuildService = RUN_BUILD,
			},
		},
		require = function(token: unknown): any
			if token == CONFIG then
				return config
			elseif token == REWARD then
				return rewardConfig
			elseif token == CONTRACTS then
				return contracts
			elseif token == PLANNER then
				return planner
			elseif token == VIEW then
				return view
			elseif token == READBACK then
				return readback
			elseif token == SCHEMA then
				return schema
			elseif token == BOOTSTRAP then
				return bootstrap
			elseif token == PLACEMENT then
				return placement
			elseif token == BARRIER then
				return barrier
			elseif token == REWARD_RESOLVER then
				return rewardResolver
			elseif token == DIRECTOR then
				return {}
			elseif token == RUN_BUILD then
				return runBuild
			end
			error("unexpected dependency")
		end,
	},
	injectGlobals = true,
})()

check(service.readRunVariationComposition() == nil, "readback must be absent before start")
service.start()
check(heartbeat ~= nil, "bounded heartbeat must mount")
local started = service.startExpedition({ Seed = 321, PartySize = 1, RunId = "  run-observe-001  " })
check(started.Accepted == true, "valid expedition must start")
local initial = service.readRunVariationComposition()
check(
	initial.RunId == "run-observe-001" and initial.CompositionDurationMs ~= nil and initial.CompositionDurationMs >= 0,
	"active timing/run binding drift"
)
check(initial.CurrentEncounterPhaseId == "Approach" and initial.CurrentRoomId == nil, "initial phase readback drift")
check(
	initial.ActiveCompositionIdentity
		== "P06-ACTIVE-COMPOSITION-v2|run=run-observe-001|composition=composition%3Aroom-plan%3A321",
	"central active identity drift"
)
activeSnapshot.PhaseId = "Dungeon"
activeContext = { PhaseId = "Dungeon", RoomId = "combat" }
local live = service.readRunVariationComposition()
check(live.CurrentEncounterPhaseId == "Dungeon", "live phase must update")
check(live.CurrentRoomId == "combat", "live room must update")
check(live.ActiveWaveIndex == 2, "active room wave hint must update")
check(table.isfrozen(live), "live readback must be immutable")
local stopped = service.stopExpedition("fixture-stop")
check(stopped.Accepted == true and destroyed, "stop must destroy active bootstrap")
check(service.readRunVariationComposition() == nil, "stop must clear diagnostics")
local beforeDestroy, beforeReset = placementDestroyCount, barrierResetCount
local failed = service.startExpedition({ Seed = 995, PartySize = 1, RunId = "run-observe-995" })
check(
	failed.Accepted == false and failed.ReasonId == "ExpeditionCreationFailed",
	"creation failure must remain explicit"
)
check(
	placementDestroyCount == beforeDestroy + 1 and barrierResetCount == beforeReset + 1,
	"creation failure cleanup drift"
)
service.stop()
print("Expedition run variation observability fixture passed")
