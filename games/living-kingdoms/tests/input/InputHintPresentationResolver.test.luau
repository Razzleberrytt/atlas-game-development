--!strict

-- BA-062 shared hint-presentation fixture. The display vocabulary must stay pure,
-- must convert canonical action-map bindings into player-facing tokens, and must
-- report absence rather than inventing a shortcut the device does not have.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 hint presentation assertion failed", 2)
	end
end

local presentationPath = "games/living-kingdoms/src/shared/Input/InputHintPresentationResolver.luau"
local hintPath = "games/living-kingdoms/src/shared/Input/InputBindingHintResolver.luau"
local mapPath = "games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau"

local presentationSource = fs.readFile(presentationPath)
local hintResolver =
	luau.load(fs.readFile(hintPath), { debugName = "InputBindingHintResolver", injectGlobals = true })()
local actionMap = luau.load(fs.readFile(mapPath), { debugName = "InputActionMapConfig", injectGlobals = true })()

local hintToken = { "InputBindingHintResolver" }
local scriptStub = { Parent = { InputBindingHintResolver = hintToken } }

local resolver = luau.load(presentationSource, {
	debugName = "InputHintPresentationResolver",
	injectGlobals = true,
	environment = {
		script = scriptStub,
		require = function(target: unknown)
			assert(target == hintToken, "presentation resolver required an unexpected dependency")
			return hintResolver
		end,
	},
})()

local families = resolver.DeviceFamilyIds
local ids = resolver.ResolutionIds
local sources = resolver.BindingSourceIds

-- Raw binding names become short player-facing tokens; unmapped single keys pass through.
assert(resolver.displayToken("ButtonR2") == "RT")
assert(resolver.displayToken("ButtonX") == "X")
assert(resolver.displayToken("DPadDown") == "↓")
assert(resolver.displayToken("Thumbstick1") == "L STICK")
assert(resolver.displayToken("MouseButton1") == "LMB")
assert(resolver.displayToken("One") == "1")
assert(resolver.displayToken("R") == "R", "an unmapped single key must pass through unchanged")
assert(resolver.displayToken("") == nil)
assert(resolver.displayToken(42) == nil)

-- Move reports every keyboard key of the one selected source, so a strip can render WASD.
local moveKeyboard = resolver.resolve(actionMap.Actions.Move, families.KeyboardPointer, { Separator = "" })
assert(moveKeyboard.ResolutionId == ids.Available)
assert(moveKeyboard.BindingSourceId == sources.Keyboard)
assert(#moveKeyboard.Tokens == 4)
assert(moveKeyboard.Text == "WASD", `expected WASD, got {tostring(moveKeyboard.Text)}`)

local moveGamepad = resolver.resolve(actionMap.Actions.Move, families.Gamepad)
assert(moveGamepad.Text == "L STICK")

local moveTouch = resolver.resolve(actionMap.Actions.Move, families.Touch)
assert(moveTouch.BindingSourceId == sources.Touch)
assert(moveTouch.Text == "THUMBSTICK")

-- Interact is the loot verb: it must read correctly on all three families.
assert(resolver.resolveText(actionMap.Actions.Interact, families.KeyboardPointer) == "E")
assert(resolver.resolveText(actionMap.Actions.Interact, families.Gamepad) == "X")
assert(resolver.resolveText(actionMap.Actions.Interact, families.Touch) == "TAP PROMPT")

-- Reload and flashlight carry the BA-062 gamepad bindings rather than keyboard text.
assert(resolver.resolveText(actionMap.Actions.Reload, families.KeyboardPointer) == "R")
assert(resolver.resolveText(actionMap.Actions.Reload, families.Gamepad) == "RB")
assert(resolver.resolveText(actionMap.Actions.Flashlight, families.Gamepad) == "Y")
assert(resolver.resolveText(actionMap.Actions.Fire, families.Gamepad) == "RT")
assert(resolver.resolveText(actionMap.Actions.Fire, families.KeyboardPointer) == "LMB")

-- Numbered choice input is keyboard-only and must bound how many tokens it shows.
local choiceKeyboard =
	resolver.resolve(actionMap.Actions.NumberedChoiceInput, families.KeyboardPointer, { MaximumTokens = 3 })
assert(choiceKeyboard.ResolutionId == ids.Available)
assert(#choiceKeyboard.Tokens == 3, "numbered choice must respect the token bound")
assert(choiceKeyboard.Text == "1 / 2 / 3")

local choiceTwo =
	resolver.resolve(actionMap.Actions.NumberedChoiceInput, families.KeyboardPointer, { MaximumTokens = 2 })
assert(choiceTwo.Text == "1 / 2")

-- The critical negative: numbers are not a gamepad or touch shortcut, so the
-- resolver must report absence instead of leaking keyboard text onto a controller.
local choiceGamepad = resolver.resolve(actionMap.Actions.NumberedChoiceInput, families.Gamepad)
assert(choiceGamepad.ResolutionId == ids.Unavailable)
assert(choiceGamepad.Text == nil)
assert(#choiceGamepad.Tokens == 0)

local choiceTouch = resolver.resolve(actionMap.Actions.NumberedChoiceInput, families.Touch)
assert(choiceTouch.ResolutionId == ids.Unavailable)
assert(choiceTouch.Text == nil)

-- GUI navigation is still never advertised as a direct gamepad shortcut.
assert(resolver.resolveText(actionMap.Actions.OpenCharacter, families.Gamepad) == nil)
assert(resolver.resolveText(actionMap.Actions.CloseHubUI, families.Gamepad) == nil)

-- Invalid inputs stay inert.
local invalidFamily = resolver.resolve(actionMap.Actions.Fire, "Telepathy")
assert(invalidFamily.ResolutionId == ids.InvalidDeviceFamily)
assert(invalidFamily.Text == nil)

local invalidAction = resolver.resolve({}, families.KeyboardPointer)
assert(invalidAction.ResolutionId == ids.InvalidAction)
assert(invalidAction.Text == nil)

assert(resolver.resolveText(nil, families.KeyboardPointer) == nil)

-- Results are frozen so a HUD cannot mutate shared presentation state.
local frozen = resolver.resolve(actionMap.Actions.Interact, families.Gamepad)
assert(table.isfrozen(frozen))
assert(table.isfrozen(frozen.Tokens))

-- Every gamepad binding the canonical map declares must have a short display token.
for actionId, action in actionMap.Actions do
	for _, rawName in action.GamepadKeyCodeNames do
		local token = resolver.displayToken(rawName)
		assert(token ~= nil, `{actionId} gamepad binding {rawName} has no display token`)
		assert(#token <= 8, `{actionId} gamepad token {token} is too long for a HUD hint; add a DisplayTokens entry`)
	end
end

-- Purity: presentation may not listen for input, build instances, or reach the network.
for _, token in
	{
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
	}
do
	assert(string.find(presentationSource, token, 1, true) == nil, `hint presentation must remain pure: {token}`)
end

print("BA-062 InputHintPresentationResolver: device tokens, bounded choice hints, and absence reporting passed")
