# Device-binding hint resolver

**Roadmap ticket:** BA-062 input abstraction foundation  
**Evidence level:** E1 source/static only

## Decision

Presentation code needs one truthful way to ask which direct input hint, if any, may be shown for a semantic action on the player's current device family.

`InputBindingHintResolver` consumes one definition from the canonical `InputActionMapConfig` and resolves a single raw binding token for:

- `KeyboardPointer` — keyboard is preferred; mouse is used only when the action has no keyboard binding;
- `Gamepad` — only an explicitly recorded gamepad key is returned;
- `Touch` — only an explicitly recorded touch surface is returned.

The resolver returns `Unavailable` when the action is reachable only indirectly for that family. For example, Character and hub-close UI can be navigated by gamepad, but the action map records no direct gamepad shortcut, so the resolver does **not** invent a controller-button label.

## Why raw tokens

This foundation returns canonical tokens such as `C`, `MouseButton1`, `ButtonR2`, `DPadDown`, `PromptTap`, or `GuiButton`. It does not localize, choose glyph assets, rename engine buttons, or invent platform-specific art. A later presentation layer may translate a verified token into copy or a glyph while preserving this resolver as the availability/source-of-truth boundary.

## Runtime boundary

This module does not:

- listen for input;
- move or replace any current controller binding;
- create GUI;
- detect the current device;
- fire remotes;
- change gameplay or presentation authority;
- claim controller/touch reachability from source alone.

The existing device-adaptive RPG launcher labels remain unchanged in this increment. Later isolated migrations may consume this resolver rather than duplicating family-selection logic.

## Validation

`InputBindingHintResolver.test.luau` loads the canonical action map and verifies representative keyboard/pointer, gamepad, and touch results, including mouse fallback for Fire and deliberate `Unavailable` results for GUI-navigation-only gamepad paths.

Real device behavior remains part of the consolidated Studio/device acceptance pass.
