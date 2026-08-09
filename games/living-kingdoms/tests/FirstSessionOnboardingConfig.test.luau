--!strict

-- BA-060 onboarding fixture: pin the intended first-session player journey to
-- existing owner boundaries and dormant prepared MVP content without creating a
-- tutorial runtime or hiding the deliberate-replay lifecycle blocker.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-060 first-session onboarding assertion failed", 2)
	end
end

local hubConfig = {
	ZoneContentId = "zone.hub.forward_operations",
	Stations = {
		{ actionId = "OpenClass", contentId = "hub.specialist" },
		{ actionId = "OpenWeapon", contentId = "hub.armory" },
		{ actionId = "OpenExpedition", contentId = "hub.expedition" },
	},
}
local routeConfig = {
	RouteId = "outdoor-route.first-descent",
	RuntimeConsumptionActive = false,
}
local discoveryConfig = {
	RuntimeConsumptionActive = false,
	Discoveries = {
		{ Id = "discovery.first-descent.lookout-cache" },
	},
}
local dungeonConfig = {
	SequenceId = "first-descent-repeatable",
}
local rewardDecisionConfig = {
	SequenceId = "first-descent-reward-decisions",
	RuntimeConsumptionEnabled = false,
}

local HUB_TOKEN = {}
local ROUTE_TOKEN = {}
local DISCOVERY_TOKEN = {}
local DUNGEON_TOKEN = {}
local REWARD_TOKEN = {}

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstSessionOnboardingConfig.luau"), {
	debugName = "FirstSessionOnboardingConfig",
	environment = {
		script = {
			Parent = {
				HubPreparationConfig = HUB_TOKEN,
				FirstOutdoorRouteConfig = ROUTE_TOKEN,
				FirstOutdoorDiscoveryConfig = DISCOVERY_TOKEN,
				FirstDungeonContentConfig = DUNGEON_TOKEN,
				FirstDungeonRewardDecisionConfig = REWARD_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == HUB_TOKEN then
				return hubConfig
			end
			if token == ROUTE_TOKEN then
				return routeConfig
			end
			if token == DISCOVERY_TOKEN then
				return discoveryConfig
			end
			if token == DUNGEON_TOKEN then
				return dungeonConfig
			end
			if token == REWARD_TOKEN then
				return rewardDecisionConfig
			end
			error("unexpected FirstSessionOnboardingConfig dependency")
		end,
	},
	injectGlobals = true,
})()

assert(config.Version == "BA-060-v1")
assert(config.SequenceId == "onboarding.first-session.mvp-0.1")
assert(config.RuntimeConsumptionActive == false)
assert(#config.Steps == 12, "first-session sequence should remain a compact twelve-step journey")

local byId = {}
local optionalCount = 0
local blockedCount = 0
for index, onboardingStep in config.Steps do
	assert(onboardingStep.Order == index, "first-session step ordering must remain contiguous")
	assert(byId[onboardingStep.Id] == nil, "first-session step IDs must remain unique")
	byId[onboardingStep.Id] = onboardingStep
	assert(#onboardingStep.PlayerGoal > 0, "every first-session step needs a player-facing goal")
	assert(#onboardingStep.OwnershipBoundaryId > 0, "every first-session step needs an ownership boundary")
	if onboardingStep.Optional then
		optionalCount += 1
	end
	if onboardingStep.ImplementationStateId == config.ImplementationStateIds.BlockedLifecycle then
		blockedCount += 1
	end
end

assert(optionalCount == 1, "Lookout Cache must remain the only optional first-session beat")
assert(blockedCount == 1, "deliberate replay must remain the one explicit lifecycle blocker")
assert(config.Steps[1].KindId == config.StepKindIds.Arrival)
assert(config.Steps[#config.Steps].KindId == config.StepKindIds.Replay)

assert(byId["arrive-forward-operations"].OwnershipBoundaryId == "HubPreparationService")
assert(byId["arrive-forward-operations"].ReferenceId == hubConfig.ZoneContentId)
assert(byId["choose-specialist"].OwnershipBoundaryId == "ClassService")
assert(byId["choose-specialist"].ActionId == "OpenClass")
assert(byId["choose-specialist"].ReferenceId == "hub.specialist")
assert(byId["choose-loadout"].OwnershipBoundaryId == "WeaponLoadoutService")
assert(byId["choose-loadout"].ActionId == "OpenWeapon")
assert(byId["choose-loadout"].ReferenceId == "hub.armory")
assert(byId["open-expedition-terminal"].OwnershipBoundaryId == "ExpeditionLobbyService")
assert(byId["open-expedition-terminal"].ActionId == "OpenExpedition")

assert(byId["traverse-first-outdoor-route"].ReferenceId == routeConfig.RouteId)
assert(byId["traverse-first-outdoor-route"].ImplementationStateId == config.ImplementationStateIds.PreparedData)
assert(byId["discover-lookout-cache"].ReferenceId == discoveryConfig.Discoveries[1].Id)
assert(byId["discover-lookout-cache"].Optional == true)
assert(byId["complete-first-descent"].ReferenceId == dungeonConfig.SequenceId)
assert(byId["make-run-reward-choice"].ReferenceId == rewardDecisionConfig.SequenceId)
assert(byId["make-run-reward-choice"].OwnershipBoundaryId == "RunBuildService")
assert(byId["make-run-reward-choice"].ImplementationStateId == config.ImplementationStateIds.PreparedIntegration)

assert(byId["read-operation-result"].OwnershipBoundaryId == "ExpeditionResultService")
assert(byId["return-to-preparation"].ActionId == "ReturnToLobby")
assert(byId["apply-earned-build-choice"].OwnershipBoundaryId == "RunBuildService")
assert(byId["apply-earned-build-choice"].ActionId == "SubmitRelicChoice")

local replay = byId["deliberately-start-next-run"]
assert(replay == config.Steps[#config.Steps], "deliberate replay must stay last")
assert(replay.OwnershipBoundaryId == "OperationLifecycleService")
assert(replay.ImplementationStateId == config.ImplementationStateIds.BlockedLifecycle)
assert(
	string.find(replay.IntegrationNote, "auto-replays", 1, true) ~= nil,
	"the current auto-replay mismatch must remain explicit"
)

local source = fs.readFile("games/living-kingdoms/src/shared/Config/FirstSessionOnboardingConfig.luau")
assert(string.find(source, "Workspace/", 1, true) == nil, "BA-060 cannot author raw Workspace paths")
assert(string.find(source, "DataStore", 1, true) == nil, "BA-060 cannot own persistence")
assert(string.find(source, "FireServer", 1, true) == nil, "BA-060 cannot fire onboarding remotes")
assert(string.find(source, "RemoteEvent", 1, true) == nil, "BA-060 cannot create onboarding networking")
assert(
	string.find(source, "require(script.Parent.Parent.Server.Systems.OperationLifecycleService", 1, true) == nil,
	"BA-060 must not import the blocked lifecycle owner"
)

print("BA-060 FirstSessionOnboardingConfig fixture passed")
