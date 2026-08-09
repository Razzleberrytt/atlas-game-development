--!strict

--[[
	BA-061 input action-map source audit, updated by BA-062 remediation.

	This fixture locks the factual claims in
	`docs/specifications/input-action-map-audit.md` to the source they were read
	from, so the audit cannot silently rot.

	BA-062 closes M1-M5 and C1-C4 in isolated source increments and has landed
	the shared action-map and fail-closed numbered-choice coordination foundations.
]]

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-061 action-map audit assertion failed", 2)
	end
end

local CLIENT = "games/living-kingdoms/src/client/Controllers/"
local SERVER = "games/living-kingdoms/src/server/Systems/"
local SHARED = "games/living-kingdoms/src/shared/Config/"
local AUDIT_PATH = "docs/specifications/input-action-map-audit.md"

local function read(path: string): string
	return fs.readFile(path)
end

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local weapon = read(CLIENT .. "WeaponController.luau")
local mobile = read(CLIENT .. "MobileControlsController.luau")
local survivor = read(CLIENT .. "SurvivorController.luau")
local operativeLife = read(CLIENT .. "OperativeLifeController.luau")
local classAction = read(CLIENT .. "ClassActionController.luau")
local flashlight = read(CLIENT .. "PersonalFlashlightController.luau")
local squadPing = read(CLIENT .. "SquadPingController.luau")
local rpgMenu = read(CLIENT .. "RPGMenuController.luau")
local hubPreparation = read(CLIENT .. "HubPreparationController.luau")
local choiceCoordinator = read(CLIENT .. "ChoiceInputCoordinator.luau")
local hordeHud = read(CLIENT .. "HordeHUDController.luau")
local runBuildHud = read(CLIENT .. "RunBuildHUDController.luau")
local audit = read(AUDIT_PATH)

-- M1 remediation: mouse remains supported, while WeaponController owns one
-- device-neutral ContextActionService surface for gamepad R2 and a generated
-- touch button. Every device converges on the same setFiring/FireIntent path.
assert(contains(weapon, "Enum.UserInputType.MouseButton1"), "mouse firing must remain available")
assert(contains(weapon, 'game:GetService("ContextActionService")'), "fire must use ContextActionService")
assert(contains(weapon, 'FIRE_ACTION_NAME = "LK_Fire"'), "fire action must have one stable semantic action name")
assert(contains(weapon, "Enum.KeyCode.ButtonR2"), "gamepad firing must use the right trigger")
assert(
	contains(weapon, "ContextActionService:BindAction(FIRE_ACTION_NAME, onFireAction, true, Enum.KeyCode.ButtonR2)"),
	"fire must bind gamepad and generated touch input through one CAS action"
)
assert(
	contains(weapon, 'ContextActionService:SetTitle(FIRE_ACTION_NAME, "Fire")'),
	"touch fire button must be labelled"
)
assert(contains(weapon, "ContextActionService:UnbindAction(FIRE_ACTION_NAME)"), "fire action must unbind on stop")
assert(
	contains(weapon, "local function setFiring(isFiring: boolean)"),
	"all fire origins must share one hold-state helper"
)
assert(
	contains(weapon, "fireIntentRemote:FireServer(isFiring, direction)"),
	"fire still uses the existing intent remote"
)
assert(
	not contains(mobile, "FIRE_ACTION") and not contains(mobile, "onFireAction"),
	"MobileControlsController must not become a second fire owner"
)

-- Only WeaponController may originate fire intent.
local fireIntentOwners = 0
for _, path in
	{
		CLIENT .. "WeaponController.luau",
		CLIENT .. "MobileControlsController.luau",
		CLIENT .. "ClassActionController.luau",
		CLIENT .. "HordeHUDController.luau",
		CLIENT .. "RunBuildHUDController.luau",
		CLIENT .. "SurvivorController.luau",
	}
do
	if contains(read(path), "FireIntent") then
		fireIntentOwners += 1
	end
end
assert(fireIntentOwners == 1, "exactly one client controller may own the fire intent remote")

