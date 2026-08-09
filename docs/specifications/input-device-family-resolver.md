# Input device-family resolver

**Roadmap ticket:** BA-062 input abstraction foundation  
**Evidence level:** E1 source/static only

## Decision

Device-adaptive presentation should classify the **observed input event**, not guess from the set of hardware capabilities Roblox reports for the client.

`InputDeviceFamilyResolver` is a pure mapping from a `UserInputType.Name` string into one of three presentation families:

- `KeyboardPointer` — `Keyboard`, mouse buttons, mouse movement, and mouse wheel;
- `Gamepad` — `Gamepad1` through `Gamepad8`;
- `Touch` — `Touch`.

Other valid names resolve to `Unknown`. Empty or non-string values resolve to `InvalidInput`.

## Conservative unknown policy

Sensor, focus, text, `None`, or future input types must not silently switch presentation copy. The resolver therefore does not infer a family from accelerometer/gyro/focus events and does not use capability flags as a fallback.

A runtime consumer may choose to retain its previously known family when this resolver returns `Unknown`. That policy is intentionally outside this pure contract.

## Relationship to binding hints

This resolver determines **which device family an observed input belongs to**. `InputBindingHintResolver` separately determines **which direct binding token, if any, the canonical action map can truthfully advertise for that family**.

Keeping those responsibilities separate avoids two common errors:

1. treating controller GUI navigation as if it were a direct button shortcut;
2. changing displayed hints because an unrelated sensor input occurred.

## Runtime boundary

This module does not call `UserInputService`, subscribe to input events, query capabilities, create GUI, select a binding, fire remotes, or change input/gameplay ownership. Existing runtime controllers do not consume it in this increment.

## Validation

`InputDeviceFamilyResolver.test.luau` covers all six keyboard/pointer names, `Gamepad1` through `Gamepad8`, touch, representative unknown/sensor inputs, invalid values, and source guardrails against runtime APIs.

Real device behavior remains part of the consolidated Studio/device acceptance pass after an isolated runtime consumer adopts this resolver.
