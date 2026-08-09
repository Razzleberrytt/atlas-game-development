# PC / mobile / controller action-map audit

**Roadmap ticket:** BA-061

**Lane:** controlled build-ahead, P6 onboarding/input/UI preparation

**Status:** audit complete; BA-062 M1-M3 and C1/C2 source remediations applied, remaining findings open

**Evidence level:** E1 source/static only — no Studio device testing was performed

**Playable-patch mapping:** MVP 0.1 device-parity input; remaining remediation belongs to BA-062 and Patch 0.2

**Runtime behavior:** BA-062 changes only client input origins/bindings; server combat, movement, revive, class-action and prompt authority are unchanged

## Decision

Atlas's semantic action surface is still **not fully centralized or device-adaptive**. Seventeen
player actions remain distributed across ten client controllers with no shared action
map, and the split between `ContextActionService` and raw
`UserInputService.InputBegan` still makes the whole surface difficult to inspect from
one place.

BA-062's first isolated remediation closed the critical M1 source gap: firing
keeps `MouseButton1` and adds `ButtonR2` plus a generated touch **Fire** button
through `ContextActionService`. All three input origins converge on the same
`WeaponController.setFiring` hold state and the existing `FireIntent` remote.

BA-062's second isolated remediation closed the two hard prompt-key conflicts.
Revive moved from keyboard `E` to `V`, leaving contextual world interaction on
`E`. The class action kept keyboard `Q` but moved gamepad from `ButtonX` to
`ButtonB`, leaving contextual world interaction on `ButtonX`. The class-action
HUD hint moved with the binding.

BA-062's third isolated remediation closes the remaining M2/M3 gamepad coverage
gaps for the core playable loop:

- reload keeps keyboard `R` and the existing mobile reload button while adding
  gamepad `ButtonR1` at `WeaponController`;
- sprint keeps keyboard `LeftShift` and the existing mobile sprint button while
  adding gamepad `ButtonL3` at `SurvivorController`;
- revive keeps keyboard `V` and its generated touch button while adding gamepad
  `DPadDown` to the same revive hold action.

Reload and sprint gamepad bindings use `createTouchButton = false`, so they do
not duplicate the touch actions already owned by `MobileControlsController`.
All new inputs feed the existing owner methods rather than creating new gameplay
authority.

C3/C4, the shared-action-map gap, device-adaptive labels, close affordances and
accessibility/rebinding work remain open. Device behavior is not accepted until
a later Studio/device pass verifies these source changes on actual controller
and touch surfaces.

## Method and limits

Every finding below is read from source in `games/living-kingdoms/src/client`
and `games/living-kingdoms/src/server/Systems`, and is locked by
`tests/InputActionMapSourceAudit.test.luau`.

This remains **E1** evidence. No device was tested. Specifically unverified:

- whether the generated Fire touch button is reachable, correctly sized or
  non-overlapping on a real phone;
- whether holding/releasing `ButtonR2` produces the intended feel on a real
  controller;
- whether `ButtonR1` reload is comfortable and does not conflict with any
  Studio/place-level controller behavior outside this source tree;
- whether `ButtonL3` sprint feels reliable during simultaneous movement/look;
- whether `DPadDown` revive is comfortable and discoverable during co-op play;
- whether `V` is a comfortable/discoverable keyboard Revive binding in actual
  first-person play;
- whether `ButtonB` is a comfortable/discoverable class-action binding on a
  real controller;
- whether gamepad UI navigation actually reaches every button;
- any latency, comfort or discoverability judgement.

Those belong to the consolidated Studio/device pass.

## Binding mechanisms in use

| Mechanism | Device reach | Used by |
|---|---|---|
| `ContextActionService:BindAction(..., true/false, keys...)` | keyboard/gamepad and optionally generated touch buttons | fire, reload gamepad, sprint gamepad, class action, flashlight, ping, revive, and mobile action surfaces |
| Raw `UserInputService.InputBegan/InputEnded` | keyboard and mouse | legacy/direct keyboard and mouse paths retained where already authoritative |
| Engine `ProximityPrompt` | keyboard `E`, gamepad `ButtonX`, touch tap | contextual world interaction |
| Roblox `PlayerModule` | full native coverage | move, jump, camera |
| GUI `Activated` + `GuiService.SelectedObject` | pointer, touch, gamepad selection focus | choice surfaces and menu buttons |

The third `BindAction` argument (`createTouchButton`) remains `true` where a
generated touch control is intended, such as Fire and Revive. The new reload and
sprint gamepad bindings explicitly use `false` because their existing touch
buttons remain in `MobileControlsController`.

## Action inventory

`—` means the action has no direct binding on that device.

