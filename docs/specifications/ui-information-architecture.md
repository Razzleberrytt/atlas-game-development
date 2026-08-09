# BA-063 — UI Information Architecture

**Status:** DATA-ONLY / DORMANT  
**Runtime activation:** No  
**Evidence level:** E1 source/static only  
**Primary source:** `games/living-kingdoms/src/shared/Config/UIInformationArchitectureConfig.luau`  
**Input source of truth:** `docs/specifications/input-action-map-audit.md` (BA-061 / BA-062)

## Purpose

BA-063 defines one MVP UI information architecture before more screens are added. It records which canonical surface owns presentation, which server-side systems own the state being shown or mutated, when each surface should be visible, and which surfaces must not compete for player input.

This is intentionally **not** a UI rewrite and **not** a shared modal coordinator. Existing runtime behavior is left unchanged. The goal is to give later UI/input work one matrix to implement against instead of allowing each controller to invent its own overlap rules.

## Architecture principles

1. **Presentation is not gameplay authority.** A controller may render state or submit a narrow request, but canonical server services keep validation and mutation ownership.
2. **One input-owning modal at a time.** Character, inventory, progression-choice, and relic-choice surfaces all belong to one future exclusive-input-modal policy.
3. **Ambient HUD may coexist.** Objective/combat HUD and persistent build summaries can remain behind a modal when readable because they do not need to compete for selection input.
4. **Hub panels are routed, not stacked.** Specialist, loadout, and expedition lobby are mutually exclusive preparation panels and are closed when an expedition becomes active.
5. **Results and decisions stay separate.** The expedition result is read-only. Replay/return intent belongs to the separate party-decision surface.
6. **BA-061 owns the action inventory.** BA-063 references that audit and does not duplicate keyboard/gamepad/touch bindings.

## Screen-state matrix

| Surface | Context | Runtime GUI path | Presentation owner | Canonical state / mutation owner(s) | Input policy | Visibility | Mutation request? |
|---|---|---|---|---|---|---|---|
| Specialist selection | Preparation | `TemporaryClassSelectionUI` | `HubPreparationController` routes it | `ClassService` | Hub routed | Safe preparation only | Yes |
| Weapon loadout | Preparation | `WeaponLoadoutSelectionUI` | `HubPreparationController` routes it | `WeaponLoadoutService` | Hub routed | Safe preparation only | Yes |
| Expedition lobby | Preparation | `LK_ExpeditionLobby` | `ExpeditionLobbyController` | `ExpeditionLobbyService` | Hub routed | Safe preparation only | Yes |
| Character record | Global | `RPGMenu.Modal.CharacterPanel` | `RPGMenuController` | Class / loadout / life / run-progression services | Exclusive input modal | Player toggle | No |
| Inventory record | Global | `RPGMenu.Modal.InventoryPanel` | `RPGMenuController` | Inventory / persistence / loadout services | Exclusive input modal | Player toggle | No |
| Expedition objective HUD | Expedition | `LK_ExpeditionHUD` | `ExpeditionHUDController` | `ExpeditionLiveRuntimeService` | Ambient | Active run only | No |
| Combat HUD | Expedition | `LivingKingdomsHordeHUD` | `HordeHUDController` | Mission / horde / combat / life / progression services | Ambient | Active run only | No |
| Level-up choice | Expedition | `LivingKingdomsHordeHUD.UpgradeOverlay` | `HordeHUDController` | `RunProgressionService` | Exclusive input modal | Reward pending | Yes |
| Run Relic summary | Expedition | `LK_RunBuildHUD.RelicBar` | `RunBuildHUDController` | `RunBuildService` | Ambient | Build relevant | No |
| Run Relic choice | Expedition | `LK_RunBuildHUD.RelicReward` | `RunBuildHUDController` | `RunBuildService` | Exclusive input modal | Reward pending | Yes |
| Expedition result | Debrief | `LK_ExpeditionResult` | `ExpeditionResultController` | `ExpeditionResultService` | Read-only result | Resolved run | No |
| Replay / return decision | Debrief | `LK_ExpeditionReplayDecision` | `ExpeditionReplayDecisionController` | `ExpeditionPartyDecisionService` | Decision | Decision pending | Yes |

