--!strict

--[[
	BA-060 first-session onboarding sequence.

	This is dormant orchestration data, not a tutorial runtime. It orders the
	player-facing first-run goals around existing canonical surfaces/services and
	prepared MVP content. It never fires prompts, mutates gameplay, starts a run,
	grants a reward, returns a player, or restarts an operation.
]]

local HubPreparationConfig = require(script.Parent.HubPreparationConfig)
local FirstOutdoorRouteConfig = require(script.Parent.FirstOutdoorRouteConfig)
local FirstOutdoorDiscoveryConfig = require(script.Parent.FirstOutdoorDiscoveryConfig)
local FirstDungeonContentConfig = require(script.Parent.FirstDungeonContentConfig)
local FirstDungeonRewardDecisionConfig = require(script.Parent.FirstDungeonRewardDecisionConfig)

local ImplementationStateIds = table.freeze({
	RuntimeExisting = "RuntimeExisting",
	PreparedData = "PreparedData",
	PreparedIntegration = "PreparedIntegration",
	BlockedLifecycle = "BlockedLifecycle",
})

local StepKindIds = table.freeze({
	Arrival = "Arrival",
	Preparation = "Preparation",
	Launch = "Launch",
	Traversal = "Traversal",
	OptionalDiscovery = "OptionalDiscovery",
	Dungeon = "Dungeon",
	Reward = "Reward",
	Result = "Result",
	Return = "Return",
	Upgrade = "Upgrade",
	Replay = "Replay",
})

local function hubStationContentId(actionId: string): string
	for _, station in HubPreparationConfig.Stations do
		if station.actionId == actionId then
			return station.contentId
		end
	end
	error("unknown first-session hub action: " .. actionId)
end

local function step(
	id: string,
	order: number,
	kindId: string,
	playerGoal: string,
	implementationStateId: string,
	optional: boolean,
	ownershipBoundaryId: string,
	referenceId: string?,
	actionId: string?,
	integrationNote: string?
)
	return table.freeze({
		Id = id,
		Order = order,
		KindId = kindId,
		PlayerGoal = playerGoal,
		ImplementationStateId = implementationStateId,
		Optional = optional,
		OwnershipBoundaryId = ownershipBoundaryId,
		ReferenceId = referenceId,
		ActionId = actionId,
		IntegrationNote = integrationNote,
	})
end

local discovery = FirstOutdoorDiscoveryConfig.Discoveries[1]

local FirstSessionOnboardingConfig = {
	Version = "BA-060-v1",
	SequenceId = "onboarding.first-session.mvp-0.1",
	RuntimeConsumptionActive = false,
	ImplementationStateIds = ImplementationStateIds,
	StepKindIds = StepKindIds,
	Steps = table.freeze({
		step(
			"arrive-forward-operations",
			1,
			StepKindIds.Arrival,
			"Arrive safely and recognize the Ranger Station preparation area.",
			ImplementationStateIds.RuntimeExisting,
			false,
			"HubPreparationService",
			HubPreparationConfig.ZoneContentId,
			nil,
			nil
		),
		step(
			"choose-specialist",
			2,
			StepKindIds.Preparation,
			"Inspect the specialist station and understand that operative choice lives here.",
			ImplementationStateIds.RuntimeExisting,
			false,
			"ClassService",
			hubStationContentId("OpenClass"),
			"OpenClass",
			"BA-060 sequences the existing station; ClassService retains class mutation ownership."
		),
		step(
			"choose-loadout",
			3,
			StepKindIds.Preparation,
			"Inspect the armory and leave preparation with a readable weapon choice.",
			ImplementationStateIds.RuntimeExisting,
			false,
			"WeaponLoadoutService",
			hubStationContentId("OpenWeapon"),
			"OpenWeapon",
			"BA-060 sequences the existing station; WeaponLoadoutService retains loadout mutation ownership."
		),
		step(
			"open-expedition-terminal",
			4,
			StepKindIds.Launch,
			"Open the expedition terminal, join the lobby, and deliberately ready for launch.",
			ImplementationStateIds.RuntimeExisting,
			false,
			"ExpeditionLobbyService",
			hubStationContentId("OpenExpedition"),
			"OpenExpedition",
			"The server-owned lobby consumes readiness before mission and horde pressure are armed."
		),
		step(
			"traverse-first-outdoor-route",
			5,
			StepKindIds.Traversal,
			"Follow the readable outdoor approach and learn escalating encounter pressure.",
			ImplementationStateIds.PreparedData,
			false,
			"PreparedRouteIntegrationBoundary",
			FirstOutdoorRouteConfig.RouteId,
			nil,
			"BA-050/051 content is authored but remains dormant until an approved runtime consumer exists."
		),
		step(
			"discover-lookout-cache",
			6,
			StepKindIds.OptionalDiscovery,
			"Notice that exploration can reveal an optional cache without blocking the main route.",
			ImplementationStateIds.PreparedData,
			true,
			"PreparedDiscoveryIntegrationBoundary",
			discovery.Id,
			nil,
			"The authored-container reward seam is planned; BA-060 does not activate it."
		),
		step(
			"complete-first-descent",
			7,
			StepKindIds.Dungeon,
			"Enter the First Descent, survive the room sequence, elite gate, boss, and terminal.",
			ImplementationStateIds.PreparedData,
			false,
			"PreparedExpeditionContentIntegrationBoundary",
			FirstDungeonContentConfig.SequenceId,
			nil,
			"BA-032 supplies deterministic content data; runtime integration remains separately gated."
		),
		step(
			"make-run-reward-choice",
			8,
			StepKindIds.Reward,
			"Make a meaningful two-choice Run Relic decision earned from the operation.",
			ImplementationStateIds.PreparedIntegration,
			false,
			"RunBuildService",
			FirstDungeonRewardDecisionConfig.SequenceId,
			"SubmitRelicChoice",
			"BA-033 reward mapping is dormant and the boss milestone source remains planned."
		),
		step(
			"read-operation-result",
			9,
			StepKindIds.Result,
			"See a clear resolved run result before leaving the operation.",
			ImplementationStateIds.RuntimeExisting,
			false,
			"ExpeditionResultService",
			FirstDungeonContentConfig.SequenceId,
			nil,
			"Result finalization is server-owned and does not itself teleport or replay."
		),
		step(
			"return-to-preparation",
			10,
			StepKindIds.Return,
			"Return to the safe preparation flow after the resolved expedition.",
			ImplementationStateIds.RuntimeExisting,
			false,
			"ExpeditionLobbyBridge",
			HubPreparationConfig.ZoneContentId,
			"ReturnToLobby",
			"The existing server bridge validates that the expedition is resolved before stopping it."
		),
		step(
			"apply-earned-build-choice",
			11,
			StepKindIds.Upgrade,
			"Confirm the earned build choice and understand how the next run can play differently.",
			ImplementationStateIds.PreparedIntegration,
			false,
			"RunBuildService",
			"run-build.relic-choice",
			"SubmitRelicChoice",
			"The choice authority exists, but BA-060 does not create or reroll reward offers."
		),
		step(
			"deliberately-start-next-run",
			12,
			StepKindIds.Replay,
			"Choose to start another run from safety rather than being auto-restarted.",
			ImplementationStateIds.BlockedLifecycle,
			false,
			"OperationLifecycleService",
			hubStationContentId("OpenExpedition"),
			"OpenExpedition",
			"BLOCKED: current OperationLifecycleService auto-replays after debrief; reconcile that owner before onboarding integration."
		),
	}),
}

