--!strict

-- BA-062 direct-binding collision fixture. The canonical action map should have
-- no gamepad key-code collisions and exactly the known C4 keyboard overlaps.
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
assert(#canonical.Collisions == 6, "the only canonical direct-key overlap must be C4's six number keys")

local expectedKeyboardTokens = {
	One = true,
	Two = true,
	Three = true,
	KeypadOne = true,
	KeypadTwo = true,
	KeypadThree = true,
}
local seenKeyboardTokens = {}
for _, collision in canonical.Collisions do
	assert(collision.FamilyId == families.Keyboard, "canonical gamepad direct bindings must remain collision-free")
	assert(expectedKeyboardTokens[collision.BindingToken] == true, `unexpected canonical collision: {collision.BindingToken}`)
	assert(not seenKeyboardTokens[collision.BindingToken], "canonical collision tokens must be unique")
	seenKeyboardTokens[collision.BindingToken] = true
	assert(#collision.ActionIds == 2)
	assert(collision.ActionIds[1] == "RelicChoice")
	assert(collision.ActionIds[2] == "UpgradeChoice")
end
for token in expectedKeyboardTokens do
	assert(seenKeyboardTokens[token] == true, `missing expected C4 collision: {token}`)
end

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

print("BA-062 InputBindingCollisionAnalyzer: only C4 keyboard collisions remain; gamepad keys are collision-free")
