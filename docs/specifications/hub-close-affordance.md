# Hub preparation close affordance

**Roadmap ticket:** BA-062 M4 / C3

**Evidence level:** E1 source/static only

## Decision

Hub preparation screens share one device-neutral `CLOSE` GUI affordance owned by `HubPreparationController`.

The button is shown only after the router successfully opens one of its existing preparation `ScreenGui` surfaces and is hidden whenever `closeHubUi()` runs. `Activated` routes directly to that same close helper, so pointer click, touch tap, and gamepad GUI activation do not create another preparation-state owner.

C3 assigns keyboard `Escape` exclusively to the RPG player modal. Hub-routed preparation panels therefore no longer own a second raw `UserInputService` Escape listener. This removes the collision rather than adding a new arbitration layer.

## Compatibility

- RPG Character/Inventory modal keeps keyboard `Escape` close behavior;
- hub preparation close is GUI-only through its explicit `CLOSE` button;
- no direct gamepad key is added;
- `ButtonB`, `ButtonX`, triggers, stick clicks, and D-pad directions remain untouched;
- the shared input action map records `CloseHubUI` as `GuiOnly`, with pointer/touch GUI activation and no keyboard/gamepad shortcut;
- no class, loadout, expedition, networking, persistence, or gameplay mutation authority changes.

## Evidence boundary

M4/C3 are source-remediated only. Real pointer, touch, keyboard and gamepad navigation behavior remains for the consolidated Studio/device acceptance pass.
