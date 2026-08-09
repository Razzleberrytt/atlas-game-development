--!strict

-- Mobile touch controls supplement Roblox's native PlayerModule movement with a
-- reload action and never establish a second movement owner.

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
-- input is never altered by the touch-only controller.
assertThat(
	contains(mobile, "UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled"),
	"mobile controls must activate only on a touch device without a keyboard"
)
assertThat(contains(mobile, "if started or not isTouchDevice() then"), "start must no-op on a non-touch device")

-- Roblox PlayerModule is the one movement owner on every input platform.
assertThat(
	contains(survivor, "playerModule:GetControls()"),
	"the survivor controller must acquire Roblox's native controls"
)
assertThat(
	contains(survivor, "state.playerControls = controls") and contains(survivor, "controls:Enable()"),
	"native controls must be retained and explicitly enabled once acquired"
)
-- Acquisition is bounded and off the bootstrap thread. This controller starts
-- ahead of every HUD, weapon, enemy and expedition owner, so an unbounded wait on
-- a place-template module that a `rojo build` place may not carry would stall the
-- whole client instead of only native movement.
assertThat(
	not contains(survivor, 'WaitForChild("PlayerModule")'),
	"PlayerModule must never be awaited without a timeout"
)
assertThat(
	contains(survivor, "PLAYER_MODULE_WAIT_SECONDS") and contains(survivor, "task.spawn"),
	"native controls must be acquired with a bounded wait off the bootstrap thread"
)
assertThat(not contains(survivor, ":Disable()"), "the survivor controller must never disable Roblox's native controls")
assertThat(
	not contains(survivor, "Humanoid:Move") and not contains(survivor, "RenderStepped"),
	"the survivor controller must not inject competing per-frame movement"
)
assertThat(
	not contains(mobile, "MovementZone") and not contains(mobile, "setAnalogMovement"),
	"mobile must use PlayerModule's native touch stick instead of a duplicate"
)
assertThat(
	contains(survivor, "MovementLimits.SprintingSpeed") and contains(survivor, "MovementLimits.WalkingSpeed"),
	"native humanoid movement must support shared walking and sprint speeds"
)
assertThat(contains(survivor, "Enum.KeyCode.LeftShift"), "desktop sprint must use the conventional shift key")
assertThat(
	contains(
		survivor,
		"ContextActionService:BindAction(SPRINT_ACTION_NAME, onSprintAction, false, Enum.KeyCode.ButtonL3)"
	),
	"gamepad sprint must reuse the survivor owner without creating a touch button"
)
assertThat(
	contains(mobile, "ContextActionService:BindAction(SPRINT_ACTION, onSprintAction, true)"),
	"touch players require a dedicated sprint action"
)

-- Reload is a ContextActionService touch button in the same auto-arranged cluster
-- as the other actions -- not a hand-placed corner button -- and both touch and
-- gamepad route through WeaponController's one reload path.
assertThat(
	contains(mobile, "ContextActionService:BindAction(RELOAD_ACTION, onReloadAction, true)"),
	"reload must be a ContextAction touch button so Roblox arranges it with the cluster"
)
assertThat(
	contains(
		weapon,
		"ContextActionService:BindAction(RELOAD_ACTION_NAME, onReloadAction, false, Enum.KeyCode.ButtonR1)"
	),
	"gamepad reload must reuse the weapon owner without creating a touch button"
)
assertThat(
	contains(mobile, "ContextActionService:UnbindAction(RELOAD_ACTION)"),
	"the touch reload action must be unbound on teardown"
)
assertThat(
	contains(weapon, "ContextActionService:UnbindAction(RELOAD_ACTION_NAME)"),
	"the gamepad reload action must be unbound on teardown"
)
assertThat(
	not contains(mobile, "ReloadButton") and not contains(mobile, ".Activated:Connect"),
	"the hand-placed corner reload button must be gone"
)
assertThat(
	contains(mobile, "WeaponController.requestReload()"),
	"the touch reload button must call the shared reload path"
)
assertThat(
	contains(weapon, "function WeaponController.requestReload(): boolean"),
	"the weapon controller must expose one reload path"
)
assertThat(
	count(weapon, "reloadIntentRemote:FireServer") == 1,
	"reload must fire from exactly one place, shared by keyboard, gamepad and touch"
)
assertThat(
	contains(weapon, "WeaponController.requestReload()") and contains(weapon, "input.KeyCode ~= Enum.KeyCode.R"),
	"the keyboard handler must route through the same shared reload path"
)

-- Revive is core co-op. One ContextActionService action serves keyboard V,
-- gamepad D-pad Down and the auto-created touch button, keeping E/ButtonX free
-- for world prompts while preserving the exact server intent shape.
assertThat(
	contains(
		life,
		"ContextActionService:BindAction(ACTION_NAME, onReviveAction, true, Enum.KeyCode.V, Enum.KeyCode.DPadDown)"
	),
	"revive must bind keyboard, gamepad and auto-created touch through one action"
)
assertThat(
	contains(life, "inputState == Enum.UserInputState.Begin") and contains(life, "Enum.UserInputState.End"),
	"the revive touch/gamepad hold must use Begin on press and End on release"
)
assertThat(
	contains(life, 'phase = "Begin"') and contains(life, 'phase = "End"'),
	"the client revive intent shape must be unchanged"
)
assertThat(
	not contains(life, "UserInputService.InputBegan") and not contains(life, "input.KeyCode ~= Enum.KeyCode.V"),
	"the raw keyboard-only revive path must remain gone"
)
assertThat(
	not contains(life, "normalizedProgress") and not contains(life, "completionServerTimestamp ="),
	"the client must still declare no revive progress or completion"
)

-- No new authority: the touch controls send no remote of their own and hold no
-- gameplay fact. Movement and reload are intents routed via their existing owners.
for _, forbidden in { "FireServer", "OnServerEvent", "applyAuthoritativeDamage", "Humanoid:Move", "damage", "Health" } do
	assertThat(not contains(mobile, forbidden), "mobile controls must add no authority: " .. forbidden)
end

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

-- Bootstrapped after the paths it composes.
local survivorStart = string.find(bootstrap, "SurvivorController.start()", 1, true)
local weaponStart = string.find(bootstrap, "WeaponController.start()", 1, true)
local mobileStart = string.find(bootstrap, "MobileControlsController.start()", 1, true)
assertThat(mobileStart ~= nil, "mobile controls must be bootstrapped")
assertThat(
	(survivorStart :: number) < (mobileStart :: number) and (weaponStart :: number) < (mobileStart :: number),
	"mobile controls must start after the movement and reload owners they compose onto"
)

print("MobileControlsIntegration: native touch plus gamepad core actions add no new authority")
