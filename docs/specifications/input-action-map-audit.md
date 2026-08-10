# PC / mobile / controller action-map audit

**Roadmap ticket:** BA-061  
**Lane:** controlled build-ahead, P6 onboarding/input/UI preparation  
**Status:** audit complete; BA-062 M1-M6 and C1-C4 source-remediated  
**Evidence level:** E1 source/static only — consolidated Studio/device acceptance remains open

## Current decision

BA-061 originally found seventeen semantic player actions distributed across client controllers, engine controls, and world prompts. BA-062 has now closed the identified source-level device gaps and direct input conflicts without moving server gameplay authority.

The canonical descriptive registry is `InputActionMapConfig`. It contains the original seventeen semantic actions plus one remediation infrastructure entry, `NumberedChoiceInput`, for eighteen total entries. `NumberedChoiceInput` is not a new gameplay verb: it represents the single direct keyboard owner for the existing Upgrade and Relic choice shortcuts.

Current source-level outcomes:

- Fire preserves mouse input and adds `ButtonR2` plus a generated touch action.
- Reload preserves `R` and touch while adding `ButtonR1`.
- Sprint preserves `LeftShift` and touch while adding `ButtonL3`.
- Revive uses `V`, `DPadDown`, and generated touch, leaving world interaction on `E` / `ButtonX`.
- Class action uses `Q` / `ButtonB`, leaving world interaction on `ButtonX`.
- Hub preparation has an explicit selectable/tappable **CLOSE** affordance and no raw Escape listener.
- Character/Inventory launcher labels no longer advertise keyboard shortcuts on touch/gamepad input families.
- Escape belongs to the RPG modal close path rather than two independent UI owners.
- Upgrade and Relic number shortcuts are detected by one `ChoiceInputCoordinator`; if both surfaces report active, dispatch fails closed and neither receives the number press.
- Direct keyboard/gamepad claims in the canonical map are now collision-free.

None of those source results constitutes real-device acceptance.

## Method and limits

The audit is locked by `games/living-kingdoms/tests/InputActionMapSourceAudit.test.luau` plus focused BA-062 fixtures. Source inspection can prove ownership, binding values, listener count, teardown, and unchanged remote paths. It cannot prove ergonomics, Roblox place-level behavior outside this source tree, touch reachability, gamepad navigation quality, or simultaneous-input feel.

Still unverified in Studio/device testing:

- generated touch button size, placement, and overlap;
- controller feel for R2 fire, R1 reload, L3 sprint, D-pad Down revive, B class action, and D-pad Up ping;
- discoverability of V revive and the remapped controller actions;
- gamepad selection reachability for every GUI button;
- input-family transitions for device-adaptive labels;
- latency, comfort, simultaneous aim/fire/sprint behavior, and multiplayer choice-modal timing.

## Current action inventory

`—` means there is no direct shortcut on that device. GUI navigation can still make a surface reachable without implying a direct gamepad key.

| Semantic action / input | Owner | Keyboard | Mouse | Gamepad | Touch | Mechanism |
|---|---|---|---|---|---|---|
| Move | Roblox `PlayerModule` | WASD | — | left stick | thumbstick | engine |
| Jump | Roblox `PlayerModule` | Space | — | ButtonA | button | engine |
| Camera look | `PlayerModule` + `CameraController` | — | mouse | right stick | drag | engine |
| Fire weapon | `WeaponController` | — | MouseButton1 | ButtonR2 | generated Fire | raw UIS + CAS |
| Reload | `WeaponController` + mobile surface | R | — | ButtonR1 | button | raw UIS + owner CAS + touch CAS |
| Sprint | `SurvivorController` + mobile surface | LeftShift | — | ButtonL3 | button | raw UIS + owner CAS + touch CAS |
| Class action | `ClassActionController` | Q | — | ButtonB | generated action | CAS |
| Flashlight | `PersonalFlashlightController` | F | — | ButtonY | generated action | CAS/config |
| Squad ping | `SquadPingController` | G | MouseButton3 | DPadUp | generated action | CAS/config |
| Revive ally | `OperativeLifeController` | V | — | DPadDown | generated action | CAS |
| Interact / collect | world `ProximityPrompt`s | E | — | ButtonX | prompt tap | engine prompt |
| Numbered choice input | `ChoiceInputCoordinator` | 1–3, Keypad 1–3 | — | — | — | shared fail-closed input |
| Upgrade choice | `HordeHUDController` | via coordinator | click | selection focus | tap | shared dispatch + GUI |
| Relic choice | `RunBuildHUDController` | via coordinator | click | selection focus | tap | shared dispatch + GUI |
| Open Character | `RPGMenuController` | C | click | UI navigation | tap | raw UIS + GUI |
| Open Inventory | `RPGMenuController` | I | click | UI navigation | tap | raw UIS + GUI |
| Close RPG modal | `RPGMenuController` | Escape | click | UI navigation | tap | raw UIS + GUI |
| Close hub UI | `HubPreparationController` | — | click | UI navigation | tap | GUI only |

