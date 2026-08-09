# Shared input action-map foundation

**Roadmap ticket:** BA-062  
**Evidence level:** E1 source/static only  
**Runtime scope:** canonical input inventory plus isolated C4 numbered-input ownership

## Decision

`InputActionMapConfig` is the canonical descriptive registry for the seventeen semantic player actions identified by BA-061. BA-062 C4 adds one infrastructure entry, `NumberedChoiceInput`, so the registry now contains **eighteen entries** without adding a new gameplay verb.

The map records action IDs, current owner IDs, binding mechanisms, and per-device binding tokens. It does not itself listen for input, mutate gameplay state, send network requests, or replace gameplay owners.

`ChoiceInputCoordinator` is the one intentional runtime consumer introduced for C4. It owns only direct keyboard detection for `1/2/3` and keypad equivalents. Upgrade and Relic HUDs continue to own their choice semantics, GUI activation, and existing network calls.

## Covered entries

The original semantic actions remain:

1. Move
2. Jump
3. CameraLook
4. Fire
5. Reload
6. Sprint
7. ClassAction
8. Flashlight
9. SquadPing
10. Revive
11. Interact
12. UpgradeChoice
13. RelicChoice
14. OpenCharacter
15. OpenInventory
16. CloseRPGModal
17. CloseHubUI

The remediation infrastructure entry is:

18. `NumberedChoiceInput` — the single direct keyboard owner for choice indices 1–3.

## Core binding snapshot

| Action | Keyboard / mouse | Gamepad | Touch |
|---|---|---|---|
| Fire | MouseButton1 | ButtonR2 | generated action button |
| Reload | R | ButtonR1 | existing mobile action button |
| Sprint | LeftShift | ButtonL3 | existing mobile action button |
| ClassAction | Q | ButtonB | generated action button |
| Flashlight | F | ButtonY | generated action button |
| SquadPing | G / MouseButton3 | DPadUp | generated action button |
| Revive | V | DPadDown | generated action button |
| Interact | E | ButtonX | prompt tap |
| NumberedChoiceInput | 1–3 / Keypad 1–3 | — | — |
| UpgradeChoice | GUI click | selection focus | GUI tap |
| RelicChoice | GUI click | selection focus | GUI tap |
| CloseRPGModal | Escape / GUI click | selection focus | GUI tap |
| CloseHubUI | GUI click | selection focus | GUI tap |

The map therefore no longer represents UpgradeChoice and RelicChoice as duplicate direct keyboard owners. Their number shortcuts arrive through the coordinator.

## C4 arbitration boundary

`ChoiceInputCoordinator` registers the two choice owners by stable IDs:

- `UpgradeChoice`
- `RelicChoice`

Each registration supplies only an `isActive` predicate and an existing choice callback. On a numbered key press, the coordinator asks `ChoiceInputConflictResolver` which owner, if any, may receive the index.

- zero active owners → no dispatch;
- exactly one active owner → dispatch to that owner;
- multiple active owners → fail closed, no dispatch.

No priority between Upgrade and Relic is invented. GUI `Activated` paths remain unchanged.

## Authority boundary

`InputActionMapConfig` remains configuration-only. It must not:

- call `ContextActionService` or `UserInputService`;
- create Instances or GUI;
- send remotes;
- alter combat, movement, revive, class-action, prompt, progression, relic, inventory, or persistence authority;
- claim real-device acceptance.

`ChoiceInputCoordinator` is client-input-only. It must not send remotes, own reward legality, alter offers, choose relic/upgrade IDs, or mutate gameplay state.

## Validation

Source/static acceptance requires:

- exactly eighteen unique registry entries: seventeen audited semantics plus `NumberedChoiceInput` infrastructure;
- the accepted gameplay bindings remain unchanged;
- Revive/ClassAction stay distinct from world prompt keys;
- one numbered keyboard owner represents all six 1–3/keypad tokens;
- UpgradeChoice and RelicChoice contain no direct number-key claims;
- the direct-binding collision analyzer reports zero keyboard/gamepad collisions;
- the two HUDs retain their existing GUI/network authority and unregister from the coordinator on teardown;
- full Stylua, Selene, Lune, and Rojo validation passes.

Real controller/touch/keyboard behavior remains for the consolidated Studio/device pass.
