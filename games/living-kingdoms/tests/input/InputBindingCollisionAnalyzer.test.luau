--!strict

-- BA-062 direct-binding collision fixture. After C4, the canonical action map
-- must have zero duplicate direct keyboard/gamepad key-code claims.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 input collision analyzer assertion failed", 2)
	end
end

local analyzerPath = "games/living-kingdoms/src/shared/Input/InputBindingCollisionAnalyzer.luau"
local mapPath = "games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau"
local analyzerSource = fs.readFile(analyzerPath)
local mapSource = fs.readFile(mapPath)
local analyzer = luau.load(analyzerSource, { debugName = "InputBindingCollisionAnalyzer", injectGlobals = true })()
local actionMap = luau.load(mapSource, { debugName = "InputActionMapConfig", injectGlobals = true })()
local families = analyzer.FamilyIds
local errors = analyzer.ErrorIds

local canonical = analyzer.analyze(actionMap.ActionOrder, actionMap.Actions)
assert(canonical.Valid == true)
assert(canonical.ErrorId == nil)
assert(#canonical.Collisions == 0, "canonical direct keyboard/gamepad bindings must remain collision-free")

local syntheticActions = {
	Alpha = {
		KeyboardKeyCodeNames = {},
		GamepadKeyCodeNames = { "ButtonX" },
	},
	Beta = {
		KeyboardKeyCodeNames = {},
		GamepadKeyCodeNames = { "ButtonX" },
	},
}
local synthetic = analyzer.analyze({ "Beta", "Alpha" }, syntheticActions)
assert(synthetic.Valid == true)
assert(#synthetic.Collisions == 1)
assert(synthetic.Collisions[1].FamilyId == families.Gamepad)
assert(synthetic.Collisions[1].BindingToken == "ButtonX")
assert(synthetic.Collisions[1].ActionIds[1] == "Alpha")
assert(synthetic.Collisions[1].ActionIds[2] == "Beta")

local syntheticKeyboardActions = {
	Alpha = {
		KeyboardKeyCodeNames = { "One" },
		GamepadKeyCodeNames = {},
	},
	Beta = {
		KeyboardKeyCodeNames = { "One" },
		GamepadKeyCodeNames = {},
	},
}
local syntheticKeyboard = analyzer.analyze({ "Alpha", "Beta" }, syntheticKeyboardActions)
assert(syntheticKeyboard.Valid == true)
assert(#syntheticKeyboard.Collisions == 1)
assert(syntheticKeyboard.Collisions[1].FamilyId == families.Keyboard)
assert(syntheticKeyboard.Collisions[1].BindingToken == "One")

local duplicateOrder = analyzer.analyze({ "Alpha", "Alpha" }, syntheticActions)
assert(duplicateOrder.Valid == false)
assert(duplicateOrder.ErrorId == errors.InvalidActionOrder)

local missingAction = analyzer.analyze({ "Missing" }, {})
assert(missingAction.Valid == false)
assert(missingAction.ErrorId == errors.MissingAction)

local invalidList = analyzer.analyze({ "Broken" }, {
	Broken = {
		KeyboardKeyCodeNames = "Q",
		GamepadKeyCodeNames = {},
	},
})
assert(invalidList.Valid == false)
assert(invalidList.ErrorId == errors.InvalidBindingList)

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
	}
do
	assert(string.find(analyzerSource, token, 1, true) == nil, `collision analyzer must remain pure: {token}`)
end

print("BA-062 InputBindingCollisionAnalyzer: canonical direct keyboard/gamepad bindings are collision-free")
