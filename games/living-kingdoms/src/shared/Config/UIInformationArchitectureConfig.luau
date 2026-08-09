--!strict

--[[
	BA-063 UI information architecture.

	This module is dormant architecture data. It inventories canonical player-facing
	surfaces, their presentation/state owners, and the coexistence rules future UI
	coordination work must preserve. It does not create GUI, bind input, fire
	remotes, or become a second gameplay authority.

	Input actions remain owned by BA-061/BA-062. This config references that audit
	instead of copying the seventeen-action inventory into a second source of truth.
]]

local ContextIds = table.freeze({
	Global = "Global",
	Preparation = "Preparation",
	Expedition = "Expedition",
	Debrief = "Debrief",
})

local SurfaceKindIds = table.freeze({
	AmbientHUD = "AmbientHUD",
	PersistentSummary = "PersistentSummary",
	RoutedPanel = "RoutedPanel",
	PlayerModal = "PlayerModal",
	ChoiceModal = "ChoiceModal",
	ReadOnlyResult = "ReadOnlyResult",
	DecisionPanel = "DecisionPanel",
})

local InputPolicyIds = table.freeze({
	Ambient = "Ambient",
	HubRouted = "HubRouted",
	ExclusiveInputModal = "ExclusiveInputModal",
	ReadOnlyResult = "ReadOnlyResult",
	Decision = "Decision",
})

local VisibilityRuleIds = table.freeze({
	AlwaysAvailable = "AlwaysAvailable",
	SafePreparationOnly = "SafePreparationOnly",
	PlayerToggle = "PlayerToggle",
	ActiveRunOnly = "ActiveRunOnly",
	RewardPending = "RewardPending",
	ResolvedRun = "ResolvedRun",
	DecisionPending = "DecisionPending",
	BuildRelevant = "BuildRelevant",
})

local function authorities(...: string): { string }
	return table.freeze({ ... })
end

local function surface(
	id: string,
	contextId: string,
	kindId: string,
	guiPath: string,
	presentationOwnerId: string,
	stateAuthorityIds: { string },
	inputPolicyId: string,
	visibilityRuleId: string,
	canRequestMutation: boolean,
	note: string
)
	return table.freeze({
		Id = id,
		ContextId = contextId,
		KindId = kindId,
		GuiPath = guiPath,
		PresentationOwnerId = presentationOwnerId,
		StateAuthorityIds = stateAuthorityIds,
		InputPolicyId = inputPolicyId,
		VisibilityRuleId = visibilityRuleId,
		CanRequestMutation = canRequestMutation,
		Note = note,
	})
end

