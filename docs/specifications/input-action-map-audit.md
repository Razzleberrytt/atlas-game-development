# PC / mobile / controller action-map audit

**Roadmap ticket:** BA-061

**Lane:** controlled build-ahead, P6 onboarding/input/UI preparation

**Status:** audit complete; BA-062 M1 source remediation applied, remaining findings open

**Evidence level:** E1 source/static only — no Studio device testing was performed

**Playable-patch mapping:** MVP 0.1 device-parity input; remaining remediation belongs to BA-062 and Patch 0.2

**Runtime behavior:** BA-062 changes only the client fire-input origin; server combat authority is unchanged

## Decision

Atlas's semantic action surface is still **not fully device-neutral**. Seventeen
player actions are bound across ten client controllers with no shared action
map, and the split between `ContextActionService` and raw
`UserInputService.InputBegan` still makes device coverage inconsistent.

BA-062's first isolated remediation closes the critical M1 source gap: firing
now keeps `MouseButton1` and adds `ButtonR2` plus a generated touch **Fire**
button through `ContextActionService`. All three input origins converge on the
same `WeaponController.setFiring` hold state and the existing `FireIntent`
remote. No second client fire owner or server combat authority was added.

Reload, sprint and revive still lack complete gamepad coverage. Two hard binding
conflicts also remain between controller-owned actions and the engine's
`ProximityPrompt` defaults: `E` (revive vs. every prompt) and `ButtonX` (class
action vs. every prompt on gamepad).

This document therefore remains the BA-061 source audit plus its BA-062
remediation ledger. Device behavior is not accepted until a later Studio/device
pass verifies the source change on actual controller and touch surfaces.

## Method and limits

Every finding below is read from source in `games/living-kingdoms/src/client`
and `games/living-kingdoms/src/server/Systems`, and is locked by
`tests/InputActionMapSourceAudit.test.luau`.

This remains **E1** evidence. No device was tested. Specifically unverified:

- whether the generated Fire touch button is reachable, correctly sized or
  non-overlapping on a real phone;
- whether holding/releasing `ButtonR2` produces the intended feel on a real
  controller;
- whether gamepad UI navigation actually reaches every button;
- whether the engine's default `ProximityPrompt` gamepad button behaves as
  documented alongside a competing `ContextActionService` binding;
- any latency, comfort or discoverability judgement.

Those belong to the consolidated Studio device pass.

## Binding mechanisms in use

| Mechanism | Device reach | Used by |
|---|---|---|
| `ContextActionService:BindAction(..., true, keys...)` | keyboard/gamepad and/or generated touch button, depending on registered keys | 6 actions after BA-062 M1 |
| Raw `UserInputService.InputBegan/InputEnded` | keyboard and mouse only | 8 actions; fire now supplements its mouse path with CAS |
| Engine `ProximityPrompt` | keyboard `E`, gamepad `ButtonX`, touch tap — all engine defaults | all world interaction |
| Roblox `PlayerModule` | full native coverage | move, jump, camera |
| GUI `Activated` + `GuiService.SelectedObject` | pointer, touch, gamepad selection focus | 2 choice surfaces |

The third `BindAction` argument (`createTouchButton`) is `true` for the current
`ContextActionService` actions, including BA-062's Fire action.

## Action inventory

`—` means the action has no binding on that device.

