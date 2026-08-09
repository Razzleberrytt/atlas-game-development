--!strict

-- BA-062 M5 label-half fixture. Character/Inventory remain keyboard shortcuts
-- plus GUI launchers; labels must stop advertising keyboard-only shortcuts when
-- the active input family is touch or gamepad.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 device-adaptive RPG menu label assertion failed", 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/RPGMenuController.luau")
local configSource = fs.readFile("games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau")
local config = luau.load(configSource, { debugName = "InputActionMapConfig", injectGlobals = true })()

assert(contains(controller, "Shared.Config.InputActionMapConfig"), "RPG menu labels must read the shared action map")
assert(
	contains(controller, "UserInputService:GetLastInputType()"),
	"initial launcher labels must reflect the active input family"
)
assert(
	contains(controller, "UserInputService.LastInputTypeChanged:Connect(updateLauncherLabels)"),
	"launcher labels must update when the active input family changes"
)
assert(contains(controller, "usesKeyboardShortcutLabels"), "keyboard/pointer label policy must be explicit")
assert(contains(controller, "Enum.UserInputType.Keyboard"), "keyboard input must retain shortcut labels")
assert(contains(controller, "Enum.UserInputType.MouseMovement"), "pointer input must retain keyboard shortcut labels")
assert(contains(controller, 'shortcut .. "   CHARACTER"'), "Character keyboard label must come from the action map")
assert(contains(controller, 'shortcut .. "   INVENTORY"'), "Inventory keyboard label must come from the action map")
assert(contains(controller, 'else "CHARACTER"'), "non-keyboard Character label must omit the shortcut")
assert(contains(controller, 'else "INVENTORY"'), "non-keyboard Inventory label must omit the shortcut")

-- M5 label remediation must not silently change shortcut ownership.
assert(contains(controller, "input.KeyCode == Enum.KeyCode.C"), "Character keyboard shortcut must remain C")
assert(contains(controller, "input.KeyCode == Enum.KeyCode.I"), "Inventory keyboard shortcut must remain I")
assert(not contains(controller, "Enum.KeyCode.Button"), "this slice must not invent a direct gamepad menu shortcut")
assert(not contains(controller, "Enum.KeyCode.DPad"), "this slice must not invent a D-pad menu shortcut")

local openCharacter = config.Actions.OpenCharacter
local openInventory = config.Actions.OpenInventory
assert(openCharacter.KeyboardKeyCodeNames[1] == "C")
assert(openInventory.KeyboardKeyCodeNames[1] == "I")
assert(#openCharacter.GamepadKeyCodeNames == 0, "Character must not advertise an unimplemented gamepad shortcut")
assert(#openInventory.GamepadKeyCodeNames == 0, "Inventory must not advertise an unimplemented gamepad shortcut")
assert(openCharacter.TouchBindingIds[1] == "GuiButton")
assert(openInventory.TouchBindingIds[1] == "GuiButton")

print("BA-062 RPGMenuDeviceAdaptiveLabels: keyboard hints are truthful across input families")
