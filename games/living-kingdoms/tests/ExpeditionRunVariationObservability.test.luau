--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "expedition run variation observability assertion failed", 2)
	end
end

local CONFIG_TOKEN = {}
local REWARD_CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local VARIATION_PLANNER_TOKEN = {}
local ENCOUNTER_VIEW_TOKEN = {}
local BOOTSTRAP_TOKEN = {}
local PLACEMENT_TOKEN = {}
local BARRIER_TOKEN = {}
local REWARD_RESOLVER_TOKEN = {}
local DIRECTOR_TOKEN = {}
local RUN_BUILD_TOKEN = {}

local roomPlan: any = nil
local variationPlan: any = nil
local encounterView: any = nil
local plannerReceivedPlan: any = nil
local encounterViewReceivedPlan: any = nil
local encounterViewReceivedVariationPlan: any = nil
local bootstrapDestroyed = false
local activeSnapshot = {
	RunId = "run-observe-001",
	PhaseId = "Approach",
	OutcomeId = "InProgress",
	SecretDiscovered = false,
}

local expeditionConfig = {
	RuntimeLimits = { MinimumSeed = 1, MaximumSeed = 10_000 },
	Definitions = {
		FirstExpedition = { MinimumPlayers = 1, MaximumPlayers = 4 },
	},
}
local rewardConfig = {
	DecisionByRoomId = {
		["keeper-core"] = { Id = "reward-decision" },
	},
}
local contracts = {
	PhaseIds = { Approach = "Approach" },
	OutcomeIds = { InProgress = "InProgress" },
}

local variationPlanner = {
	plan = function(plan: any): any
		plannerReceivedPlan = plan
		if plan.Seed == 999 then
			error("intentional variation planning failure")
		end
		variationPlan = table.freeze({
			Seed = plan.Seed,
			RoomPlanIdentity = plan.PlanIdentity,
			VariationIdentity = "variation:" .. plan.PlanIdentity,
		})
		return variationPlan
	end,
}

local encounterViewBuilder = {
	build = function(plan: any, composedVariationPlan: any): any
		encounterViewReceivedPlan = plan
		encounterViewReceivedVariationPlan = composedVariationPlan
		if plan.Seed == 998 then
			error("intentional encounter-view failure")
		end
		encounterView = table.freeze({
			Seed = plan.Seed,
			RoomPlanIdentity = plan.PlanIdentity,
			VariationIdentity = composedVariationPlan.VariationIdentity,
			Records = table.freeze({}),
		})
		return encounterView
	end,
}

local bootstrap = {
	new = function(_director: any, parameters: any): any
		roomPlan = {
			Seed = parameters.Seed,
			PlanIdentity = "room-plan:" .. tostring(parameters.Seed),
			Nodes = {},
		}
		bootstrapDestroyed = false
		return {
			getRoomPlan = function(): any
				return roomPlan
			end,
			getSnapshot = function(): any
				return activeSnapshot
			end,
			getActiveEncounterContext = function(): any
				return nil
			end,
			step = function(): any
				return { Accepted = false, ReasonId = "EncounterInProgress" }
			end,
			destroy = function()
				bootstrapDestroyed = true
			end,
			Runtime = {},
		}
	end,
}

local placement = {
	place = function(plan: any): any
		assert(plan == roomPlan, "room placement must receive the same canonical room plan")
		return { Accepted = true, ReasonId = "Placed" }
	end,
	destroy = function() end,
}
local barrier = {
	reset = function() end,
	update = function(_context: any) end,
}
local rewardResolver = {
	resolve = function(_previous: any, _current: any, _decision: any): any
		return nil
	end,
}
local runBuild = {
	offerRelicRewardToParticipants = function()
		error("variation observability must not grant rewards")
	end,
}

local heartbeatCallback: ((number) -> ())? = nil
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
		Heartbeat = {
			Connect = function(_self: any, callback: (number) -> ()): any
				heartbeatCallback = callback
				return { Disconnect = function() end }
			end,
		},
	},
}

local replicatedStorage = {
	Shared = {
		Config = {
			ExpeditionConfig = CONFIG_TOKEN,
			FirstDungeonRewardDecisionConfig = REWARD_CONFIG_TOKEN,
		},
		Expeditions = {
			ExpeditionContracts = CONTRACTS_TOKEN,
			RunVariationPlanner = VARIATION_PLANNER_TOKEN,
			RunVariationEncounterView = ENCOUNTER_VIEW_TOKEN,
		},
	},
}

