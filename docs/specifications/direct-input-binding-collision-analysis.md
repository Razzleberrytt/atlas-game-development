# Direct input-binding collision analysis

**Roadmap ticket:** BA-062 collision hardening  
**Evidence level:** E1 source/static only

## Decision

The canonical action map should be mechanically checked for duplicate **direct keyboard and gamepad key-code claims**.

`InputBindingCollisionAnalyzer` is a pure utility that consumes `InputActionMapConfig.ActionOrder` plus its action definitions and returns a deterministic list of duplicated keyboard/gamepad binding tokens.

Pointer and touch bindings are intentionally excluded. Tokens such as `MouseButton1` and `GuiButton` often describe generic GUI activation across many surfaces rather than a unique global shortcut, so treating them as direct-key collisions would create false positives.

## Current canonical result

The source fixture locks the current action map to this result:

- **Gamepad:** zero duplicate direct key-code claims.
- **Keyboard:** exactly six duplicate tokens: `One`, `Two`, `Three`, `KeypadOne`, `KeypadTwo`, and `KeypadThree`.
- Every one of those six collisions is shared only by `UpgradeChoice` and `RelicChoice`.

Those six overlaps are the existing BA-062 C4 issue. The analyzer does not resolve that runtime conflict; it ensures C4 cannot quietly grow into additional collisions while the live listener migration remains separate.

## Validation behavior

The analyzer also fails its input contract when action order contains duplicates, an ordered action is missing, a binding list is malformed, or a binding token is empty/non-string.

Collision ordering and action-owner ordering are deterministic so CI output can be compared reliably.

## Runtime boundary

This module does not bind input, create GUI, dispatch a choice, select a priority, fire remotes, or alter gameplay/presentation authority. It reports source configuration only.

## Next C4 integration boundary

The live C4 remediation still needs one shared numbered-choice listener (or equivalent single-owner dispatch path) that consumes `ChoiceInputConflictResolver` and submits nothing when both choice surfaces are active. That integration remains separate because it touches two large live HUD owners.

Real device behavior remains part of the consolidated Studio/device acceptance pass.
