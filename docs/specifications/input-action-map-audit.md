# PC / mobile / controller action-map audit

**Roadmap ticket:** BA-061

**Lane:** controlled build-ahead, P6 onboarding/input/UI preparation

**Status:** audit complete; BA-062 M1 and C1/C2 source remediations applied, remaining findings open

**Evidence level:** E1 source/static only — no Studio device testing was performed

**Playable-patch mapping:** MVP 0.1 device-parity input; remaining remediation belongs to BA-062 and Patch 0.2

**Runtime behavior:** BA-062 changes only client input origins/bindings; server combat, revive, class-action and prompt authority are unchanged

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

BA-062's second isolated remediation closes the two hard prompt-key conflicts.
Revive moves from keyboard `E` to `V`, leaving the engine-default keyboard
`ProximityPrompt` key `E` exclusively available to contextual world
interaction. The class action keeps keyboard `Q` but moves gamepad from
`ButtonX` to `ButtonB`, leaving the engine-default gamepad prompt key `ButtonX`
exclusively available to contextual world interaction. The class-action HUD hint
moves with the binding from `GAMEPAD X` to `GAMEPAD B`.

Reload, sprint and revive still lack complete gamepad coverage. C3/C4 and the
broader shared-action-map/device-adaptive-label work also remain open.

This document therefore remains the BA-061 source audit plus its BA-062
remediation ledger. Device behavior is not accepted until a later Studio/device
pass verifies the source changes on actual controller and touch surfaces.

## Method and limits

Every finding below is read from source in `games/living-kingdoms/src/client`
and `games/living-kingdoms/src/server/Systems`, and is locked by
`tests/InputActionMapSourceAudit.test.luau`.

This remains **E1** evidence. No device was tested. Specifically unverified:

- whether the generated Fire touch button is reachable, correctly sized or
  non-overlapping on a real phone;
- whether holding/releasing `ButtonR2` produces the intended feel on a real
  controller;
- whether `V` is a comfortable/discoverable keyboard Revive binding in actual
  first-person play;
- whether `ButtonB` is a comfortable/discoverable class-action binding on a
  real controller;
- whether gamepad UI navigation actually reaches every button;
- any latency, comfort or discoverability judgement.

Those belong to the consolidated Studio device pass.

## Binding mechanisms in use

| Mechanism | Device reach | Used by |
|---|---|---|
| `ContextActionService:BindAction(..., true, keys...)` | keyboard/gamepad and/or generated touch button, depending on registered keys | 6 actions after current BA-062 remediations |
| Raw `UserInputService.InputBegan/InputEnded` | keyboard and mouse only | 8 actions; fire now supplements its mouse path with CAS |
| Engine `ProximityPrompt` | keyboard `E`, gamepad `ButtonX`, touch tap — engine defaults/current explicit keyboard value | all world interaction |
| Roblox `PlayerModule` | full native coverage | move, jump, camera |
| GUI `Activated` + `GuiService.SelectedObject` | pointer, touch, gamepad selection focus | 2 choice surfaces |

The third `BindAction` argument (`createTouchButton`) is `true` for the current
`ContextActionService` actions, including BA-062's Fire and Revive actions.

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
| Class action (Brace) | `ClassActionController` | Q | — | **ButtonB** | button | CAS |
| Flashlight | `PersonalFlashlightController` | F | — | ButtonY | button | CAS (config-driven) |
| Squad ping | `SquadPingController` | G | MouseButton3 | DPadUp | button | CAS (config-driven) |
| Revive ally | `OperativeLifeController` | **V** | — | **—** | button | CAS |
| Interact / collect | server `ProximityPrompt`s | E | — | ButtonX | tap prompt | engine |
| Upgrade choice 1–3 | `HordeHUDController` | 1–3, Keypad 1–3 | click | selection focus | tap | raw UIS + GUI |
| Relic choice 1–3 | `RunBuildHUDController` | 1–3, Keypad 1–3 | click | selection focus | tap | raw UIS + GUI |
| Open Character panel | `RPGMenuController` | C | click | UI navigation | tap | raw UIS + GUI |
| Open Inventory panel | `RPGMenuController` | I | click | UI navigation | tap | raw UIS + GUI |
| Close RPG modal | `RPGMenuController` | Escape | click | UI navigation | tap | raw UIS + GUI |
| Close hub UI | `HubPreparationController` | Escape | — | **—** | **—** | raw UIS |

Only two actions are config-driven: `PersonalFlashlightConfig` and
`SquadPingConfig` each expose `KeyboardKeyCodeName` and `GamepadKeyCodeName`.
The other fifteen still hardcode their bindings inside controllers. The current
BA-062 increments intentionally do not jump ahead to the later shared-action-map
increment.

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