assert(FirstSessionOnboardingConfig.RuntimeConsumptionActive == false, "BA-060 onboarding data must remain dormant")
assert(FirstOutdoorRouteConfig.RuntimeConsumptionActive == false, "BA-060 cannot activate the BA-050 route")
assert(FirstOutdoorDiscoveryConfig.RuntimeConsumptionActive == false, "BA-060 cannot activate BA-052 discovery data")
assert(
	FirstDungeonRewardDecisionConfig.RuntimeConsumptionEnabled == false,
	"BA-060 cannot activate BA-033 reward-decision consumption"
)

local validImplementationStates = {}
for _, stateId in ImplementationStateIds do
	validImplementationStates[stateId] = true
end
local validStepKinds = {}
for _, kindId in StepKindIds do
	validStepKinds[kindId] = true
end

local seenStepIds = {}
local optionalCount = 0
local blockedLifecycleCount = 0
for index, onboardingStep in FirstSessionOnboardingConfig.Steps do
	assert(onboardingStep.Order == index, "first-session onboarding orders must remain contiguous")
	assert(seenStepIds[onboardingStep.Id] == nil, "duplicate first-session onboarding step: " .. onboardingStep.Id)
	seenStepIds[onboardingStep.Id] = true
	assert(validStepKinds[onboardingStep.KindId] == true, "unknown first-session onboarding step kind")
	assert(
		validImplementationStates[onboardingStep.ImplementationStateId] == true,
		"unknown first-session implementation state"
	)
	assert(#onboardingStep.PlayerGoal > 0, "first-session onboarding steps require a player-facing goal")
	assert(#onboardingStep.OwnershipBoundaryId > 0, "first-session onboarding steps require an ownership boundary")
	if onboardingStep.Optional then
		optionalCount += 1
	end
	if onboardingStep.ImplementationStateId == ImplementationStateIds.BlockedLifecycle then
		blockedLifecycleCount += 1
		assert(index == #FirstSessionOnboardingConfig.Steps, "lifecycle blocker must remain the final replay step")
	end
end

assert(optionalCount == 1, "the first session must keep exactly one optional discovery beat")
assert(blockedLifecycleCount == 1, "the first session must expose the unresolved deliberate-replay lifecycle blocker")
assert(
	FirstSessionOnboardingConfig.Steps[1].KindId == StepKindIds.Arrival
		and FirstSessionOnboardingConfig.Steps[#FirstSessionOnboardingConfig.Steps].KindId == StepKindIds.Replay,
	"first-session sequence must run from safe arrival through deliberate replay intent"
)

return table.freeze(FirstSessionOnboardingConfig)
