--!strict

-- BA-063 fixture: pin the canonical UI surface matrix and ownership boundaries
-- without activating a shared modal coordinator or duplicating BA-061 actions.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-063 UI information architecture assertion failed", 2)
	end
end

local sourcePath = "games/living-kingdoms/src/shared/Config/UIInformationArchitectureConfig.luau"
local source = fs.readFile(sourcePath)
local config = luau.load(source, {
	debugName = "UIInformationArchitectureConfig",
	injectGlobals = true,
})()

assert(config.Version == "BA-063-v1")
assert(config.RuntimeConsumptionActive == false)
assert(config.InputArchitecture.ActionInventoryTicketId == "BA-061")
assert(config.InputArchitecture.InputRemediationTicketId == "BA-062")
assert(config.InputArchitecture.ActionInventorySpecification == "docs/specifications/input-action-map-audit.md")
assert(config.InputArchitecture.ExistingModalAttribute == "LK_InputModalOpen")
assert(config.InputArchitecture.SharedModalCoordinatorImplemented == false)

assert(config.KnownOpenRisks.EscapeOwnershipCollision == true)
assert(config.KnownOpenRisks.NumberChoiceCollision == true)
assert(config.KnownOpenRisks.PromptActionCollision == true)
assert(config.KnownOpenRisks.DeviceAdaptiveLabelsIncomplete == true)
assert(#config.CoexistenceRules == 4)
assert(#config.Surfaces == 12, "BA-063 should describe the twelve canonical MVP UI surfaces")

local byId = {}
local guiPaths = {}
local exclusiveCount = 0
local mutationRequestCount = 0
for _, surface in config.Surfaces do
	assert(byId[surface.Id] == nil, "surface IDs must remain unique")
	assert(guiPaths[surface.GuiPath] == nil, "GUI paths must remain unique")
	byId[surface.Id] = surface
	guiPaths[surface.GuiPath] = true
	assert(#surface.PresentationOwnerId > 0)
	assert(#surface.StateAuthorityIds > 0)
	assert(#surface.Note > 0)
	if surface.InputPolicyId == config.InputPolicyIds.ExclusiveInputModal then
		exclusiveCount += 1
	end
	if surface.CanRequestMutation then
		mutationRequestCount += 1
	end
end

assert(exclusiveCount == 4, "character, inventory, progression choice, and relic choice are the four modal surfaces")
assert(mutationRequestCount == 6, "only routed/choice/decision surfaces should request canonical mutations")

local specialist = byId["preparation-specialist"]
assert(specialist.GuiPath == "TemporaryClassSelectionUI")
assert(specialist.PresentationOwnerId == "HubPreparationController")
assert(specialist.StateAuthorityIds[1] == "ClassService")
assert(specialist.InputPolicyId == config.InputPolicyIds.HubRouted)
assert(specialist.VisibilityRuleId == config.VisibilityRuleIds.SafePreparationOnly)

local loadout = byId["preparation-loadout"]
assert(loadout.GuiPath == "WeaponLoadoutSelectionUI")
assert(loadout.StateAuthorityIds[1] == "WeaponLoadoutService")

local lobby = byId["preparation-expedition-lobby"]
assert(lobby.GuiPath == "LK_ExpeditionLobby")
assert(lobby.PresentationOwnerId == "ExpeditionLobbyController")
assert(lobby.StateAuthorityIds[1] == "ExpeditionLobbyService")

local character = byId["character-record"]
assert(character.GuiPath == "RPGMenu.Modal.CharacterPanel")
assert(character.CanRequestMutation == false)
assert(character.InputPolicyId == config.InputPolicyIds.ExclusiveInputModal)

local inventory = byId["inventory-record"]
assert(inventory.GuiPath == "RPGMenu.Modal.InventoryPanel")
assert(inventory.CanRequestMutation == false)
assert(inventory.InputPolicyId == config.InputPolicyIds.ExclusiveInputModal)

local expeditionHud = byId["expedition-objective-hud"]
assert(expeditionHud.GuiPath == "LK_ExpeditionHUD")
assert(expeditionHud.CanRequestMutation == false)
assert(expeditionHud.InputPolicyId == config.InputPolicyIds.Ambient)

local combatHud = byId["combat-hud"]
assert(combatHud.GuiPath == "LivingKingdomsHordeHUD")
assert(combatHud.CanRequestMutation == false)
assert(combatHud.InputPolicyId == config.InputPolicyIds.Ambient)

local progressionChoice = byId["progression-upgrade-choice"]
assert(progressionChoice.GuiPath == "LivingKingdomsHordeHUD.UpgradeOverlay")
assert(progressionChoice.StateAuthorityIds[1] == "RunProgressionService")
assert(progressionChoice.InputPolicyId == config.InputPolicyIds.ExclusiveInputModal)
assert(progressionChoice.CanRequestMutation == true)

local relicSummary = byId["run-relic-summary"]
assert(relicSummary.GuiPath == "LK_RunBuildHUD.RelicBar")
assert(relicSummary.StateAuthorityIds[1] == "RunBuildService")
assert(relicSummary.CanRequestMutation == false)

local relicChoice = byId["run-relic-choice"]
assert(relicChoice.GuiPath == "LK_RunBuildHUD.RelicReward")
assert(relicChoice.InputPolicyId == config.InputPolicyIds.ExclusiveInputModal)
assert(relicChoice.CanRequestMutation == true)

local result = byId["expedition-result"]
assert(result.GuiPath == "LK_ExpeditionResult")
assert(result.StateAuthorityIds[1] == "ExpeditionResultService")
assert(result.KindId == config.SurfaceKindIds.ReadOnlyResult)
assert(result.CanRequestMutation == false)

local nextAction = byId["expedition-next-action"]
assert(nextAction.GuiPath == "LK_ExpeditionReplayDecision")
assert(nextAction.StateAuthorityIds[1] == "ExpeditionPartyDecisionService")
assert(nextAction.KindId == config.SurfaceKindIds.DecisionPanel)
assert(nextAction.CanRequestMutation == true)

local ruleById = {}
for _, rule in config.CoexistenceRules do
	ruleById[rule.Id] = rule
end
assert(ruleById["hub-routed-panels-exclusive"] ~= nil)
assert(ruleById["one-exclusive-input-modal"] ~= nil)
assert(ruleById["ambient-hud-may-coexist"] ~= nil)
assert(ruleById["result-before-next-action"] ~= nil)

-- BA-063 is architecture data only. Runtime/UI creation and intent sending stay
-- in their existing controllers and server-authoritative services.
assert(string.find(source, "Instance.new", 1, true) == nil, "BA-063 cannot create UI instances")
assert(string.find(source, "FireServer", 1, true) == nil, "BA-063 cannot fire remotes")
assert(string.find(source, "InvokeServer", 1, true) == nil, "BA-063 cannot invoke server mutation")
assert(string.find(source, "GetService", 1, true) == nil, "BA-063 cannot become a runtime service/controller")
assert(string.find(source, "Enum.KeyCode", 1, true) == nil, "BA-063 must consume BA-061 instead of duplicating action bindings")
assert(string.find(source, "DataStore", 1, true) == nil, "BA-063 cannot own persistence")

print("BA-063 UIInformationArchitectureConfig fixture passed")