| Semantic action | Owner | Keyboard | Mouse | Gamepad | Touch | Mechanism |
|---|---|---|---|---|---|---|
| Move | Roblox `PlayerModule` | WASD | — | left stick | thumbstick | engine |
| Jump | Roblox `PlayerModule` | Space | — | ButtonA | button | engine |
| Camera look | `PlayerModule` + `CameraController` | — | mouse | right stick | drag | engine |
| **Fire weapon** | `WeaponController` | — | MouseButton1 | **ButtonR2** | **Fire button** | raw UIS + CAS |
| Reload | `WeaponController`, `MobileControlsController` | R | — | **—** | button | raw UIS + touch-only CAS |
| Sprint | `SurvivorController`, `MobileControlsController` | LeftShift | — | **—** | button | raw UIS + touch-only CAS |
| Class action (Brace) | `ClassActionController` | Q | — | ButtonX | button | CAS |
| Flashlight | `PersonalFlashlightController` | F | — | ButtonY | button | CAS (config-driven) |
| Squad ping | `SquadPingController` | G | MouseButton3 | DPadUp | button | CAS (config-driven) |
| Revive ally | `OperativeLifeController` | E | — | **—** | button | CAS |
| Interact / collect | server `ProximityPrompt`s | E | — | ButtonX | tap prompt | engine |
| Upgrade choice 1–3 | `HordeHUDController` | 1–3, Keypad 1–3 | click | selection focus | tap | raw UIS + GUI |
| Relic choice 1–3 | `RunBuildHUDController` | 1–3, Keypad 1–3 | click | selection focus | tap | raw UIS + GUI |
| Open Character panel | `RPGMenuController` | C | click | UI navigation | tap | raw UIS + GUI |
| Open Inventory panel | `RPGMenuController` | I | click | UI navigation | tap | raw UIS + GUI |
| Close RPG modal | `RPGMenuController` | Escape | click | UI navigation | tap | raw UIS + GUI |
| Close hub UI | `HubPreparationController` | Escape | — | **—** | **—** | raw UIS |

Only two actions are config-driven: `PersonalFlashlightConfig` and
`SquadPingConfig` each expose `KeyboardKeyCodeName` and `GamepadKeyCodeName`.
The other fifteen still hardcode their bindings inside controllers. BA-062's M1
fix intentionally does not jump ahead to the later shared-action-map increment.

## Missing bindings / remediation ledger

### M1 — Firing device coverage — source-remediated by BA-062

Before BA-062, `WeaponController` sent fire intent only from
`MouseButton1`, leaving gamepad and touch unable to attack.

The first BA-062 increment keeps that mouse path and adds a single
`ContextActionService` action named `LK_Fire`, registered with
`createTouchButton = true` and `Enum.KeyCode.ButtonR2`. Begin, End and Cancel
all feed the same `setFiring` helper used by mouse input; that helper is the only
local hold-state transition and still calls the existing `FireIntent` remote.
`MobileControlsController` is deliberately not made a second fire owner.

**Source status:** remediated.  
**Runtime/device status:** unverified until the consolidated controller/touch
Studio pass.

### M2 — Reload and sprint have no gamepad binding

Both are raw `UserInputService` keyboard handlers (`R`, `LeftShift`) with a
touch button supplied separately by `MobileControlsController`, which only
starts when `TouchEnabled and not KeyboardEnabled`. A gamepad player on a
desktop gets neither the keyboard key nor the touch button.

### M3 — Revive has no gamepad binding

`OperativeLifeController` binds `ContextActionService` with `Enum.KeyCode.E`
only. Because `createTouchButton` is `true`, touch players do get a Revive
button, but no gamepad button is registered. Reviving is a co-op-critical verb.

### M4 — Hub UI close is keyboard-only

`HubPreparationController` closes only on `Escape` from a raw
`UserInputService` listener. `Escape` is reserved by the Roblox client for its
own menu on every platform, and there is no gamepad or touch close affordance
in this controller.

### M5 — Panel shortcuts are keyboard-only, and their labels assume keyboard

`C` and `I` have no gamepad or touch shortcut equivalent. The panels themselves
*are* reachable — `RPGMenuController` creates on-screen buttons and a close
button, so pointer, touch and gamepad UI navigation work. But those buttons are
labelled `"C   CHARACTER"` and `"I   INVENTORY"`, showing a keyboard key to
players who have no keyboard.

## Conflicts

### C1 — `E` is bound to both Revive and every ProximityPrompt

`OperativeLifeController` binds `E` through `ContextActionService` and returns
`Enum.ContextActionResult.Pass`, so it does not sink the input. Every world
interaction is a `ProximityPrompt` on the default keyboard key `E`:
`SurvivalLootService` sets `KeyboardKeyCode = Enum.KeyCode.E` explicitly, and
`RecoveryLootService`, `AmmunitionCacheService` and `HubPreparationService`
leave the default, which is also `E`.

A player standing near a downed ally and a loot container presses `E` and drives
both paths. This remains the next isolated BA-062 remediation target.