## Binding mechanisms

- `ContextActionService` owns the remediated direct gamepad/generated-touch gameplay actions.
- Raw `UserInputService` remains for already-authoritative keyboard/mouse paths and the one shared numbered-choice listener.
- `ProximityPrompt` owns contextual world interaction on `E` / `ButtonX` / prompt tap.
- Roblox `PlayerModule` owns native movement, jump, and camera control.
- GUI `Activated` plus selection focus remains the pointer/touch/gamepad-navigation route for choice and menu surfaces.
- `ChoiceInputCoordinator` owns only direct 1/2/3 detection; it does not own upgrade/relic semantics or network mutation.

## Missing bindings / remediation ledger

### M1 — Firing device coverage — source-remediated by BA-062

`WeaponController` preserves `MouseButton1` and adds `ButtonR2` plus generated touch through the same fire hold state and existing intent path.

**Source status:** remediated.  
**Runtime/device status:** unverified.

### M2 — Reload and sprint gamepad coverage — source-remediated by BA-062

Reload adds `ButtonR1` at the existing weapon owner; Sprint adds `ButtonL3` at the existing movement/sprint owner. Both reuse existing owner functions and avoid creating duplicate touch controls.

**Source status:** remediated.  
**Runtime/device status:** unverified.

### M3 — Revive gamepad coverage — source-remediated by BA-062

Revive uses `V` + `DPadDown` + generated touch on the same Begin/End hold path.

**Source status:** remediated.  
**Runtime/device status:** unverified.

### M4 — Hub UI close affordance — source-remediated by BA-062

`HubPreparationController` exposes an explicit **CLOSE** GUI button whenever a routed preparation screen is open. The button is selectable for gamepad navigation and activates the existing `closeHubUi()` path. The hub router no longer owns Escape.

**Source status:** remediated.  
**Runtime/device status:** unverified.

### M5 — Device-adaptive launcher labels — source-remediated by BA-062

Character/Inventory launch buttons retain `C` / `I` hints for keyboard/pointer presentation and use neutral `CHARACTER` / `INVENTORY` labels for touch/gamepad presentation. No fake direct controller shortcut was invented.

**Source status:** remediated.  
**Runtime/device status:** unverified.

## Conflicts

### C1 — `E` / Revive prompt collision — source-remediated by BA-062

Revive moved to `V`; contextual world prompts retain `E`.

### C2 — `ButtonX` / class-action prompt collision — source-remediated by BA-062

Class action moved to `ButtonB`; contextual world prompts retain `ButtonX`.

### C3 — duplicate Escape listeners — source-remediated by BA-062

The RPG modal remains the raw Escape UI owner. Hub preparation closes through its explicit GUI affordance, so a single Escape press no longer independently invokes both UI owners.

### C4 — Number keys 1–3 — source-remediated by BA-062

Before remediation, `HordeHUDController` and `RunBuildHUDController` each owned separate raw listeners for `One`/`Two`/`Three` and keypad equivalents.

Now `ChoiceInputCoordinator` owns the single raw numbered listener. The two HUDs register:

- their existing local active-state predicate; and
- a callback into their existing submit function(s).

The coordinator gathers active owners and calls `ChoiceInputConflictResolver`. Exactly one active owner may receive the choice index. Zero active owners do nothing. Multiple active owners fail closed and dispatch nothing; no hidden priority is invented.

