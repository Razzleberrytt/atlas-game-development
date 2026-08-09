# Hub preparation close affordance

**Roadmap ticket:** BA-062 M4

**Evidence level:** E1 source/static only

## Decision

Hub preparation screens now share one device-neutral `CLOSE` GUI affordance owned by `HubPreparationController`.

The button is shown only after the router successfully opens one of its existing preparation `ScreenGui` surfaces and is hidden whenever `closeHubUi()` runs. `Activated` routes directly to that same close helper, so pointer click, touch tap, and gamepad GUI activation do not create another preparation-state owner.

## Compatibility

- keyboard `Escape` remains supported in this isolated M4 increment;
- no direct gamepad key is added;
- `ButtonB`, `ButtonX`, triggers, stick clicks, and D-pad directions remain untouched;
- the shared input action map records `CloseHubUI` as `RawInputAndGui`, with `Escape` plus GUI-button activation;
- no class, loadout, expedition, networking, persistence, or gameplay mutation authority changes.

## Remaining boundary

This closes the missing-affordance portion of M4 at source level. C3 remains separate: `RPGMenuController` and `HubPreparationController` still each listen for `Escape` and should be coordinated in a dedicated increment rather than folded into this presentation change.

Real touch/gamepad navigation reachability remains for the consolidated Studio/device acceptance pass.