### C2 — `ButtonX` is bound to both the class action and every ProximityPrompt

`ClassActionController` binds `Enum.KeyCode.ButtonX` for Brace. `ButtonX` is
also the engine's default `ProximityPrompt` gamepad button. The same collision
as C1 remains on gamepad, against a different action.

### C3 — Two independent `Escape` listeners

`RPGMenuController` and `HubPreparationController` each open their own
`UserInputService.InputBegan` connection for `Escape` and neither knows about
the other. One press runs both handlers. Today each is guarded by its own
visibility check so the effect is usually benign, but nothing coordinates them,
and `Escape` is reserved by the Roblox client regardless.

### C4 — Number keys 1–3 are claimed by two HUDs

`HordeHUDController` (upgrade choices) and `RunBuildHUDController` (relic
choices) each open their own `InputBegan` listener for `1/2/3` and `Keypad1-3`.
Each is guarded by its own local flag — `upgradeInputActive` and
`choiceInputActive` — but neither consults the other. If an upgrade offer and a
relic choice are ever active at once, one keypress submits to both. No code
prevents that overlap; only the current pacing does.

## Accessibility considerations

None of the following broad options are implemented by the M1 remediation.
They remain considerations for later BA-062/Patch 0.2 work.

| Consideration | Current state |
|---|---|
| Rebinding | No action can be rebound. Fifteen of seventeen remain hardcoded; two are config constants that are not player-facing. |
| Hold vs. toggle | Sprint, fire and revive are hold-only. No toggle alternative. |
| Hold duration | Revive's hold length is not adjustable. |
| One-handed / reduced-mobility play | Simultaneous hold-sprint plus hold-fire plus aim is required with no alternative. |
| Keyboard-only play | Firing still requires a mouse button; there is no keyboard fire. |
| Pointer-free play | Cursor is locked to centre (`MouseBehavior.LockCenter`) except while `LK_InputModalOpen` is set. |
| Input labelling | Prompt and button labels are keyboard-worded (`"C   CHARACTER"`) and do not adapt to the active device. |
| Choice surfaces | Upgrade and relic choices support cursor, keyboard and gamepad selection focus via `GuiService.SelectedObject`. |
| Device detection | `MobileControlsController` still adapts via `TouchEnabled and not KeyboardEnabled`; the Fire CAS action is no longer dependent on that controller. |

## Structural finding

There is still no shared action map. Ten controllers own their own bindings, so:

- the full action surface cannot be listed, diffed or validated from one place;
- a new controller can silently claim a key another controller already uses;
- device coverage remains inconsistent outside the M1 remediation;
- rebinding and device-adaptive labelling have nowhere to live.

`PersonalFlashlightConfig` and `SquadPingConfig` still show the config-driven
shape the other fifteen actions lack.

## Recommended remediation order

BA-062 remains an umbrella of isolated, merge-after-each increments. The first
item is complete in source; do not bundle later items together merely because
they share this ticket.

1. **M1 — device-neutral firing:** source-remediated by BA-062. Confirm on real
   controller/touch hardware during the consolidated Studio pass.
2. **C1 and C2 — resolve the `E` and `ButtonX` collisions.** Either move Revive
   and Brace off the prompt keys, or make prompts and contextual actions share
   one arbitration owner. Do not solve it by blindly sinking the input, which
   would break world interaction.
3. **M3 and M2 — add gamepad bindings for revive, reload and sprint.**
4. **Introduce a shared action map** covering all seventeen actions, following
   the two existing configs, so BA-063's UI work and future rebinding have one
   surface.
5. **M4 and M5 — device-neutral close affordance and device-adaptive labels.**

Accessibility options (rebinding, hold/toggle, hold duration) should follow the
action map rather than precede it.

## Completion boundary

BA-061 remains complete at E1. BA-062's first increment changes only client
input mapping and does not raise the evidence level: source now exposes firing
to mouse, `ButtonR2`, and a generated touch button through one owner, while
server authority for shots, cadence, ammunition, targeting and damage is
unchanged. The Studio device pass that verifies touch-button reachability and
controller behavior remains outstanding. BA-062 should continue one isolated
remediation at a time, with C1/C2 next.
