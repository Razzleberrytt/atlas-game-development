--!strict

--[[
	Regression fixture for a live Studio defect found on 2026-08-09.

	`UserInputService:GetLastInputType()` returned `Focus` — the engine reports
	window focus through the same channel as real input, alongside `TextInput`,
	`InputMethod` and `None`. Every hint surface classified that as "not a
	keyboard" and silently rewrote its labels: the observed symptom was the
	Character/Inventory launcher losing its `C` / `I` hints on a keyboard-only
	machine. The same fault would rewrite a gamepad player's combat hints as
	keyboard text the moment they alt-tabbed back into the game.

	The rule locked here: unclassifiable input retains the previously adopted
	family. It never resolves to one, and it never falls back to keyboard.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local resolverPath = "games/living-kingdoms/src/shared/Input/InputDeviceFamilyResolver.luau"
local ownerPath = "games/living-kingdoms/src/client/State/ActiveInputDeviceFamily.luau"
local resolverSource = fs.readFile(resolverPath)
local ownerSource = fs.readFile(ownerPath)
local resolver = luau.load(resolverSource, { debugName = "InputDeviceFamilyResolver", injectGlobals = true })()
local families = resolver.DeviceFamilyIds

-- Real devices are adopted normally.
assertThat(resolver.adopt("Keyboard", nil) == families.KeyboardPointer, "keyboard input must adopt keyboard/pointer")
assertThat(resolver.adopt("MouseMovement", nil) == families.KeyboardPointer, "mouse input must adopt keyboard/pointer")
assertThat(resolver.adopt("Gamepad1", nil) == families.Gamepad, "gamepad input must adopt gamepad")
assertThat(resolver.adopt("Touch", nil) == families.Touch, "touch input must adopt touch")

-- A real device replaces a different previous device.
assertThat(resolver.adopt("Gamepad1", families.KeyboardPointer) == families.Gamepad, "a real device change applies")
assertThat(resolver.adopt("Touch", families.Gamepad) == families.Touch, "a real device change applies")

-- The defect: non-device input types must retain the previous family. `Focus` is
-- the one actually observed in Studio; the others share its shape.
for _, nonDevice in { "Focus", "TextInput", "InputMethod", "None", "Accelerometer", "Gyro" } do
	assertThat(
		resolver.adopt(nonDevice, families.Gamepad) == families.Gamepad,
		`{nonDevice} must not displace an active gamepad`
	)
	assertThat(
		resolver.adopt(nonDevice, families.Touch) == families.Touch,
		`{nonDevice} must not displace an active touch device`
	)
	assertThat(
		resolver.adopt(nonDevice, families.KeyboardPointer) == families.KeyboardPointer,
		`{nonDevice} must not displace an active keyboard`
	)
	assertThat(resolver.adopt(nonDevice, nil) == nil, `{nonDevice} must not invent a family from nothing`)
end

-- Malformed input behaves the same way: retain, never guess.
assertThat(resolver.adopt(nil, families.Gamepad) == families.Gamepad, "nil input must retain the active family")
assertThat(resolver.adopt("", families.Gamepad) == families.Gamepad, "empty input must retain the active family")
assertThat(resolver.adopt(42, families.Touch) == families.Touch, "non-string input must retain the active family")
assertThat(resolver.adopt(nil, nil) == nil, "nil input with no history must stay unresolved")

-- The shared resolver stays pure.
for _, forbidden in { "GetService", "InputBegan", "BindAction", "FireServer", "Instance.new" } do
	assertThat(not contains(resolverSource, forbidden), `device-family resolver must remain pure: {forbidden}`)
end

-- The client owner is the single place that observes input for this purpose and
-- delegates the decision rather than re-implementing it.
for _, required in
	{
		"InputDeviceFamilyResolver.adopt(",
		"LastInputTypeChanged",
		"function ActiveInputDeviceFamily.get()",
		"function ActiveInputDeviceFamily.onChanged(",
	}
do
	assertThat(contains(ownerSource, required), `the active-device owner is missing {required}`)
end

-- It reports a fact only: no gameplay authority, no presentation, no network.
for _, forbidden in { "FireServer", "InvokeServer", "ScreenGui", "TextLabel", "BindAction" } do
	assertThat(not contains(ownerSource, forbidden), `the active-device owner must own no gameplay or UI: {forbidden}`)
end

-- Consumers must route through the owner rather than reading last input directly.
for _, consumer in
	{
		"src/client/Controllers/HordeHUDController.luau",
		"src/client/Controllers/RunBuildHUDController.luau",
		"src/client/Controllers/RPGMenuController.luau",
		"src/client/Controllers/SquadPingController.luau",
	}
do
	local source = fs.readFile("games/living-kingdoms/" .. consumer)
	assertThat(contains(source, "ActiveInputDeviceFamily"), `{consumer} must use the shared active-device owner`)
	assertThat(
		not contains(source, "UserInputService:GetLastInputType()"),
		`{consumer} must not re-derive the device family from a raw last-input read`
	)
end

print("BA-062 ActiveInputDeviceFamily: non-device input retains the active family across every hint surface")
