# Shared input action-map foundation

**Roadmap ticket:** BA-062

**Evidence level:** E1 source/static only

**Runtime scope:** behavior-preserving input configuration centralization

## Decision

`InputActionMapConfig` is the canonical descriptive registry for the seventeen
semantic player actions identified by BA-061. It records stable action IDs,
current owner IDs, current binding mechanism, and per-device binding tokens.

The map does not listen for input, dispatch actions, own UI, mutate gameplay
state, send network requests, or replace existing action owners. Controllers
continue to own their current behavior; this increment only moves already-agreed
binding values toward one shared configuration surface.

## Covered actions

The map covers:

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

Engine-owned movement/camera/prompt entries are descriptive. GUI choice/menu
entries are also descriptive until their isolated BA-062 remediation steps.

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

These values intentionally preserve the BA-062 collision and device-coverage
remediations already merged. The map does not introduce new bindings.

## Adoption boundary

This increment may migrate already-remediated gameplay input owners to read their
binding values from `InputActionMapConfig` while preserving their existing
handlers and action names. Existing flashlight/ping tuning configs may proxy their
binding fields to the shared map for compatibility.

The unresolved UI paths remain behaviorally unchanged in this increment:

- `CloseRPGModal` and `CloseHubUI` still share Escape until C3 is remediated;
- `UpgradeChoice` and `RelicChoice` still share 1/2/3 until C4 is remediated;
- hub close remains without a direct gamepad/touch binding until M4;
- character/inventory shortcut labels remain keyboard-oriented until M5.

Their current bindings are represented in the map now so those later changes can
be made against one inventory instead of rediscovering the surface.

## Authority boundary

`InputActionMapConfig` must remain configuration-only. It must not:

- call `ContextActionService` or `UserInputService`;
- create Instances or GUI;
- send remotes;
- alter movement, combat, revive, class-action, prompt, inventory, reward, or
  persistence authority;
- arbitrate C3/C4 before their dedicated remediation increments;
- claim real-device acceptance.

## Validation

Source/static acceptance requires:

- exactly seventeen unique semantic action definitions;
- the previously accepted core bindings remain unchanged;
- Revive/ClassAction remain distinct from world prompt keys;
- migrated controllers continue routing input to their existing owner methods;
- unresolved UI bindings remain represented without behavioral changes;
- full Stylua, Selene, Lune and Rojo validation passes.

Real controller/touch/keyboard behavior remains for the consolidated Studio/device
pass.
