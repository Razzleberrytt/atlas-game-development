--!strict

-- BA-062 shared action-map fixture. The map is descriptive input configuration,
-- not a listener, dispatcher, UI owner, or gameplay authority.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 shared action-map assertion failed", 2)
	end
end

local PATH = "games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau"
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
	assert(type(definition.MechanismId) == "string" and definition.MechanismId ~= "", `missing mechanism for {actionId}`)
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

for _, token in {
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
} do
	assert(not string.find(source, token, 1, true), `shared action map must stay configuration-only: {token}`)
end

print("BA-062 InputActionMapConfig: seventeen semantic actions and collision-safe core bindings passed")
