--!strict

-- BA-062 source-drift guard. The canonical semantic input map must stay aligned
-- with the live client bindings that have already been source-remediated.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 input action map source drift assertion failed", 2)
	end
end

local root = "games/living-kingdoms/"
local function read(relativePath: string): string
	return fs.readFile(root .. relativePath)
end

local function load(relativePath: string, debugName: string)
	return luau.load(read(relativePath), { debugName = debugName, injectGlobals = true })()
end

local actionMap = load("src/shared/Config/InputActionMapConfig.luau", "InputActionMapConfig")
local flashlightConfig = load("src/shared/Config/PersonalFlashlightConfig.luau", "PersonalFlashlightConfig")
local pingConfig = load("src/shared/Config/SquadPingConfig.luau", "SquadPingConfig")

local weaponSource = read("src/client/Controllers/WeaponController.luau")
local survivorSource = read("src/client/Controllers/SurvivorController.luau")
local classActionSource = read("src/client/Controllers/ClassActionController.luau")
local reviveSource = read("src/client/Controllers/OperativeLifeController.luau")
local flashlightSource = read("src/client/Controllers/PersonalFlashlightController.luau")
local pingSource = read("src/client/Controllers/SquadPingController.luau")

local function only(list: { string }, expected: string, label: string)
	assert(#list == 1, `{label} must expose exactly one direct binding`)
	assert(list[1] == expected, `{label} expected {expected}, got {tostring(list[1])}`)
end

local fire = actionMap.Actions.Fire
assert(fire.OwnerId == "WeaponController")
assert(#fire.KeyboardKeyCodeNames == 0)
only(fire.MouseInputTypeNames, "MouseButton1", "Fire mouse")
only(fire.GamepadKeyCodeNames, "ButtonR2", "Fire gamepad")
only(fire.TouchBindingIds, "GeneratedActionButton", "Fire touch")
assert(string.find(weaponSource, "Enum.UserInputType.MouseButton1", 1, true) ~= nil)
assert(string.find(weaponSource, "Enum.KeyCode.ButtonR2", 1, true) ~= nil)

local reload = actionMap.Actions.Reload
only(reload.KeyboardKeyCodeNames, "R", "Reload keyboard")
only(reload.GamepadKeyCodeNames, "ButtonR1", "Reload gamepad")
assert(string.find(weaponSource, "Enum.KeyCode.R", 1, true) ~= nil)
assert(string.find(weaponSource, "Enum.KeyCode.ButtonR1", 1, true) ~= nil)

local sprint = actionMap.Actions.Sprint
only(sprint.KeyboardKeyCodeNames, "LeftShift", "Sprint keyboard")
only(sprint.GamepadKeyCodeNames, "ButtonL3", "Sprint gamepad")
assert(string.find(survivorSource, "Enum.KeyCode.LeftShift", 1, true) ~= nil)
assert(string.find(survivorSource, "Enum.KeyCode.ButtonL3", 1, true) ~= nil)

local classAction = actionMap.Actions.ClassAction
only(classAction.KeyboardKeyCodeNames, "Q", "Class action keyboard")
only(classAction.GamepadKeyCodeNames, "ButtonB", "Class action gamepad")
assert(string.find(classActionSource, "Enum.KeyCode.Q", 1, true) ~= nil)
assert(string.find(classActionSource, "Enum.KeyCode.ButtonB", 1, true) ~= nil)
assert(
	string.find(classActionSource, "Enum.KeyCode.ButtonX", 1, true) == nil,
	"class action must not reclaim prompt ButtonX"
)

local revive = actionMap.Actions.Revive
only(revive.KeyboardKeyCodeNames, "V", "Revive keyboard")
only(revive.GamepadKeyCodeNames, "DPadDown", "Revive gamepad")
assert(string.find(reviveSource, "Enum.KeyCode.V", 1, true) ~= nil)
assert(string.find(reviveSource, "Enum.KeyCode.DPadDown", 1, true) ~= nil)
assert(string.find(reviveSource, "Enum.KeyCode.E", 1, true) == nil, "revive must not reclaim prompt E")

local interact = actionMap.Actions.Interact
assert(interact.OwnerId == "WorldPrompts")
assert(interact.MechanismId == "EnginePrompt")
only(interact.KeyboardKeyCodeNames, "E", "Interact keyboard")
only(interact.GamepadKeyCodeNames, "ButtonX", "Interact gamepad")
only(interact.TouchBindingIds, "PromptTap", "Interact touch")

local flashlight = actionMap.Actions.Flashlight
only(flashlight.KeyboardKeyCodeNames, flashlightConfig.KeyboardKeyCodeName, "Flashlight keyboard")
only(flashlight.GamepadKeyCodeNames, flashlightConfig.GamepadKeyCodeName, "Flashlight gamepad")
assert(string.find(flashlightSource, "PersonalFlashlightConfig.KeyboardKeyCodeName", 1, true) ~= nil)
assert(string.find(flashlightSource, "PersonalFlashlightConfig.GamepadKeyCodeName", 1, true) ~= nil)

local ping = actionMap.Actions.SquadPing
only(ping.KeyboardKeyCodeNames, pingConfig.KeyboardKeyCodeName, "Squad ping keyboard")
only(ping.MouseInputTypeNames, "MouseButton3", "Squad ping mouse")
only(ping.GamepadKeyCodeNames, pingConfig.GamepadKeyCodeName, "Squad ping gamepad")
assert(string.find(pingSource, "SquadPingConfig.KeyboardKeyCodeName", 1, true) ~= nil)
assert(string.find(pingSource, "SquadPingConfig.GamepadKeyCodeName", 1, true) ~= nil)
assert(string.find(pingSource, "Enum.UserInputType.MouseButton3", 1, true) ~= nil)

print("BA-062 InputActionMap source drift: remediated live bindings match canonical map")
