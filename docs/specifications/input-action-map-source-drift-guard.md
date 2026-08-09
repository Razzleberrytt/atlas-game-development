# BA-062 Input Action Map Source-Drift Guard

**Evidence level:** E1 source/static only  
**Runtime activation:** none  
**Scope:** canonical input-map truth versus already-active client binding source

## Purpose

`InputActionMapConfig` is the canonical semantic inventory for player-facing bindings, but it is descriptive rather than the runtime listener owner. This guard prevents that map from silently drifting away from the live controllers that already own the remediated input paths.

The fixture verifies the current source truth for:

- Fire: mouse primary, gamepad R2, generated touch action.
- Reload: keyboard R, gamepad R1.
- Sprint: keyboard Left Shift, gamepad L3.
- Class action: keyboard Q, gamepad B.
- Revive: keyboard V, gamepad D-pad Down.
- World interaction: keyboard E, gamepad X, prompt tap.
- Flashlight: config-backed keyboard/gamepad bindings.
- Squad ping: config-backed keyboard/gamepad bindings plus middle mouse.

## Prompt-collision boundary

The historical BA-061 audit recorded revive on `E` and class action on `ButtonX`, colliding with engine world prompts. Current source has already moved those actions away from prompt ownership:

- revive is `V` / `DPadDown`;
- class action is `Q` / `ButtonB`;
- world prompts retain `E` / `ButtonX`.

The fixture explicitly rejects a return of `Enum.KeyCode.E` inside the revive controller and `Enum.KeyCode.ButtonX` inside the class-action controller.

## What this does not do

This change does not:

- bind or unbind any runtime action;
- change ContextActionService priorities or sink/pass behavior;
- query device capabilities;
- change GUI navigation;
- resolve the remaining numbered-choice C4 overlap;
- claim real-device acceptance;
- replace Studio input verification.

## Relationship to other BA-062 preparation

- `InputActionMapConfig` remains the canonical semantic map.
- `InputBindingHintResolver` reads the map for truthful presentation hints.
- `InputDeviceFamilyResolver` classifies observed input-type names without service access.
- `InputBindingCollisionAnalyzer` reports duplicate direct keyboard/gamepad claims.
- `ChoiceInputConflictResolver` defines fail-closed C4 arbitration, while live numbered-choice listener migration remains separate.

## Acceptance

The source/static slice is accepted when the focused fixture and the repository's normal Stylua, Selene, Lune, Rojo build, and reproducible artifact checks all pass.