Mouse/touch GUI `Activated` behavior, gamepad selection focus, upgrade submission, relic choice submission, and relic replacement submission remain in their existing HUD owners. The coordinator contains no remote calls.

**Source status:** remediated.  
**Runtime/device status:** unverified, including real overlap timing.

## Shared action-map state

`InputActionMapConfig` is now the canonical descriptive inventory. The original seventeen semantic actions remain represented, and the C4 remediation adds `NumberedChoiceInput` as an infrastructure entry so direct number keys have one truthful owner.

The direct-binding collision analyzer now requires **zero** duplicate keyboard/gamepad key-code claims in the canonical map. Pointer/touch GUI activation tokens remain intentionally excluded because generic click/tap activation is not a unique global shortcut.

The source-drift guard separately checks the remediated live gameplay bindings against the map so stale documentation cannot silently reintroduce the old `E` / `ButtonX` findings.

## Accessibility considerations still open

BA-062 source remediation does not implement broad accessibility customization. Remaining product decisions include:

| Consideration | Current state |
|---|---|
| Rebinding | No player-facing rebinding UI. |
| Hold vs. toggle | Sprint, fire, and revive remain hold-oriented. |
| Hold duration | Revive hold duration is not player-adjustable. |
| One-handed / reduced-mobility play | No alternate simultaneous aim/fire/sprint scheme. |
| Keyboard-only play | Fire still requires a pointer button. |
| Global device-adaptive hints | The combat control strip, the run-upgrade offer and the relic offer now resolve their hints from the canonical map through `InputHintPresentationResolver`. Remaining HUD/prompt surfaces still carry no hints rather than wrong ones. |
| Device switching | Source resolver exists; real switching behavior remains unverified. |

### M6 — Device-adaptive HUD hint text — source-remediated

Fixing the bindings left a second half of the BA-061 finding open: the HUD still
*told* every player to use keyboard keys. The combat control strip read
`MOVE WASD • INTERACT / PICK UP E • RELOAD R • FLASHLIGHT F`, the run-upgrade
offer read `PRESS 1, 2, OR 3` with `PRESS n OR CLICK` on each button, and the
relic offer read `CHOOSE ONE [1 / 2]` with `Press 1 or 2, or click.` A controller
player was being instructed to press keys their device does not have, on the
three surfaces that carry the run's core verbs and both reward decisions.

`InputHintPresentationResolver` (`src/shared/Input/`) is now the single display
vocabulary: it converts canonical action-map binding names into short
player-facing tokens (`ButtonR1` → `RB`, `Thumbstick1` → `L STICK`,
`PromptTap` → `TAP PROMPT`) and reports *absence* when an action has no direct
binding on the active family. Callers must omit the hint in that case rather than
fall back to the keyboard key, so GUI navigation is still never advertised as a
direct gamepad shortcut. Because numbers are keyboard-only, gamepad and touch now
get a truthful verb (`SELECT ONE` / `TAP ONE`) and lose the `[n]` prefix.

The combat HUD also rewrites its hints on `LastInputTypeChanged`, so a controller
picked up mid-run stops showing keyboard text.

**Source status:** remediated, locked by
`tests/DeviceAdaptiveHudHintSourceAudit.test.luau` and
`tests/InputHintPresentationResolver.test.luau`.
**Runtime/device status:** unverified.

**Known limitation:** the relic panel resolves the device family when it renders
but does not re-render on a mid-panel device switch; its choice render is inline
in the revision-gated `applySnapshot` path, and re-entering it was judged riskier
than the narrow case it covers. The combat HUD does refresh.

## Completion boundary

BA-061 remains complete at E1. BA-062's identified M1-M5 and C1-C4 source findings
are now remediated, plus the M6 hint-text half of the original finding, while
consolidated Studio/device acceptance remains outstanding.

Source/static acceptance proves ownership and wiring only. It does **not** promote these changes to E2 device evidence, does not validate comfort or placement, and does not change server authority for combat, movement, revive, class actions, prompts, progression choices, relic choices, or persistence.

The next BA-062 work should therefore be either a deliberately scoped accessibility/device-label adoption increment or the consolidated Studio/device acceptance pass, depending on the active MVP gate.