local service = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionLiveRuntimeService.luau"), {
	debugName = "ExpeditionLiveRuntimeService",
	environment = {
		game = {
			GetService = function(_self: any, serviceName: string): any
				if serviceName == "ReplicatedStorage" then
					return replicatedStorage
				end
				return services[serviceName]
			end,
		},
		workspace = {
			GetServerTimeNow = function(): number
				return 100
			end,
		},
		script = {
			Parent = {
				ExpeditionServerBootstrap = BOOTSTRAP_TOKEN,
				ExpeditionRoomPlacementService = PLACEMENT_TOKEN,
				ExpeditionRoomBarrierStateService = BARRIER_TOKEN,
				ExpeditionBossRewardTransitionResolver = REWARD_RESOLVER_TOKEN,
				EnemyDirectorService = DIRECTOR_TOKEN,
				RunBuildService = RUN_BUILD_TOKEN,
			},
		},
		require = function(token: unknown): any
			if token == CONFIG_TOKEN then
				return expeditionConfig
			elseif token == REWARD_CONFIG_TOKEN then
				return rewardConfig
			elseif token == CONTRACTS_TOKEN then
				return contracts
			elseif token == VARIATION_PLANNER_TOKEN then
				return variationPlanner
			elseif token == ENCOUNTER_VIEW_TOKEN then
				return encounterViewBuilder
			elseif token == BOOTSTRAP_TOKEN then
				return bootstrap
			elseif token == PLACEMENT_TOKEN then
				return placement
			elseif token == BARRIER_TOKEN then
				return barrier
			elseif token == REWARD_RESOLVER_TOKEN then
				return rewardResolver
			elseif token == DIRECTOR_TOKEN then
				return {}
			elseif token == RUN_BUILD_TOKEN then
				return runBuild
			end
			error("unexpected ExpeditionLiveRuntimeService dependency")
		end,
	},
	injectGlobals = true,
})()

assert(service.readRunVariationPlan() == nil, "variation plan must be absent before a run starts")
assert(service.readRunVariationEncounterView() == nil, "encounter view must be absent before a run starts")
service.start()
assert(heartbeatCallback ~= nil, "service start must preserve its bounded heartbeat owner")

local started = service.startExpedition({ Seed = 321, PartySize = 1, RunId = "run-observe-001" })
assert(started.Accepted == true, "valid expedition must start")
assert(plannerReceivedPlan == roomPlan, "planner must receive the exact canonical room plan")
assert(encounterViewReceivedPlan == roomPlan, "encounter view must receive the exact canonical room plan")
assert(
	encounterViewReceivedVariationPlan == variationPlan,
	"encounter view must receive the exact composed run variation plan"
)
assert(service.readRunVariationPlan() == variationPlan, "server read must expose the composed variation plan")
assert(
	service.readRunVariationEncounterView() == encounterView,
	"server read must expose the composed run variation encounter view"
)
assert(variationPlan.Seed == 321, "variation plan must retain the authoritative run seed")
assert(encounterView.Seed == 321, "encounter view must retain the authoritative run seed")
assert(service.readRoomPlan() == roomPlan, "existing room-plan read must remain unchanged")

local stopped = service.stopExpedition("fixture-stop")
assert(stopped.Accepted == true, "active expedition must stop")
assert(bootstrapDestroyed == true, "stopping must still destroy the bootstrap")
assert(service.readRunVariationPlan() == nil, "stopping must clear variation observability")
assert(service.readRunVariationEncounterView() == nil, "stopping must clear encounter-view observability")

local encounterViewFailed = service.startExpedition({ Seed = 998, PartySize = 1, RunId = "run-observe-998" })
assert(
	encounterViewFailed.Accepted == false and encounterViewFailed.ReasonId == "RunVariationEncounterViewFailed",
	"encounter-view failure must reject creation"
)
assert(bootstrapDestroyed == true, "encounter-view failure must destroy the half-created bootstrap")
assert(service.readRunVariationPlan() == nil, "encounter-view failure must not publish partial variation state")
assert(
	service.readRunVariationEncounterView() == nil,
	"encounter-view failure must not publish partial encounter-view state"
)

local failed = service.startExpedition({ Seed = 999, PartySize = 1, RunId = "run-observe-999" })
assert(
	failed.Accepted == false and failed.ReasonId == "RunVariationPlanningFailed",
	"planner failure must reject creation"
)
assert(bootstrapDestroyed == true, "planner failure must destroy the half-created bootstrap")
assert(service.readRunVariationPlan() == nil, "planner failure must not publish partial variation state")
assert(service.readRunVariationEncounterView() == nil, "planner failure must not publish encounter-view state")

service.stop()
assert(service.readRunVariationPlan() == nil, "service shutdown must leave no variation state")
assert(service.readRunVariationEncounterView() == nil, "service shutdown must leave no encounter-view state")

local liveMountSource = fs.readFile("games/living-kingdoms/src/server/expedition-live.server.luau")
assert(
	string.find(liveMountSource, 'action == "ReadRunVariationEncounterView"', 1, true) ~= nil,
	"server-only ExpeditionControl must expose the encounter view read action"
)
assert(
	string.find(liveMountSource, "ExpeditionLiveRuntimeService.readRunVariationEncounterView()", 1, true) ~= nil,
	"encounter view read action must delegate to the canonical live runtime owner"
)

print("Expedition run variation observability fixture passed")
