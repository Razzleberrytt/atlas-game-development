--!strict

-- BA-062 shared action-map fixture. The map is descriptive input configuration,
-- not a listener, dispatcher, UI owner, or gameplay authority. This fixture also
-- locks the registry to the current runtime owners so the foundation cannot drift.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 shared action-map assertion failed", 2)
	end
end

local function contains(sourceText: string, token: string): boolean
	return string.find(sourceText, token, 1, true) ~= nil
end

local PATH = "games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau"
local CLIENT = "games/living-kingdoms/src/client/Controllers/"
local SHARED = "games/living-kingdoms/src/shared/Config/"
local SERVER = "games/living-kingdoms/src/server/Systems/"

local source = fs.readFile(PATH)
local config = luau.load(source, { debugName = "InputActionMapConfig", injectGlobals = true })()

assert(config.Version == 1)
assert(#config.ActionOrder == 17, "the canonical map must cover all seventeen audited semantic actions")

local seen = {}
for _, actionId in config.ActionOrder do
	assert(type(actionId) == "string" and actionId ~= "", "action IDs must be non-empty strings")
	assert(not seen[actionId], "action order must not contain duplicates")
	seen[actionId] = true
	local definition = config.get(actionId)
	assert(definition ~= nil, `missing action definition: {actionId}`)
	assert(definition.ActionId == actionId, `definition ID must match map key: {actionId}`)
	assert(type(definition.OwnerId) == "string" and definition.OwnerId ~= "", `missing owner for {actionId}`)
	assert(
		type(definition.MechanismId) == "string" and definition.MechanismId ~= "",
		`missing mechanism for {actionId}`
	)
	assert(type(definition.KeyboardKeyCodeNames) == "table")
	assert(type(definition.MouseInputTypeNames) == "table")
	assert(type(definition.GamepadKeyCodeNames) == "table")
	assert(type(definition.TouchBindingIds) == "table")
end

assert(config.get("NotAnAction") == nil)

local actions = config.Actions
assert(actions.Fire.MouseInputTypeNames[1] == "MouseButton1")
assert(actions.Fire.GamepadKeyCodeNames[1] == "ButtonR2")
assert(actions.Reload.KeyboardKeyCodeNames[1] == "R")
assert(actions.Reload.GamepadKeyCodeNames[1] == "ButtonR1")
assert(actions.Sprint.KeyboardKeyCodeNames[1] == "LeftShift")
assert(actions.Sprint.GamepadKeyCodeNames[1] == "ButtonL3")
assert(actions.ClassAction.KeyboardKeyCodeNames[1] == "Q")
assert(actions.ClassAction.GamepadKeyCodeNames[1] == "ButtonB")
assert(actions.Flashlight.KeyboardKeyCodeNames[1] == "F")
assert(actions.Flashlight.GamepadKeyCodeNames[1] == "ButtonY")
assert(actions.SquadPing.KeyboardKeyCodeNames[1] == "G")
assert(actions.SquadPing.MouseInputTypeNames[1] == "MouseButton3")
assert(actions.SquadPing.GamepadKeyCodeNames[1] == "DPadUp")
assert(actions.Revive.KeyboardKeyCodeNames[1] == "V")
assert(actions.Revive.GamepadKeyCodeNames[1] == "DPadDown")
assert(actions.Interact.KeyboardKeyCodeNames[1] == "E")
assert(actions.Interact.GamepadKeyCodeNames[1] == "ButtonX")

assert(actions.ClassAction.GamepadKeyCodeNames[1] ~= actions.Interact.GamepadKeyCodeNames[1])
assert(actions.Revive.KeyboardKeyCodeNames[1] ~= actions.Interact.KeyboardKeyCodeNames[1])
assert(actions.Revive.GamepadKeyCodeNames[1] ~= actions.Interact.GamepadKeyCodeNames[1])

-- Lock the new registry to the already-accepted runtime source. This stage does
-- not migrate listeners; later isolated increments can replace these literals
-- with lookups without changing the canonical values.
local weapon = fs.readFile(CLIENT .. "WeaponController.luau")
assert(contains(weapon, "Enum.UserInputType.MouseButton1"))
assert(contains(weapon, "Enum.KeyCode.R"))
assert(contains(weapon, "Enum.KeyCode.ButtonR2"))
assert(contains(weapon, "Enum.KeyCode.ButtonR1"))

local survivor = fs.readFile(CLIENT .. "SurvivorController.luau")
assert(contains(survivor, "Enum.KeyCode.LeftShift"))
assert(contains(survivor, "Enum.KeyCode.ButtonL3"))

local classAction = fs.readFile(CLIENT .. "ClassActionController.luau")
assert(contains(classAction, "Enum.KeyCode.Q, Enum.KeyCode.ButtonB"))

local flashlightConfig = fs.readFile(SHARED .. "PersonalFlashlightConfig.luau")
assert(contains(flashlightConfig, 'KeyboardKeyCodeName = "F"'))
assert(contains(flashlightConfig, 'GamepadKeyCodeName = "ButtonY"'))

local pingConfig = fs.readFile(SHARED .. "SquadPingConfig.luau")
assert(contains(pingConfig, 'KeyboardKeyCodeName = "G"'))
assert(contains(pingConfig, 'GamepadKeyCodeName = "DPadUp"'))
local pingController = fs.readFile(CLIENT .. "SquadPingController.luau")
assert(contains(pingController, "Enum.UserInputType.MouseButton3"))

local revive = fs.readFile(CLIENT .. "OperativeLifeController.luau")
assert(contains(revive, "Enum.KeyCode.V, Enum.KeyCode.DPadDown"))
assert(not contains(revive, "Enum.KeyCode.E"))
assert(not contains(revive, "Enum.KeyCode.ButtonX"))

local worldPrompt = fs.readFile(SERVER .. "SurvivalLootService.luau")
assert(contains(worldPrompt, "prompt.KeyboardKeyCode = Enum.KeyCode.E"))

local hordeHud = fs.readFile(CLIENT .. "HordeHUDController.luau")
local runBuildHud = fs.readFile(CLIENT .. "RunBuildHUDController.luau")
for _, hud in { hordeHud, runBuildHud } do
	assert(contains(hud, "Enum.KeyCode.One"))
	assert(contains(hud, "Enum.KeyCode.Two"))
	assert(contains(hud, "Enum.KeyCode.Three"))
	assert(contains(hud, "Enum.KeyCode.KeypadOne"))
end

local rpgMenu = fs.readFile(CLIENT .. "RPGMenuController.luau")
assert(contains(rpgMenu, "Enum.KeyCode.C"))
assert(contains(rpgMenu, "Enum.KeyCode.I"))
assert(contains(rpgMenu, "Enum.KeyCode.Escape"))
local hubPreparation = fs.readFile(CLIENT .. "HubPreparationController.luau")
assert(contains(hubPreparation, "Enum.KeyCode.Escape"))

for _, token in
	{
		"GetService",
		"BindAction",
		"InputBegan",
		"FireServer",
		"InvokeServer",
		"RemoteEvent",
		"DataStore",
		"Instance.new",
		"SetAsync",
		"UpdateAsync",
	}
do
	assert(not contains(source, token), `shared action map must stay configuration-only: {token}`)
end

print("BA-062 InputActionMapConfig: seventeen semantic actions, collision-safe bindings, and runtime parity passed")
