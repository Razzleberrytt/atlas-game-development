--!strict

-- BA-062 device-binding hint fixture. Presentation may expose only shortcuts or
-- touch surfaces that the canonical action map actually records for that family.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 input binding hint assertion failed", 2)
	end
end

local resolverPath = "games/living-kingdoms/src/shared/Input/InputBindingHintResolver.luau"
local mapPath = "games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau"
local resolverSource = fs.readFile(resolverPath)
local mapSource = fs.readFile(mapPath)
local resolver = luau.load(resolverSource, { debugName = "InputBindingHintResolver", injectGlobals = true })()
local actionMap = luau.load(mapSource, { debugName = "InputActionMapConfig", injectGlobals = true })()
local families = resolver.DeviceFamilyIds
local ids = resolver.ResolutionIds
local sources = resolver.BindingSourceIds

local characterKeyboard = resolver.resolve(actionMap.Actions.OpenCharacter, families.KeyboardPointer)
assert(characterKeyboard.ResolutionId == ids.Available)
assert(characterKeyboard.BindingSourceId == sources.Keyboard)
assert(characterKeyboard.BindingToken == "C")

local fireKeyboardPointer = resolver.resolve(actionMap.Actions.Fire, families.KeyboardPointer)
assert(fireKeyboardPointer.ResolutionId == ids.Available)
assert(fireKeyboardPointer.BindingSourceId == sources.Mouse)
assert(fireKeyboardPointer.BindingToken == "MouseButton1")

local fireGamepad = resolver.resolve(actionMap.Actions.Fire, families.Gamepad)
assert(fireGamepad.ResolutionId == ids.Available)
assert(fireGamepad.BindingToken == "ButtonR2")

local reviveGamepad = resolver.resolve(actionMap.Actions.Revive, families.Gamepad)
assert(reviveGamepad.ResolutionId == ids.Available)
assert(reviveGamepad.BindingToken == "DPadDown")

local interactTouch = resolver.resolve(actionMap.Actions.Interact, families.Touch)
assert(interactTouch.ResolutionId == ids.Available)
assert(interactTouch.BindingSourceId == sources.Touch)
assert(interactTouch.BindingToken == "PromptTap")

local hubTouch = resolver.resolve(actionMap.Actions.CloseHubUI, families.Touch)
assert(hubTouch.ResolutionId == ids.Available)
assert(hubTouch.BindingToken == "GuiButton")

local characterGamepad = resolver.resolve(actionMap.Actions.OpenCharacter, families.Gamepad)
assert(characterGamepad.ResolutionId == ids.Unavailable)
assert(characterGamepad.BindingToken == nil, "GUI navigation must not be advertised as a direct gamepad shortcut")

local hubGamepad = resolver.resolve(actionMap.Actions.CloseHubUI, families.Gamepad)
assert(hubGamepad.ResolutionId == ids.Unavailable)
assert(hubGamepad.BindingToken == nil)

local invalidFamily = resolver.resolve(actionMap.Actions.Fire, "Telepathy")
assert(invalidFamily.ResolutionId == ids.InvalidDeviceFamily)
assert(invalidFamily.BindingToken == nil)

local invalidAction = resolver.resolve({}, families.KeyboardPointer)
assert(invalidAction.ResolutionId == ids.InvalidAction)
assert(invalidAction.BindingToken == nil)

for _, token in {
	"GetService",
	"InputBegan",
	"BindAction",
	"FireServer",
	"InvokeServer",
	"RemoteEvent",
	"Instance.new",
	"DataStore",
	"SetAsync",
	"UpdateAsync",
} do
	assert(string.find(resolverSource, token, 1, true) == nil, `hint resolver must remain pure: {token}`)
end

print("BA-062 InputBindingHintResolver: truthful keyboard/pointer, gamepad, and touch hints passed")