| Semantic action | Owner | Keyboard | Mouse | Gamepad | Touch | Mechanism |
|---|---|---|---|---|---|---|
| Move | Roblox `PlayerModule` | WASD | — | left stick | thumbstick | engine |
| Jump | Roblox `PlayerModule` | Space | — | ButtonA | button | engine |
| Camera look | `PlayerModule` + `CameraController` | — | mouse | right stick | drag | engine |
| **Fire weapon** | `WeaponController` | — | MouseButton1 | **ButtonR2** | **Fire button** | raw UIS + CAS |
| Reload | `WeaponController`, `MobileControlsController` | R | — | **ButtonR1** | button | raw UIS + owner CAS + touch CAS |
| Sprint | `SurvivorController`, `MobileControlsController` | LeftShift | — | **ButtonL3** | button | raw UIS + owner CAS + touch CAS |
| Class action (Brace) | `ClassActionController` | Q | — | **ButtonB** | button | CAS |
| Flashlight | `PersonalFlashlightController` | F | — | ButtonY | button | CAS (config-driven) |
| Squad ping | `SquadPingController` | G | MouseButton3 | DPadUp | button | CAS (config-driven) |
| Revive ally | `OperativeLifeController` | **V** | — | **DPadDown** | button | CAS |
| Interact / collect | server `ProximityPrompt`s | E | — | ButtonX | tap prompt | engine |
| Upgrade choice 1–3 | `HordeHUDController` | 1–3, Keypad 1–3 | click | selection focus | tap | raw UIS + GUI |
| Relic choice 1–3 | `RunBuildHUDController` | 1–3, Keypad 1–3 | click | selection focus | tap | raw UIS + GUI |
| Open Character panel | `RPGMenuController` | C | click | UI navigation | tap | raw UIS + GUI |
| Open Inventory panel | `RPGMenuController` | I | click | UI navigation | tap | raw UIS + GUI |
| Close RPG modal | `RPGMenuController` | Escape | click | UI navigation | tap | raw UIS + GUI |
| Close hub UI | `HubPreparationController` | Escape | — | **—** | **—** | raw UIS |

Only two actions are config-driven: `PersonalFlashlightConfig` and
`SquadPingConfig` expose keyboard and gamepad key names. The other fifteen still
hardcode bindings inside controllers. The current BA-062 increments intentionally
do not jump ahead to the later shared-action-map increment.

## Missing bindings / remediation ledger

### M1 — Firing device coverage — source-remediated by BA-062

Before BA-062, `WeaponController` sent fire intent only from `MouseButton1`,
leaving gamepad and touch unable to attack.

The first BA-062 increment keeps that mouse path and adds a single
`ContextActionService` action named `LK_Fire`, registered with
`createTouchButton = true` and `Enum.KeyCode.ButtonR2`. Begin, End and Cancel
feed the same `setFiring` helper used by mouse input; that helper remains the one
local hold-state transition and still calls the existing `FireIntent` remote.

**Source status:** remediated.  
**Runtime/device status:** unverified until the consolidated controller/touch
Studio pass.

### M2 — Reload and sprint gamepad coverage — source-remediated by BA-062

Before the third BA-062 increment, reload and sprint were keyboard paths (`R`,
`LeftShift`) plus touch buttons supplied separately by `MobileControlsController`.
A controller player had neither path.

The remediation adds two owner-local gamepad actions:

- `LK_Reload` binds `ButtonR1` in `WeaponController` with
  `createTouchButton = false` and calls the existing `requestReload()` path;
- `LK_Sprint` binds `ButtonL3` in `SurvivorController` with
  `createTouchButton = false` and calls the existing `setSprinting()` path on
  Begin/End/Cancel.

The keyboard paths remain intact. `MobileControlsController` remains the touch
surface and does not register gamepad key codes. Both gamepad actions unbind on
controller teardown.

**Source status:** remediated.  
**Runtime/device status:** unverified until the consolidated controller Studio
pass.

### M3 — Revive gamepad coverage — source-remediated by BA-062

Before the third BA-062 increment, `OperativeLifeController` bound keyboard `V`
and generated a touch button but had no controller key.

The remediation adds `Enum.KeyCode.DPadDown` to the same `LK_Revive` CAS action.
Keyboard, controller and touch therefore share the same target selection and
Begin/End hold intent. `E` and `ButtonX` stay free for contextual world prompts.

**Source status:** remediated.  
**Runtime/device status:** unverified until the consolidated controller/touch
Studio pass.

### M4 — Hub UI close is keyboard-only

`HubPreparationController` closes only on `Escape` from a raw
`UserInputService` listener. `Escape` is reserved by the Roblox client for its
own menu on every platform, and there is no gamepad or touch close affordance in
this controller.

### M5 — Panel shortcuts are keyboard-only, and their labels assume keyboard

`C` and `I` have no gamepad or touch shortcut equivalent. The panels themselves
are reachable through on-screen buttons and gamepad UI navigation, but their
labels still present keyboard-specific shortcuts.

## Conflicts

### C1 — `E` / Revive prompt collision — source-remediated by BA-062

Before the second BA-062 increment, `OperativeLifeController` bound `E` while
world interactions also used `E` through `ProximityPrompt`.

The remediation moves Revive to keyboard `V`. World interaction remains on `E`;
no prompt key is changed. Revive targeting, Begin/End intent shape, hold duration
and server authority are unchanged.

