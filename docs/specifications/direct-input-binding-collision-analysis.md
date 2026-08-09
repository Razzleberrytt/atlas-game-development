# Direct input-binding collision analysis

**Roadmap ticket:** BA-062 collision hardening  
**Evidence level:** E1 source/static only

## Decision

The canonical action map is mechanically checked for duplicate **direct keyboard and gamepad key-code claims** by `InputBindingCollisionAnalyzer`.

Pointer and touch bindings are intentionally excluded. Tokens such as `MouseButton1` and `GuiButton` can describe generic GUI activation across independent surfaces rather than one global shortcut, so treating them as direct-key collisions would create false positives.

## Current canonical result

After the BA-062 C4 live-listener migration, the source fixture requires:

- **Keyboard:** zero duplicate direct key-code claims.
- **Gamepad:** zero duplicate direct key-code claims.

The former six C4 overlaps (`One`, `Two`, `Three`, `KeypadOne`, `KeypadTwo`, `KeypadThree`) now belong only to `NumberedChoiceInput`, owned by `ChoiceInputCoordinator` in the canonical map. `UpgradeChoice` and `RelicChoice` no longer claim those keys directly; they keep their GUI activation and receive numbered choices through the shared coordinator.

## Runtime relationship

The analyzer itself remains pure and does not resolve input. The runtime C4 path is:

1. `ChoiceInputCoordinator` detects one of the six numbered keyboard keys.
2. It collects the currently active registered choice owners.
3. `ChoiceInputConflictResolver` returns dispatch only when exactly one owner is active.
4. The coordinator calls that HUD's existing choice callback.
5. If both HUDs report active, the key press fails closed and no choice is submitted.

No Upgrade-vs-Relic priority is invented.

## Validation behavior

The analyzer also fails its input contract when action order contains duplicates, an ordered action is missing, a binding list is malformed, or a binding token is empty/non-string.

Synthetic fixture cases still verify that keyboard and gamepad collisions are detected correctly even though the production map is now collision-free.

## Authority boundary

`InputBindingCollisionAnalyzer` does not bind input, create GUI, dispatch a choice, fire remotes, or alter gameplay/presentation authority.

`ChoiceInputCoordinator` owns only direct numbered input detection/arbitration. Upgrade legality, relic legality, replacement legality, offered IDs, reward sequence, and all network mutation remain in their existing HUD/server paths.

Real device behavior remains part of the consolidated Studio/device acceptance pass.
