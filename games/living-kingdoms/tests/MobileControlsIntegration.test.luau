--!strict

-- Mobile touch controls. The thumbstick and reload button feed the exact client
-- intents desktop input already feeds — an analog movement vector and a reload
-- request — through the single owners of those paths, establish no authority, and
-- activate only on a touch device.

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function count(source: string, token: string): number
	local total = 0
	local index = 1
	while true do
		local found = string.find(source, token, index, true)
		if found == nil then
			break
		end
		total += 1
		index = found + 1
	end
	return total
end

local mobile = fs.readFile("games/living-kingdoms/src/client/Controllers/MobileControlsController.luau")
local survivor = fs.readFile("games/living-kingdoms/src/client/Controllers/SurvivorController.luau")
local weapon = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local life = fs.readFile("games/living-kingdoms/src/client/Controllers/OperativeLifeController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

-- The controls activate only on a touch device without a keyboard, so desktop
-- input is never altered.
assertThat(
	contains(mobile, "UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled"),
	"mobile controls must activate only on a touch device without a keyboard"
)
assertThat(contains(mobile, "if started or not isTouchDevice() then"), "start must no-op on a non-touch device")

-- Movement feeds SurvivorController's single analog channel, never a parallel
-- movement path.
assertThat(
	contains(mobile, "SurvivorController.setAnalogMovement("),
	"the thumbstick must feed the survivor analog channel"
)
assertThat(
	contains(survivor, "function SurvivorController.setAnalogMovement(vector: Vector2)"),
	"the survivor controller must own the one analog movement channel"
)
assertThat(
	contains(survivor, "local inputDirection = state.analogMovement"),
	"analog input must be summed into the same direction the keyboard produces"
)
assertThat(
	contains(survivor, "if vector.Magnitude > 1 then vector.Unit else vector"),
	"the analog vector must be clamped so touch can never exceed keyboard input"
)
assertThat(
	contains(survivor, "state.analogMovement = Vector2.zero") and contains(survivor, "clearMovementInput"),
	"clearing movement must also release the analog channel"
)

-- The stick releases to zero on touch end, so a lifted finger stops the operative.
assertThat(
	contains(mobile, "SurvivorController.setAnalogMovement(Vector2.zero)") and contains(mobile, "releaseStick"),
	"releasing the stick must zero the movement intent"
)
assertThat(
	contains(mobile, "-deltaY / STICK_RADIUS"),
	"screen-down must map to backward so the stick matches the WASD forward convention"
)

-- Reload is a ContextActionService touch button in the same auto-arranged cluster
-- as the other actions -- not a hand-placed corner button -- and it routes through
-- WeaponController's one reload path.
assertThat(
	contains(mobile, "ContextActionService:BindAction(RELOAD_ACTION, onReloadAction, true)"),
	"reload must be a ContextAction touch button so Roblox arranges it with the cluster"
)
assertThat(
	contains(mobile, "ContextActionService:UnbindAction(RELOAD_ACTION)"),
	"the reload action must be unbound on teardown"
)
assertThat(
	not contains(mobile, "ReloadButton") and not contains(mobile, ".Activated:Connect"),
	"the hand-placed corner reload button must be gone"
)
assertThat(contains(mobile, "WeaponController.requestReload()"), "the reload button must call the shared reload path")
assertThat(
	contains(weapon, "function WeaponController.requestReload(): boolean"),
	"the weapon controller must expose one reload path"
)
assertThat(
	count(weapon, "reloadIntentRemote:FireServer") == 1,
	"reload must fire from exactly one place, shared by keyboard and touch"
)
assertThat(
	contains(weapon, "WeaponController.requestReload()") and contains(weapon, "input.KeyCode ~= Enum.KeyCode.R"),
	"the keyboard handler must route through the same shared reload path"
)

-- Revive is core co-op and was keyboard-only (E). It now binds through
-- ContextActionService with a touch button, so a mobile squad can rescue a
-- downed teammate, while keeping the exact server intent shape.
assertThat(
	contains(life, "ContextActionService:BindAction(ACTION_NAME, onReviveAction, true, Enum.KeyCode.E)"),
	"revive must bind keyboard E and an auto-created touch button through one action"
)
assertThat(
	contains(life, "inputState == Enum.UserInputState.Begin") and contains(life, "Enum.UserInputState.End"),
	"the revive touch button must hold: Begin on press, End on release"
)
assertThat(
	contains(life, 'phase = "Begin"') and contains(life, 'phase = "End"'),
	"the client revive intent shape must be unchanged"
)
assertThat(
	not contains(life, "UserInputService.InputBegan") and not contains(life, "input.KeyCode ~= Enum.KeyCode.E"),
	"the keyboard-only revive path must be replaced, not duplicated"
)
assertThat(
	not contains(life, "normalizedProgress") and not contains(life, "completionServerTimestamp ="),
	"the client must still declare no revive progress or completion"
)

-- No new authority: the touch controls send no remote of their own and hold no
-- gameplay fact. Movement and reload are the only intents, both via their owners.
for _, forbidden in { "FireServer", "OnServerEvent", "applyAuthoritativeDamage", "Humanoid:Move", "damage", "Health" } do
	assertThat(not contains(mobile, forbidden), "mobile controls must add no authority: " .. forbidden)
end

-- One disclosure of each input surface, and teardown releases every connection
-- and the GUI.
assertThat(
	contains(mobile, "for _, connection in connections do") and contains(mobile, "screenGui:Destroy()"),
	"teardown must release every connection and the GUI"
)

-- Every action touch button defers to ContextActionService's automatic layout, so
-- no controller guesses screen coordinates and the cluster cannot overlap.
for _, controllerName in
	{
		"MobileControlsController",
		"PersonalFlashlightController",
		"SquadPingController",
		"OperativeLifeController",
		"ClassActionController",
	}
do
	local source = fs.readFile("games/living-kingdoms/src/client/Controllers/" .. controllerName .. ".luau")
	assertThat(
		not contains(source, "SetPosition"),
		controllerName .. " must let ContextActionService arrange its touch button, not hand-place it"
	)
end

-- Themed like every other surface, and bootstrapped after the paths it composes.
assertThat(contains(mobile, "InterfaceTheme"), "mobile controls must draw from the shared theme")
assertThat(not contains(mobile, "Color3.fromRGB"), "mobile controls must take colours from the theme")
local survivorStart = string.find(bootstrap, "SurvivorController.start()", 1, true)
local weaponStart = string.find(bootstrap, "WeaponController.start()", 1, true)
local mobileStart = string.find(bootstrap, "MobileControlsController.start()", 1, true)
assertThat(mobileStart ~= nil, "mobile controls must be bootstrapped")
assertThat(
	(survivorStart :: number) < (mobileStart :: number) and (weaponStart :: number) < (mobileStart :: number),
	"mobile controls must start after the movement and reload owners they compose onto"
)

print(
	"MobileControlsIntegration: touch thumbstick, reload, and revive feed the single owner paths with no new authority"
)
