# PC / mobile / controller action-map audit

**Roadmap ticket:** BA-061

**Lane:** controlled build-ahead, P6 onboarding/input/UI preparation

**Status:** audit complete; no input behavior changed

**Evidence level:** E1 source/static only — no Studio device testing was performed

**Playable-patch mapping:** MVP 0.1 device-parity input; remediation belongs to BA-062 and Patch 0.2

**Runtime behavior:** none

## Decision

Atlas's semantic action surface is **not device-neutral**. Seventeen player
actions are bound across ten client controllers with no shared action map, and
the split between `ContextActionService` (device-neutral, can create a touch
button, accepts a gamepad key) and raw `UserInputService.InputBegan`
(keyboard/mouse only) decides device coverage by accident rather than by design.

Five actions use `ContextActionService` and are broadly reachable. The rest are
bound through raw `UserInputService`, and three of them — **fire, reload and
sprint** — are core combat verbs. Firing has no gamepad or touch binding at all.

Two hard binding conflicts exist, both between a controller-owned action and the
engine's `ProximityPrompt` defaults: `E` (revive vs. every prompt) and `ButtonX`
(class action vs. every prompt on gamepad).

This audit records the surface and its gaps. It changes no binding. BA-062 owns
remediation and remains a client-only semantic mapping task with no gameplay
authority change.

## Method and limits

Every finding below is read from source in `games/living-kingdoms/src/client`
and `games/living-kingdoms/src/server/Systems`, and is locked by
`tests/InputActionMapSourceAudit.test.luau`.

This is **E1**. No device was tested. Specifically unverified:

- whether the generated touch buttons are reachable, correctly sized or
  non-overlapping on a real phone;
- whether gamepad UI navigation actually reaches every button;
- whether the engine's default `ProximityPrompt` gamepad button behaves as
  documented alongside a competing `ContextActionService` binding;
- any latency, comfort or discoverability judgement.

Those belong to a Studio device pass, not to this audit.

## Binding mechanisms in use

| Mechanism | Device reach | Used by |
|---|---|---|
| `ContextActionService:BindAction(..., true, keys...)` | keyboard + gamepad + generated touch button | 5 actions |
| Raw `UserInputService.InputBegan/InputEnded` | keyboard and mouse only | 8 actions |
| Engine `ProximityPrompt` | keyboard `E`, gamepad `ButtonX`, touch tap — all engine defaults | all world interaction |
| Roblox `PlayerModule` | full native coverage | move, jump, camera |
| GUI `Activated` + `GuiService.SelectedObject` | pointer, touch, gamepad selection focus | 2 choice surfaces |

The third `BindAction` argument (`createTouchButton`) is `true` for every
`ContextActionService` action in the codebase, so those five actions do get a
mobile button. Raw `UserInputService` actions cannot.

## Action inventory

`—` means the action has no binding on that device.

| Semantic action | Owner | Keyboard | Mouse | Gamepad | Touch | Mechanism |
|---|---|---|---|---|---|---|
| Move | Roblox `PlayerModule` | WASD | — | left stick | thumbstick | engine |
| Jump | Roblox `PlayerModule` | Space | — | ButtonA | button | engine |
| Camera look | `PlayerModule` + `CameraController` | — | mouse | right stick | drag | engine |
| **Fire weapon** | `WeaponController` | — | MouseButton1 | **—** | **—** | raw UIS |
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
The other fifteen hardcode their bindings inside the controller.

## Missing bindings

### M1 — Firing is mouse-only (critical)

`WeaponController` sends fire intent only from
`input.UserInputType == Enum.UserInputType.MouseButton1`, with the matching
release on `InputEnded`. There is no `ContextActionService` binding, no gamepad
button and no touch button; `MobileControlsController` binds reload and sprint
but not fire. `sendFireIntent` has exactly one call site chain, so no other
surface can start firing.