`OperativeLifeController` now binds `ContextActionService` with
`Enum.KeyCode.V` only. Because `createTouchButton` is `true`, touch players do
get a Revive button, but no gamepad button is registered. Reviving is a
co-op-critical verb. Moving keyboard Revive to `V` closes C1 but does not close
this gamepad-coverage gap.

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

### C1 — `E` / Revive prompt collision — source-remediated by BA-062

Before the second BA-062 increment, `OperativeLifeController` bound `E` through
`ContextActionService` while every world interaction used `E` through
`ProximityPrompt`. Because Revive returned `Enum.ContextActionResult.Pass`, one
keypress near both a downed ally and a prompt could drive both paths.

The remediation moves Revive to keyboard `V`. World interaction remains on
`E`; no prompt key is changed and the revive handler may continue returning
`Pass` because it no longer shares the prompt key. Revive targeting, Begin/End
intent shape, hold duration and server authority are unchanged.

**Source status:** remediated.  
**Runtime/device status:** unverified until the consolidated keyboard/touch
Studio pass.

### C2 — `ButtonX` / class-action prompt collision — source-remediated by BA-062

Before the second BA-062 increment, `ClassActionController` bound
`Enum.KeyCode.ButtonX` while the engine's default `ProximityPrompt` gamepad key
was also `ButtonX`.

The remediation keeps class action keyboard `Q` and generated touch behavior,
but moves the gamepad binding to `Enum.KeyCode.ButtonB`. World interaction
remains on the native `ButtonX` prompt key. The HUD hint is updated to
`Q / GAMEPAD B`; class-action request shape, targeting hints, cooldown logic and
server authority are unchanged.

**Source status:** remediated.  
**Runtime/device status:** unverified until the consolidated controller Studio
pass.

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

None of the following broad options are implemented by the current BA-062
remediations. They remain considerations for later BA-062/Patch 0.2 work.

| Consideration | Current state |
|---|---|
| Rebinding | No action can be rebound. Fifteen of seventeen remain hardcoded; two are config constants that are not player-facing. |
| Hold vs. toggle | Sprint, fire and revive are hold-only. No toggle alternative. |
| Hold duration | Revive's hold length is not adjustable. |
| One-handed / reduced-mobility play | Simultaneous hold-sprint plus hold-fire plus aim is required with no alternative. |
| Keyboard-only play | Firing still requires a mouse button; there is no keyboard fire. |
| Pointer-free play | Cursor is locked to centre (`MouseBehavior.LockCenter`) except while `LK_InputModalOpen` is set. |
| Input labelling | Prompt and button labels are not globally device-adaptive; BA-062 only updates the one class-action hint affected by C2. |
| Choice surfaces | Upgrade and relic choices support cursor, keyboard and gamepad selection focus via `GuiService.SelectedObject`. |
| Device detection | `MobileControlsController` still adapts via `TouchEnabled and not KeyboardEnabled`; the Fire CAS action is no longer dependent on that controller. |

## Structural finding

There is still no shared action map. Ten controllers own their own bindings, so:

- the full action surface cannot be listed, diffed or validated from one place;
- a new controller can silently claim a key another controller already uses;
- device coverage remains inconsistent outside the completed BA-062 slices;
- rebinding and device-adaptive labelling have nowhere to live.

`PersonalFlashlightConfig` and `SquadPingConfig` still show the config-driven
shape the other fifteen actions lack.

## Recommended remediation order

BA-062 remains an umbrella of isolated, merge-after-each increments. Do not
bundle later items together merely because they share this ticket.

1. **M1 — device-neutral firing:** source-remediated by BA-062. Confirm on real
   controller/touch hardware during the consolidated Studio pass.
2. **C1 and C2 — prompt-key collisions:** source-remediated by BA-062. Revive is
   now `V`, class action is now `Q` / `ButtonB`, and contextual world prompts
   retain `E` / `ButtonX` / touch.
3. **M3 and M2 — add gamepad bindings for revive, reload and sprint.**
4. **Introduce a shared action map** covering all seventeen actions, following
   the two existing configs, so BA-063's UI work and future rebinding have one
   surface.
5. **M4 and M5 — device-neutral close affordance and device-adaptive labels.**

Accessibility options (rebinding, hold/toggle, hold duration) should follow the
action map rather than precede it.

## Completion boundary

BA-061 remains complete at E1. BA-062's first increment changes only client
fire input mapping; its second increment changes only conflicting client input
bindings and the matching class-action hint. Server ownership of shots,
cadence, ammunition, targeting, damage, revive truth, class-action truth and
world-interaction consequences is unchanged.

The Studio/device pass remains outstanding. Source/static acceptance proves
only that firing is exposed to mouse, `ButtonR2` and touch; Revive no longer
claims `E`; class action no longer claims `ButtonX`; and world prompts retain
their contextual keys. BA-062 should continue one isolated remediation at a
time, with M3/M2 gamepad coverage next.