## Input-modal contract

The current runtime uses the player attribute `LK_InputModalOpen` as a loose coordination signal. `RPGMenuController`, the Horde progression-choice overlay, and the Run Relic choice surface already participate in that convention, but there is no single owner arbitrating all modal states.

BA-063 therefore records the desired contract without pretending it is implemented:

- at most one surface with `ExclusiveInputModal` policy should accept selection input at a time;
- opening one exclusive modal should eventually close, defer, or suppress another rather than letting both consume the same selection action;
- cursor visibility and `GuiService.SelectedObject` should eventually be owned by that same coordination boundary;
- ambient/read-only HUD should not acquire modal ownership merely because it is visible;
- this ticket does not introduce the coordinator itself.

## Hub-routing contract

`HubPreparationController` already closes the specialist, loadout, and expedition-lobby surfaces before opening the requested one and closes hub UI when the expedition enters `InProgress`.

BA-063 preserves that shape as the preparation-layer rule:

`safe preparation → one routed preparation panel → deliberate launch → routed preparation panels hidden`

The UI architecture does not move class, weapon, or launch validation to the client.

## Expedition/debrief layering

During an active expedition, the objective HUD, combat HUD, and Run Relic summary are ambient information surfaces. They may coexist because their normal state is read-only.

When progression or relic selection is required, the corresponding choice surface becomes an input-owning modal. The server still authors and validates the available choices.

After resolution:

`read-only result → separate replay/return decision → server-resolved next action`

The result surface must not become a second lifecycle or reward authority simply to host buttons.

## Known open risks inherited from BA-061 / BA-062

BA-063 deliberately records rather than fixes these issues:

- independent `Escape` ownership remains open between existing controllers;
- number keys `1`–`3` can still be claimed by both progression and Run Relic choice surfaces if their local active states overlap;
- the `E` revive / world-prompt and `ButtonX` class-action / world-prompt collisions remain BA-062 work;
- device-adaptive labels and full gamepad coverage remain incomplete;
- a shared input/action map and a shared modal coordinator are still future work.

These are not hidden by the architecture document and are not claimed as remediated.

## Non-authority boundary

BA-063 does not:

- create or destroy GUI instances;
- start a client controller;
- bind keyboard, mouse, gamepad, or touch actions;
- fire or invoke remotes;
- mutate class, loadout, inventory, progression, relic, result, party, or lifecycle state;
- own persistence;
- alter current DisplayOrder values;
- resolve BA-062 input collisions;
- activate a central modal coordinator;
- claim Studio/runtime/device acceptance.

## Validation

`games/living-kingdoms/tests/UIInformationArchitectureConfig.test.luau` pins:

- the twelve canonical MVP UI surfaces;
- unique surface IDs and GUI paths;
- canonical presentation and server-state owner boundaries;
- the four current/future exclusive-input-modal surfaces;
- hub-panel exclusivity, ambient-HUD coexistence, and result/decision separation;
- explicit references back to BA-061 and BA-062 rather than a duplicated key map;
- the known Escape, number-choice, prompt-action, and adaptive-label risks;
- absence of runtime GUI creation, key binding, remote invocation, and persistence ownership from the BA-063 config.

Studio/manual verification is not required to accept BA-063 because it changes no runtime behavior. A later UI-coordination implementation must receive normal source tests and the consolidated exact-build Studio/device pass before any runtime acceptance claim.

## Completion boundary

BA-063 is complete when the config, fixture, and this specification agree on the screen-state matrix and CI is green. Completion means the architecture is available for future implementation; it does **not** mean the existing UI has been centralized or all overlap risks have been fixed.