local UIInformationArchitectureConfig = {
	Version = "BA-063-v1",
	RuntimeConsumptionActive = false,
	ContextIds = ContextIds,
	SurfaceKindIds = SurfaceKindIds,
	InputPolicyIds = InputPolicyIds,
	VisibilityRuleIds = VisibilityRuleIds,
	InputArchitecture = table.freeze({
		ActionInventorySpecification = "docs/specifications/input-action-map-audit.md",
		ActionInventoryTicketId = "BA-061",
		InputRemediationTicketId = "BA-062",
		ExistingModalAttribute = "LK_InputModalOpen",
		SharedModalCoordinatorImplemented = false,
	}),
	KnownOpenRisks = table.freeze({
		EscapeOwnershipCollision = true,
		NumberChoiceCollision = true,
		PromptActionCollision = true,
		DeviceAdaptiveLabelsIncomplete = true,
	}),
	CoexistenceRules = table.freeze({
		table.freeze({
			Id = "hub-routed-panels-exclusive",
			PolicyId = InputPolicyIds.HubRouted,
			Rule = "Specialist, loadout, and expedition-lobby panels are mutually exclusive and close when an expedition becomes active.",
		}),
		table.freeze({
			Id = "one-exclusive-input-modal",
			PolicyId = InputPolicyIds.ExclusiveInputModal,
			Rule = "At most one input-owning player or choice modal should accept selection input at a time.",
		}),
		table.freeze({
			Id = "ambient-hud-may-coexist",
			PolicyId = InputPolicyIds.Ambient,
			Rule = "Read-only ambient HUD and persistent build summaries may remain visible behind a modal when readability is preserved.",
		}),
		table.freeze({
			Id = "result-before-next-action",
			PolicyId = InputPolicyIds.ReadOnlyResult,
			Rule = "The resolved expedition result remains read-only; replay or return intent belongs to the separate party-decision surface.",
		}),
	}),
	Surfaces = table.freeze({
		surface(
			"preparation-specialist",
			ContextIds.Preparation,
			SurfaceKindIds.RoutedPanel,
			"TemporaryClassSelectionUI",
			"HubPreparationController",
			authorities("ClassService"),
			InputPolicyIds.HubRouted,
			VisibilityRuleIds.SafePreparationOnly,
			true,
			"Hub station routing reveals the existing specialist surface; ClassService keeps mutation authority."
		),
		surface(
			"preparation-loadout",
			ContextIds.Preparation,
			SurfaceKindIds.RoutedPanel,
			"WeaponLoadoutSelectionUI",
			"HubPreparationController",
			authorities("WeaponLoadoutService"),
			InputPolicyIds.HubRouted,
			VisibilityRuleIds.SafePreparationOnly,
			true,
			"Hub station routing reveals the existing loadout surface; WeaponLoadoutService keeps mutation authority."
		),
		surface(
			"preparation-expedition-lobby",
			ContextIds.Preparation,
			SurfaceKindIds.RoutedPanel,
			"LK_ExpeditionLobby",
			"ExpeditionLobbyController",
			authorities("ExpeditionLobbyService"),
			InputPolicyIds.HubRouted,
			VisibilityRuleIds.SafePreparationOnly,
			true,
			"The client requests only membership/readiness changes; the server exclusively decides launch."
		),
		surface(
			"character-record",
			ContextIds.Global,
			SurfaceKindIds.PlayerModal,
			"RPGMenu.Modal.CharacterPanel",
			"RPGMenuController",
			authorities("ClassService", "WeaponLoadoutService", "OperativeLifeService", "RunProgressionService"),
			InputPolicyIds.ExclusiveInputModal,
			VisibilityRuleIds.PlayerToggle,
			false,
			"Character record aggregates authoritative state for presentation and does not own class, loadout, life, or progression mutation."
		),
		surface(
			"inventory-record",
			ContextIds.Global,
			SurfaceKindIds.PlayerModal,
			"RPGMenu.Modal.InventoryPanel",
			"RPGMenuController",
			authorities("InventoryLiveService", "PlayerInventoryPersistenceService", "WeaponLoadoutService"),
			InputPolicyIds.ExclusiveInputModal,
			VisibilityRuleIds.PlayerToggle,
			false,
			"Inventory record is a presentation surface over canonical inventory/loadout state."
		),
		surface(
			"expedition-objective-hud",
			ContextIds.Expedition,
			SurfaceKindIds.AmbientHUD,
			"LK_ExpeditionHUD",
			"ExpeditionHUDController",
			authorities("ExpeditionLiveRuntimeService"),
			InputPolicyIds.Ambient,
			VisibilityRuleIds.ActiveRunOnly,
			false,
			"Read-only phase, objective, progress, party, and discovery presentation."
		),
		surface(
			"combat-hud",
			ContextIds.Expedition,
			SurfaceKindIds.AmbientHUD,
			"LivingKingdomsHordeHUD",
			"HordeHUDController",
			authorities("MissionDirectorService", "HordeExperienceService", "OperativeCombatRuntimeService", "OperativeLifeService", "RunProgressionService"),
			InputPolicyIds.Ambient,
			VisibilityRuleIds.ActiveRunOnly,
			false,
			"Unified combat presentation renders server-owned mission, combat, life, squad, and progression state."
		),
		surface(
			"progression-upgrade-choice",
			ContextIds.Expedition,
			SurfaceKindIds.ChoiceModal,
			"LivingKingdomsHordeHUD.UpgradeOverlay",
			"HordeHUDController",
			authorities("RunProgressionService"),
			InputPolicyIds.ExclusiveInputModal,
			VisibilityRuleIds.RewardPending,
			true,
			"The client submits one server-offered upgrade ID; RunProgressionService revalidates and owns the choice."
		),
		surface(
			"run-relic-summary",
			ContextIds.Expedition,
			SurfaceKindIds.PersistentSummary,
			"LK_RunBuildHUD.RelicBar",
			"RunBuildHUDController",
			authorities("RunBuildService"),
			InputPolicyIds.Ambient,
			VisibilityRuleIds.BuildRelevant,
			false,
			"Persistent run-build summary may coexist with normal gameplay while relevant."
		),
		surface(
			"run-relic-choice",
			ContextIds.Expedition,
			SurfaceKindIds.ChoiceModal,
			"LK_RunBuildHUD.RelicReward",
			"RunBuildHUDController",
			authorities("RunBuildService"),
			InputPolicyIds.ExclusiveInputModal,
			VisibilityRuleIds.RewardPending,
			true,
			"The client submits only a disclosed relic choice or replacement slot; RunBuildService owns validation and effects."
		),
		surface(
			"expedition-result",
			ContextIds.Debrief,
			SurfaceKindIds.ReadOnlyResult,
			"LK_ExpeditionResult",
			"ExpeditionResultController",
			authorities("ExpeditionResultService"),
			InputPolicyIds.ReadOnlyResult,
			VisibilityRuleIds.ResolvedRun,
			false,
			"Server-finalized debrief is read-only and cannot mutate rewards or result state."
		),
		surface(
			"expedition-next-action",
			ContextIds.Debrief,
			SurfaceKindIds.DecisionPanel,
			"LK_ExpeditionReplayDecision",
			"ExpeditionReplayDecisionController",
			authorities("ExpeditionPartyDecisionService"),
			InputPolicyIds.Decision,
			VisibilityRuleIds.DecisionPending,
			true,
			"Replay/return requests are isolated from the read-only result and resolved by the server-owned party-decision service."
		),
	}),
}

