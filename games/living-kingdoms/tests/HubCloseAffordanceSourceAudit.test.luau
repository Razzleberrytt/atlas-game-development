--!strict

-- BA-062 M4/C3 source audit. Hub preparation screens expose one explicit GUI
-- close path for pointer, touch, and gamepad UI navigation; Escape is reserved
-- for the exclusive RPG modal instead of being claimed by two UI owners.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 hub close affordance assertion failed", 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/HubPreparationController.luau")
local mapSource = fs.readFile("games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau")
local actionMap = luau.load(mapSource, { debugName = "InputActionMapConfig", injectGlobals = true })()

assert(contains(controller, 'gui.Name = "HubCloseAffordance"'), "hub router must create one close affordance surface")
assert(contains(controller, 'button.Name = "Close"'), "close affordance must be a stable GUI button")
assert(contains(controller, 'button.Text = "CLOSE"'), "close affordance must use truthful device-neutral copy")
assert(contains(controller, "button.Selectable = true"), "close affordance must participate in gamepad GUI navigation")
assert(contains(controller, "button.Activated:Connect(closeHubUi)"), "all GUI activation paths must reuse closeHubUi")
assert(contains(controller, "setCloseAffordanceVisible(true)"), "opening a hub screen must reveal the close control")
assert(contains(controller, "setCloseAffordanceVisible(false)"), "closing hub screens must hide the close control")
assert(not contains(controller, "UserInputService"), "hub routed panels must not keep an independent raw close listener")
assert(not contains(controller, "Enum.KeyCode.Escape"), "Escape must not remain claimed by the hub router")
assert(not contains(controller, "Enum.KeyCode.ButtonB"), "hub close must not steal the class-action gamepad key")
assert(not contains(controller, "Enum.KeyCode.ButtonX"), "hub close must not steal the world-interaction gamepad key")
assert(not contains(controller, "Enum.KeyCode.DPad"), "hub close must not invent a D-pad close shortcut")

local closeHub = actionMap.Actions.CloseHubUI
assert(closeHub.MechanismId == "GuiOnly")
assert(#closeHub.KeyboardKeyCodeNames == 0, "hub close must not advertise an Escape shortcut after C3")
assert(closeHub.MouseInputTypeNames[1] == "MouseButton1")
assert(#closeHub.GamepadKeyCodeNames == 0, "hub close must not advertise an unimplemented direct gamepad key")
assert(closeHub.TouchBindingIds[1] == "GuiButton")

print("BA-062 HubCloseAffordance: GUI close retained and duplicate Escape ownership removed")
