--!strict

-- BA-062 device-family fixture. Only observed keyboard/pointer, gamepad, and
-- touch input types should select a presentation family; sensor/unknown types
-- must not silently flip labels.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 input device family assertion failed", 2)
	end
end

local path = "games/living-kingdoms/src/shared/Input/InputDeviceFamilyResolver.luau"
local source = fs.readFile(path)
local resolver = luau.load(source, { debugName = "InputDeviceFamilyResolver", injectGlobals = true })()
local families = resolver.DeviceFamilyIds
local ids = resolver.ResolutionIds

for _, inputTypeName in
	{
		"Keyboard",
		"MouseButton1",
		"MouseButton2",
		"MouseButton3",
		"MouseMovement",
		"MouseWheel",
	}
do
	local resolution = resolver.resolve(inputTypeName)
	assert(resolution.ResolutionId == ids.Classified)
	assert(resolution.DeviceFamilyId == families.KeyboardPointer)
	assert(resolution.InputTypeName == inputTypeName)
end

for index = 1, 8 do
	local inputTypeName = "Gamepad" .. tostring(index)
	local resolution = resolver.resolve(inputTypeName)
	assert(resolution.ResolutionId == ids.Classified)
	assert(resolution.DeviceFamilyId == families.Gamepad)
	assert(resolution.InputTypeName == inputTypeName)
end

local touch = resolver.resolve("Touch")
assert(touch.ResolutionId == ids.Classified)
assert(touch.DeviceFamilyId == families.Touch)
assert(touch.InputTypeName == "Touch")

for _, inputTypeName in
	{
		"None",
		"Accelerometer",
		"Gyro",
		"TextInput",
		"Focus",
		"UnknownFutureInput",
	}
do
	local resolution = resolver.resolve(inputTypeName)
	assert(resolution.ResolutionId == ids.Unknown)
	assert(resolution.DeviceFamilyId == nil)
	assert(resolution.InputTypeName == inputTypeName)
end

for _, invalid in
	{
		"",
		false,
		0,
	}
do
	local resolution = resolver.resolve(invalid)
	assert(resolution.ResolutionId == ids.InvalidInput)
	assert(resolution.DeviceFamilyId == nil)
	assert(resolution.InputTypeName == nil)
end

for _, token in
	{
		"GetService",
		"GetLastInputType",
		"LastInputTypeChanged",
		"InputBegan",
		"BindAction",
		"FireServer",
		"Instance.new",
		"DataStore",
	}
do
	assert(string.find(source, token, 1, true) == nil, `device-family resolver must remain pure: {token}`)
end

print("BA-062 InputDeviceFamilyResolver: observed input classification and unknown fail-safe passed")