assert(UIInformationArchitectureConfig.RuntimeConsumptionActive == false, "BA-063 architecture data must remain dormant")
assert(UIInformationArchitectureConfig.InputArchitecture.SharedModalCoordinatorImplemented == false, "BA-063 must not claim a runtime coordinator")

local validContexts = {}
for _, id in ContextIds do
	validContexts[id] = true
end
local validKinds = {}
for _, id in SurfaceKindIds do
	validKinds[id] = true
end
local validInputPolicies = {}
for _, id in InputPolicyIds do
	validInputPolicies[id] = true
end
local validVisibilityRules = {}
for _, id in VisibilityRuleIds do
	validVisibilityRules[id] = true
end

local seenSurfaceIds = {}
local seenGuiPaths = {}
local exclusiveModalCount = 0
for _, definition in UIInformationArchitectureConfig.Surfaces do
	assert(seenSurfaceIds[definition.Id] == nil, "duplicate BA-063 surface ID: " .. definition.Id)
	seenSurfaceIds[definition.Id] = true
	assert(seenGuiPaths[definition.GuiPath] == nil, "duplicate BA-063 GUI path: " .. definition.GuiPath)
	seenGuiPaths[definition.GuiPath] = true
	assert(validContexts[definition.ContextId] == true, "unknown BA-063 context")
	assert(validKinds[definition.KindId] == true, "unknown BA-063 surface kind")
	assert(validInputPolicies[definition.InputPolicyId] == true, "unknown BA-063 input policy")
	assert(validVisibilityRules[definition.VisibilityRuleId] == true, "unknown BA-063 visibility rule")
	assert(#definition.StateAuthorityIds > 0, "every BA-063 surface requires at least one state authority")
	assert(#definition.PresentationOwnerId > 0, "every BA-063 surface requires a presentation owner")
	assert(#definition.Note > 0, "every BA-063 surface requires an ownership note")
	if definition.InputPolicyId == InputPolicyIds.ExclusiveInputModal then
		exclusiveModalCount += 1
	end
end

assert(exclusiveModalCount == 4, "BA-063 should track exactly four current input-owning modal surfaces")
assert(#UIInformationArchitectureConfig.CoexistenceRules == 4, "BA-063 should keep four top-level coexistence rules")

return table.freeze(UIInformationArchitectureConfig)
