--!strict

--[[
	BA-061 input action-map source audit.

	This fixture locks the factual claims in
	`docs/specifications/input-action-map-audit.md` to the source they were read
	from, so the audit cannot silently rot.

	It deliberately asserts gaps as well as guarantees. When BA-062 fixes one —
	for example by giving firing a gamepad binding — the matching assertion here
	is expected to fail. That failure means "the audit is now out of date",
	not "the fix is wrong": update the audit and this fixture together.
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
local hordeHud = read(CLIENT .. "HordeHUDController.luau")
local runBuildHud = read(CLIENT .. "RunBuildHUDController.luau")
local audit = read(AUDIT_PATH)

-- M1: firing is mouse-only. No gamepad button, no touch button, no
-- ContextActionService binding anywhere in the fire path.
assert(contains(weapon, "Enum.UserInputType.MouseButton1"), "firing is still expected to read MouseButton1")
assert(
	not contains(weapon, "ContextActionService"),
	"M1 is stale: WeaponController now uses ContextActionService — update the BA-061 audit"
)
assert(
	not contains(weapon, "Enum.KeyCode.Button"),
	"M1 is stale: WeaponController now binds a gamepad button — update the BA-061 audit"
)
assert(
	not contains(mobile, "Fire") and not contains(mobile, "fire"),
	"M1 is stale: MobileControlsController now touches the fire path — update the BA-061 audit"
)

-- Only WeaponController may originate fire intent, so the audit's claim that no
-- other surface can start firing stays true.
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

-- M2: reload and sprint are raw keyboard handlers plus a touch-only binding.
assert(contains(weapon, "Enum.KeyCode.R"), "reload is still expected on R")
assert(contains(survivor, "Enum.KeyCode.LeftShift"), "sprint is still expected on LeftShift")
assert(contains(mobile, "RELOAD_ACTION") and contains(mobile, "SPRINT_ACTION"), "touch reload and sprint expected")
assert(
	contains(mobile, "UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled"),
	"MobileControlsController is still expected to start only on touch-without-keyboard devices"
)
assert(
	not contains(mobile, "Enum.KeyCode."),
	"M2 is stale: MobileControlsController now registers key codes — update the BA-061 audit"
)

-- M3: revive binds E with no gamepad key, but does create a touch button.
assert(contains(operativeLife, "Enum.KeyCode.E"), "revive is still expected on E")
assert(
	not contains(operativeLife, "Enum.KeyCode.Button") and not contains(operativeLife, "Enum.KeyCode.DPad"),
	"M3 is stale: revive now has a gamepad binding — update the BA-061 audit"
)
assert(contains(operativeLife, "BindAction(ACTION_NAME, onReviveAction, true"), "revive keeps its touch button")

-- C1: revive shares E with every ProximityPrompt, and does not sink the input.
assert(contains(operativeLife, "Enum.ContextActionResult.Pass"), "revive must keep passing the input through")
local survivalLoot = read(SERVER .. "SurvivalLootService.luau")
assert(contains(survivalLoot, "prompt.KeyboardKeyCode = Enum.KeyCode.E"), "loot prompts are still expected on E")
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

-- C2: the class action claims ButtonX, the engine's default prompt gamepad key.
assert(
	contains(classAction, "Enum.KeyCode.Q, Enum.KeyCode.ButtonX"),
	"the class action is still expected on Q and ButtonX"
)

-- C3: two independent Escape listeners exist, in two controllers.
assert(contains(rpgMenu, "Enum.KeyCode.Escape"), "the RPG modal still closes on Escape")
assert(contains(hubPreparation, "Enum.KeyCode.Escape"), "the hub UI still closes on Escape")

-- C4: two HUDs claim 1/2/3, each guarded only by its own local flag.
assert(contains(hordeHud, "upgradeInputActive"), "the upgrade HUD still guards its own number keys")
assert(contains(runBuildHud, "choiceInputActive"), "the relic HUD still guards its own number keys")
for _, source in { hordeHud, runBuildHud } do
	assert(contains(source, "Enum.KeyCode.One") and contains(source, "Enum.KeyCode.KeypadOne"), "1-3 still claimed")
end

-- Both choice surfaces keep gamepad selection focus: this is the one place
-- device-neutral input is handled deliberately, and it must not regress.
for _, source in { hordeHud, runBuildHud } do
	assert(contains(source, "GuiService.SelectedObject"), "choice surfaces must keep gamepad selection focus")
end

-- Fully covered actions: keyboard plus gamepad plus a generated touch button.
assert(contains(flashlight, "GamepadKeyCodeName"), "flashlight keeps its configured gamepad key")
assert(contains(squadPing, "GamepadKeyCodeName"), "squad ping keeps its configured gamepad key")
local flashlightConfig = read(SHARED .. "PersonalFlashlightConfig.luau")
local squadPingConfig = read(SHARED .. "SquadPingConfig.luau")
assert(contains(flashlightConfig, 'KeyboardKeyCodeName = "F"') and contains(flashlightConfig, "ButtonY"))
assert(contains(squadPingConfig, 'KeyboardKeyCodeName = "G"') and contains(squadPingConfig, "DPadUp"))

-- Exactly two actions are config-driven; the structural finding depends on it.
local configDrivenActions = 0
for _, source in { flashlight, squadPing, weapon, survivor, operativeLife, classAction, rpgMenu, hubPreparation } do
	if contains(source, "KeyboardKeyCodeName") then
		configDrivenActions += 1
	end
end
assert(
	configDrivenActions == 2,
	"the structural finding assumes exactly two config-driven actions — update the BA-061 audit"
)

-- The audit stays honest about its own scope.
assert(contains(audit, "**Roadmap ticket:** BA-061"), "the audit must identify its ticket")
assert(contains(audit, "E1"), "the audit must state its evidence level")
assert(not contains(audit, "rbxassetid://"), "an input audit invents no asset IDs")
for _, finding in { "M1", "M2", "M3", "M4", "M5", "C1", "C2", "C3", "C4" } do
	assert(contains(audit, finding), `the audit must retain finding {finding}`)
end

print("BA-061 InputActionMapSourceAudit: action inventory, missing bindings, and conflicts locked")