**Source status:** remediated.  
**Runtime/device status:** unverified until the consolidated keyboard/touch
Studio pass.

### C2 — `ButtonX` / class-action prompt collision — source-remediated by BA-062

Before the second BA-062 increment, `ClassActionController` bound
`Enum.KeyCode.ButtonX` while the engine's default `ProximityPrompt` gamepad key
was also `ButtonX`.

The remediation keeps class action keyboard `Q` and generated touch behavior but
moves the gamepad binding to `Enum.KeyCode.ButtonB`. World interaction remains
on `ButtonX`. The matching HUD hint is updated to `Q / GAMEPAD B`.

**Source status:** remediated.  
**Runtime/device status:** unverified until the consolidated controller Studio
pass.

### C3 — Two independent `Escape` listeners

`RPGMenuController` and `HubPreparationController` each open their own
`UserInputService.InputBegan` connection for `Escape` and neither knows about
the other. One press runs both handlers. Today each is guarded by its own
visibility check, but nothing coordinates them and `Escape` is reserved by the
Roblox client regardless.

### C4 — Number keys 1–3 are claimed by two HUDs

`HordeHUDController` and `RunBuildHUDController` each own independent `1/2/3`
and `Keypad1-3` listeners. Each is guarded by its own local active flag, but
neither consults the other. Current pacing prevents overlap rather than a shared
input owner.

## Accessibility considerations

None of the following broad options are implemented by the current BA-062
remediations. They remain considerations for later BA-062/Patch 0.2 work.

| Consideration | Current state |
|---|---|
| Rebinding | No action can be rebound. Fifteen of seventeen remain hardcoded; two are config constants that are not player-facing. |
| Hold vs. toggle | Sprint, fire and revive are hold-only. No toggle alternative. |
| Hold duration | Revive's hold length is not adjustable. |
| One-handed / reduced-mobility play | Simultaneous hold-sprint plus hold-fire plus aim has no alternative. |
| Keyboard-only play | Firing still requires a mouse button; there is no keyboard fire. |
| Pointer-free play | Cursor is locked to centre except while the input-modal attribute is set. |
| Input labelling | Prompt and button labels are not globally device-adaptive. |
| Choice surfaces | Upgrade and relic choices support cursor, keyboard and gamepad selection focus. |
| Device detection | `MobileControlsController` still adapts via `TouchEnabled and not KeyboardEnabled`; owner-local gamepad bindings no longer depend on that controller. |

## Structural finding

There is still no shared action map. Ten controllers own their own bindings, so:

- the full action surface cannot be listed, diffed or validated from one place;
- a new controller can silently claim a key another controller already uses;
- rebinding and device-adaptive labelling have nowhere to live;
- remaining UI-close and number-key conflicts are still coordinated only by
  local controller state.

`PersonalFlashlightConfig` and `SquadPingConfig` still show the config-driven
shape the other fifteen actions lack.

## Recommended remediation order

BA-062 remains an umbrella of isolated, merge-after-each increments. Do not
bundle later items together merely because they share this ticket.

1. **M1 — device-neutral firing:** source-remediated. Confirm on controller and
   touch during the consolidated Studio pass.
2. **C1/C2 — prompt-key collisions:** source-remediated. Revive is `V`, class
   action is `Q` / `ButtonB`, contextual prompts retain `E` / `ButtonX` / touch.
3. **M2/M3 — core gamepad coverage:** source-remediated. Reload is `ButtonR1`,
   sprint is `ButtonL3`, revive is `DPadDown`.
4. **Introduce a shared action map** covering all seventeen actions, following
   the two existing configs, so future rebinding and device-adaptive labels have
   one source of truth.
5. **M4/M5 — device-neutral close affordance and device-adaptive labels.**
6. Resolve C3/C4 through the shared action/input-modal surface rather than adding
   more independent listeners.

Accessibility options such as rebinding, hold/toggle and hold duration should
follow the action map rather than precede it.

## Completion boundary

BA-061 remains complete at E1. BA-062's completed source increments change only
client input origins/bindings and one matching class-action hint. Server
ownership of shots, cadence, ammunition, targeting, damage, movement truth,
revive truth, class-action truth and world-interaction consequences is unchanged.

The Studio/device pass remains outstanding. Source/static acceptance now proves
only that:

- firing is exposed to mouse, `ButtonR2` and touch;
- reload is exposed to keyboard `R`, gamepad `ButtonR1` and the existing touch
  action through one reload owner;
- sprint is exposed to keyboard `LeftShift`, gamepad `ButtonL3` and the existing
  touch action through one sprint state path;
- revive is exposed to keyboard `V`, gamepad `DPadDown` and touch through one
  hold action;
- Revive does not claim `E`, class action does not claim `ButtonX`, and world
  prompts retain their contextual keys.

BA-062 should continue one isolated remediation at a time, with the shared
action-map foundation next unless the MVP STOP / PLAY / FIX gate is intentionally
entered first.