-- M2 remediation: keyboard and touch paths remain intact while gamepad reload
-- and sprint are added at their existing owners. The new CAS actions explicitly
-- do not create touch buttons, so MobileControlsController remains the touch owner.
assert(contains(weapon, "Enum.KeyCode.R"), "reload must remain available on R")
assert(contains(survivor, "Enum.KeyCode.LeftShift"), "sprint must remain available on LeftShift")
assert(contains(mobile, "RELOAD_ACTION") and contains(mobile, "SPRINT_ACTION"), "touch reload and sprint expected")
assert(
	contains(mobile, "UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled"),
	"MobileControlsController must remain touch-without-keyboard only"
)
assert(not contains(mobile, "Enum.KeyCode."), "touch controls must not become a competing gamepad owner")
assert(contains(weapon, 'RELOAD_ACTION_NAME = "LK_Reload"'), "reload needs one stable gamepad action name")
assert(
	contains(
		weapon,
		"ContextActionService:BindAction(RELOAD_ACTION_NAME, onReloadAction, false, Enum.KeyCode.ButtonR1)"
	),
	"gamepad reload must bind R1 without generating a second touch button"
)
assert(contains(weapon, "WeaponController.requestReload()"), "gamepad reload must reuse the one reload request path")
assert(
	contains(weapon, "ContextActionService:UnbindAction(RELOAD_ACTION_NAME)"),
	"gamepad reload must unbind on teardown"
)
assert(contains(survivor, 'SPRINT_ACTION_NAME = "LK_Sprint"'), "sprint needs one stable gamepad action name")
assert(
	contains(
		survivor,
		"ContextActionService:BindAction(SPRINT_ACTION_NAME, onSprintAction, false, Enum.KeyCode.ButtonL3)"
	),
	"gamepad sprint must bind left-stick click without generating a second touch button"
)
assert(
	contains(survivor, "SurvivorController.setSprinting(true)")
		and contains(survivor, "SurvivorController.setSprinting(false)"),
	"gamepad sprint must reuse the shared sprint state path"
)
assert(
	contains(survivor, "ContextActionService:UnbindAction(SPRINT_ACTION_NAME)"),
	"gamepad sprint must unbind on teardown"
)

-- M3 remediation: revive keeps V plus its generated touch button and adds
-- D-pad Down to the same hold action. E and ButtonX remain reserved for prompts.
assert(contains(operativeLife, "Enum.KeyCode.V"), "revive must remain on V")
assert(contains(operativeLife, "Enum.KeyCode.DPadDown"), "revive must add D-pad Down")
assert(not contains(operativeLife, "Enum.KeyCode.E"), "revive must not claim the prompt keyboard key")
assert(not contains(operativeLife, "Enum.KeyCode.ButtonX"), "revive must not claim the prompt gamepad key")
assert(
	contains(
		operativeLife,
		"ContextActionService:BindAction(ACTION_NAME, onReviveAction, true, Enum.KeyCode.V, Enum.KeyCode.DPadDown)"
	),
	"keyboard, gamepad and generated touch revive must share one hold action"
)
assert(contains(operativeLife, "BindAction(ACTION_NAME, onReviveAction, true"), "revive keeps its touch button")

-- C1 remediation: world prompts keep E while Revive stays on V.
assert(contains(operativeLife, "Enum.ContextActionResult.Pass"), "revive may keep passing its distinct inputs through")
local survivalLoot = read(SERVER .. "SurvivalLootService.luau")
assert(contains(survivalLoot, "prompt.KeyboardKeyCode = Enum.KeyCode.E"), "loot prompts must remain on E")
for _, path in
	{
		SERVER .. "RecoveryLootService.luau",
		SERVER .. "AmmunitionCacheService.luau",
		SERVER .. "HubPreparationService.luau",
	}
do
	local source = read(path)
	assert(contains(source, 'Instance.new("ProximityPrompt")'), `{path} is still expected to create a prompt`)
	assert(
		not contains(source, "KeyboardKeyCode"),
		`C1 is stale: {path} now overrides the default prompt key — update the BA-061 audit`
	)
end

-- C2 remediation: class action keeps Q on keyboard but uses B on gamepad,
-- leaving engine-default ButtonX available to ProximityPrompt.
assert(
	contains(classAction, "Enum.KeyCode.Q, Enum.KeyCode.ButtonB"),
	"the class action must use Q and ButtonB after C2 remediation"
)
assert(not contains(classAction, "Enum.KeyCode.ButtonX"), "class action must not claim the prompt gamepad key")
assert(contains(classAction, "Q / GAMEPAD B"), "class-action HUD hint must match the remapped gamepad button")

-- The new M2/M3 keys are distinct from the previously audited gameplay keys.
for _, source in { classAction, flashlight, squadPing, operativeLife } do
	assert(not contains(source, "Enum.KeyCode.ButtonR1"), "R1 reload must have one gameplay owner")
	assert(not contains(source, "Enum.KeyCode.ButtonL3"), "L3 sprint must have one gameplay owner")
end
for _, source in { weapon, survivor, classAction, flashlight, squadPing } do
	assert(not contains(source, "Enum.KeyCode.DPadDown"), "D-pad Down revive must have one gameplay owner")
end