A gamepad or touch player can move, jump, reload, sprint, ping, use the
flashlight and collect loot — but cannot attack. This directly contradicts MVP
0.1's device-parity acceptance question, and it is the single highest-value
input fix available.

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

`C` and `I` have no gamepad or touch equivalent. The panels themselves *are*
reachable — `RPGMenuController` creates on-screen buttons and a close button, so
pointer, touch and gamepad UI navigation all work. But those buttons are
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
both paths. This is the most likely conflict to be hit in real play, because
downed allies and loot occupy the same fights.

### C2 — `ButtonX` is bound to both the class action and every ProximityPrompt

`ClassActionController` binds `Enum.KeyCode.ButtonX` for Brace. `ButtonX` is
also the engine's default `ProximityPrompt` gamepad button. The same collision
as C1, on gamepad, against a different action.

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

None of the following exist today. They are recorded as considerations for
BA-062 and Patch 0.2, not as defects with an owner.

| Consideration | Current state |
|---|---|
| Rebinding | No action can be rebound. Fifteen of seventeen are hardcoded; two are config constants that are not player-facing. |
| Hold vs. toggle | Sprint, fire and revive are hold-only. No toggle alternative. |
| Hold duration | Revive's hold length is not adjustable. |
| One-handed / reduced-mobility play | Simultaneous hold-sprint plus hold-fire plus aim is required with no alternative. |
| Keyboard-only play | Firing requires a mouse button; there is no keyboard fire. |
| Pointer-free play | Cursor is locked to centre (`MouseBehavior.LockCenter`) except while `LK_InputModalOpen` is set. |
| Input labelling | Prompt and button labels are keyboard-worded (`"C   CHARACTER"`) and do not adapt to the active device. |
| Choice surfaces | Upgrade and relic choices do support cursor, keyboard and gamepad selection focus via `GuiService.SelectedObject` — the one place device-neutral input is handled deliberately. |
| Device detection | Only `MobileControlsController` adapts, via `TouchEnabled and not KeyboardEnabled`. A device with both touch and keyboard gets no touch buttons for reload or sprint. |

## Structural finding

There is no action map. Ten controllers each own their own bindings, so:

- the full action surface cannot be listed, diffed or validated from one place;
- a new controller can silently claim a key another controller already uses —
  C1 through C4 all arose this way;
- device coverage is a side effect of which binding API an author reached for;
- rebinding and device-adaptive labelling have nowhere to live.

`PersonalFlashlightConfig` and `SquadPingConfig` show the shape the other
fifteen actions lack: a named action with its key codes in shared config.

## Recommended remediation order

For BA-062, which is now unblocked. Each item is client-only semantic mapping
and changes no gameplay authority.

1. **M1 — give firing a device-neutral binding.** Move fire to
   `ContextActionService` with a gamepad trigger and a touch button, keeping
   `MouseButton1`. The server remains the sole owner of shots, cadence,
   ammunition, targeting and damage; only intent origin changes.
2. **C1 and C2 — resolve the `E` and `ButtonX` collisions.** Either move Revive
   and Brace off the prompt keys, or make prompts and contextual actions share
   one arbitration owner. Do not solve it by sinking the input, which would
   break world interaction.
3. **M3 and M2 — add gamepad bindings for revive, reload and sprint.**
4. **Introduce a shared action map** covering all seventeen actions, following
   the two existing configs, so BA-063's UI work and any future rebinding have
   a single surface. This is the structural fix that prevents C1–C4 recurring.
5. **M4 and M5 — device-neutral close affordance and device-adaptive labels.**

Accessibility options (rebinding, hold/toggle, hold duration) should follow the
action map rather than precede it.

## Completion boundary

BA-061 is complete at E1 when this audit and its source fixture are green. It
changes no binding, adds no abstraction layer, and makes no claim that any
device was tested. BA-062 is unblocked; the Studio device pass that would verify
touch-button reachability, gamepad navigation and prompt arbitration remains
outstanding and belongs to the human/Studio lane.
