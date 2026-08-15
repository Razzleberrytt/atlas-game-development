--!strict

--[[
	BA-062 device-adaptive HUD hint audit.

	BA-061 found firing bound to the mouse alone; BA-062 fixed the bindings. This
	audit locks the second half of that finding: the HUD must not *tell* a gamepad
	or touch player to press keyboard keys those devices do not have.

	The guarantee held here is "player-facing input hints are resolved from the
	canonical action map per device family", not any one literal sentence. Wording
	may change freely; reintroducing hard-coded device-specific key text may not.

	This is a source/static audit at E1. It cannot prove readability, placement, or
	that the resolved token matches what a real controller reports.
]]

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local hud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")
local runBuild = fs.readFile("games/living-kingdoms/src/client/Controllers/RunBuildHUDController.luau")
local presentation = fs.readFile("games/living-kingdoms/src/shared/Input/InputHintPresentationResolver.luau")
local actionMap = fs.readFile("games/living-kingdoms/src/shared/Config/InputActionMapConfig.luau")

-- Both hint-bearing HUDs resolve through the canonical map and the shared
-- presentation vocabulary rather than owning a private key table.
for _, pair in
	{
		{ Name = "HordeHUDController", Source = hud },
		{ Name = "RunBuildHUDController", Source = runBuild },
	}
do
	for _, required in
		{
			"InputActionMapConfig",
			"InputDeviceFamilyResolver",
			"InputHintPresentationResolver",
			"ActiveInputDeviceFamily.get()",
		}
	do
		assertThat(
			contains(pair.Source, required),
			`{pair.Name} must resolve input hints through the canonical map: missing {required}`
		)
	end
end

-- The combat control strip is the first thing a new player reads. It must be
-- built from the action map, not from a literal keyboard sentence.
assertThat(contains(hud, "CONTROL_STRIP_ENTRIES"), "the combat HUD must build its control strip from the action map")
for _, actionId in { "Move", "Interact", "Reload", "Flashlight" } do
	assertThat(
		contains(hud, `ActionId = "{actionId}"`),
		`the control strip must describe {actionId} through the canonical action map`
	)
end
assertThat(
	not contains(hud, "MOVE  WASD"),
	"the control strip must not hard-code keyboard movement keys for every device"
)
assertThat(
	not contains(hud, "RELOAD  R  "),
	"the control strip must not hard-code the keyboard reload key for every device"
)
assertThat(
	not contains(hud, "FLASHLIGHT  F"),
	"the control strip must not hard-code the keyboard flashlight key for every device"
)

-- Numbered choice shortcuts are keyboard-only. Neither choice surface may print
-- a number prefix or a "press N" call to action unconditionally.
for _, pair in
	{
		{ Name = "HordeHUDController", Source = hud },
		{ Name = "RunBuildHUDController", Source = runBuild },
	}
do
	assertThat(
		contains(pair.Source, 'InputActionMapConfig.get("NumberedChoiceInput")'),
		`{pair.Name} must take its choice keys from the canonical NumberedChoiceInput entry`
	)
	assertThat(
		contains(pair.Source, "choiceButtonPrefix("),
		`{pair.Name} must render the choice index prefix conditionally on the active device`
	)
	assertThat(
		not contains(pair.Source, "[%d]  %s"),
		`{pair.Name} must not hard-code a numeric choice prefix that only keyboard players can use`
	)
end
assertThat(
	not contains(runBuild, "Press 1 or 2, or click."),
	"the relic prompt must not hard-code keyboard/pointer instructions for every device"
)
assertThat(
	not contains(runBuild, "CHOOSE ONE [1 / 2]"),
	"the relic title must not hard-code keyboard choice keys for every device"
)

-- A device switch mid-run must rewrite the hints; a controller picked up after
-- spawn cannot be left reading keyboard text.
assertThat(
	contains(hud, "ActiveInputDeviceFamily.onChanged("),
	"the combat HUD must refresh its hints when the player changes input device"
)
-- The device family must come from the single owner that ignores the engine's
-- non-device `Focus` type; a raw last-input read here would flip a gamepad
-- player's hints to keyboard text on every window focus.
for _, pair in
	{
		{ Name = "HordeHUDController", Source = hud },
		{ Name = "RunBuildHUDController", Source = runBuild },
	}
do
	assertThat(
		not contains(pair.Source, "UserInputService:GetLastInputType()"),
		`{pair.Name} must not re-derive the device family from a raw last-input read`
	)
end

-- The shared vocabulary stays pure and authority-free: it may not bind input,
-- create instances, or touch the network.
for _, forbidden in
	{
		"GetService",
		"BindAction",
		"InputBegan",
		"FireServer",
		"InvokeServer",
		"Instance.new",
	}
do
	assertThat(
		not contains(presentation, forbidden),
		`the shared hint vocabulary must remain a pure resolver: {forbidden}`
	)
end

-- Every gamepad and touch binding the map declares must have a display token, so
-- adding a binding without a token fails here instead of rendering a raw enum
-- name like "ButtonR2" to a player.
for rawName in string.gmatch(actionMap, 'frozenList%("(Button[%w]+)"') do
	assertThat(
		contains(presentation, `{rawName} = "`),
		`gamepad binding {rawName} has no player-facing display token in the shared vocabulary`
	)
end

print("BA-062 device-adaptive HUD hints: canonical map resolution, no hard-coded key text, pure vocabulary passed")