-- C3 remediation: Escape belongs only to the exclusive RPG modal. Hub-routed
-- preparation panels close through the explicit device-neutral CLOSE button.
assert(contains(rpgMenu, "Enum.KeyCode.Escape"), "the exclusive RPG modal must keep Escape")
assert(not contains(hubPreparation, "Enum.KeyCode.Escape"), "the hub router must release Escape ownership")
assert(not contains(hubPreparation, "UserInputService"), "the hub router must not keep a raw close listener")
assert(contains(hubPreparation, "button.Activated:Connect(closeHubUi)"), "hub close must use its GUI affordance")

-- C4 remediation: one coordinator owns direct 1/2/3 detection. Each HUD
-- registers only its local active predicate plus its existing submit callback.
assert(contains(choiceCoordinator, "UserInputService.InputBegan:Connect(onInputBegan)"), "C4 needs one input listener")
for _, keyName in { "One", "Two", "Three", "KeypadOne", "KeypadTwo", "KeypadThree" } do
	assert(contains(choiceCoordinator, `Enum.KeyCode.{keyName}`), `coordinator must map {keyName}`)
end
assert(
	contains(choiceCoordinator, "ChoiceInputConflictResolver.resolve(activeOwnerIds())"),
	"coordinator must use the fail-closed conflict resolver"
)
assert(contains(hordeHud, 'ChoiceInputCoordinator.register("UpgradeChoice"'), "upgrade HUD must register with coordinator")
assert(contains(runBuildHud, 'ChoiceInputCoordinator.register("RelicChoice"'), "relic HUD must register with coordinator")
assert(contains(hordeHud, "return upgradeInputActive"), "upgrade registration must expose its local active state")
assert(contains(runBuildHud, "return choiceInputActive"), "relic registration must expose its local active state")
for _, source in { hordeHud, runBuildHud } do
	assert(not contains(source, "UserInputService.InputBegan:Connect"), "choice HUDs must not keep raw number listeners")
	assert(not contains(source, "Enum.KeyCode.One"), "choice HUDs must not directly own number keys")
	assert(contains(source, "unregisterChoiceInput()"), "choice registration must release on teardown")
end

-- Both choice surfaces keep gamepad selection focus and GUI activation.
for _, source in { hordeHud, runBuildHud } do
	assert(contains(source, "GuiService.SelectedObject"), "choice surfaces must keep gamepad selection focus")
	assert(contains(source, ".Activated:Connect"), "choice surfaces must keep GUI activation")
end

-- Fully covered actions: keyboard plus gamepad plus a generated touch button.
assert(contains(flashlight, "GamepadKeyCodeName"), "flashlight keeps its configured gamepad key")
assert(contains(squadPing, "GamepadKeyCodeName"), "squad ping keeps its configured gamepad key")
local flashlightConfig = read(SHARED .. "PersonalFlashlightConfig.luau")
local squadPingConfig = read(SHARED .. "SquadPingConfig.luau")
assert(contains(flashlightConfig, 'KeyboardKeyCodeName = "F"') and contains(flashlightConfig, "ButtonY"))
assert(contains(squadPingConfig, 'KeyboardKeyCodeName = "G"') and contains(squadPingConfig, "DPadUp"))

-- The shared map foundation now exists and models the single numbered-input owner.
local sharedActionMap = read(SHARED .. "InputActionMapConfig.luau")
assert(contains(sharedActionMap, "ActionOrder"), "the shared semantic action registry must exist")
assert(contains(sharedActionMap, '"NumberedChoiceInput"'), "the map must include the C4 shared input owner")
assert(contains(sharedActionMap, '"OpenCharacter"'), "the map must include Character")
assert(contains(sharedActionMap, '"OpenInventory"'), "the map must include Inventory")
assert(
	contains(rpgMenu, "Shared.Config.InputActionMapConfig"),
	"M5 labels must consume the shared map instead of duplicating shortcut copy"
)

-- The audit stays honest about its own scope and remediation ledger.
assert(contains(audit, "**Roadmap ticket:** BA-061"), "the audit must identify its originating ticket")
assert(contains(audit, "E1"), "the audit must state its evidence level")
for _, finding in { "M1", "M2", "M3", "M4", "M5", "C1", "C2", "C3", "C4" } do
	assert(contains(audit, finding), `the audit must retain finding {finding}`)
end
assert(contains(audit, "C4 — Number keys 1–3 — source-remediated"), "the audit must record C4 remediation")
assert(not contains(audit, "rbxassetid://"), "an input audit invents no asset IDs")

print("BA-061/062 InputActionMapSourceAudit: M1-M5 and C1-C4 are source-remediated; device acceptance remains open")
