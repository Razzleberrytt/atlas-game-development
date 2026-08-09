# BA-060 — First-Session Onboarding Sequence

**Status:** DATA-ONLY / DORMANT  
**Runtime activation:** No  
**Primary source:** `games/living-kingdoms/src/shared/Config/FirstSessionOnboardingConfig.luau`

## Purpose

BA-060 turns the playable-MVP loop into one explicit first-session journey without introducing a tutorial controller or a second gameplay authority.

The intended player experience is:

`safe arrival → specialist → loadout → expedition terminal → deliberate launch → outdoor approach → optional Lookout Cache → First Descent → Run Relic choice → result → return to safety → understand/apply build choice → deliberately start another run`

The sequence is an integration map. It distinguishes what already exists in runtime from prepared content and from the one known lifecycle blocker.

## Implementation-state vocabulary

- **RuntimeExisting** — the referenced owner/surface already exists in the canonical runtime; BA-060 only sequences the player-facing goal around it.
- **PreparedData** — content is authored and validated but intentionally has no approved runtime consumer yet.
- **PreparedIntegration** — the canonical gameplay owner exists, but the authored first-session handoff/reward mapping is still dormant or incomplete.
- **BlockedLifecycle** — the intended player-facing behavior conflicts with a current canonical lifecycle behavior and must not be integrated until that owner is deliberately reconciled.

These labels prevent a prepared document/config from being mistaken for Studio-proven or runtime-complete gameplay.

## First-session sequence

| # | Player beat | State | Ownership boundary |
|---:|---|---|---|
| 1 | Arrive safely at Forward Operations | RuntimeExisting | `HubPreparationService` |
| 2 | Inspect/select specialist | RuntimeExisting | `ClassService` |
| 3 | Inspect/select weapon loadout | RuntimeExisting | `WeaponLoadoutService` |
| 4 | Open expedition terminal and deliberately ready/launch | RuntimeExisting | `ExpeditionLobbyService` |
| 5 | Traverse the authored outdoor approach | PreparedData | prepared route integration boundary |
| 6 | Optionally discover the Lookout Cache | PreparedData | prepared discovery integration boundary |
| 7 | Complete the First Descent room/elite/boss/terminal sequence | PreparedData | prepared expedition-content integration boundary |
| 8 | Make the authored two-choice Run Relic decision | PreparedIntegration | `RunBuildService` |
| 9 | Read the resolved expedition result | RuntimeExisting | `ExpeditionResultService` |
| 10 | Return to safe preparation | RuntimeExisting | existing expedition-lobby server bridge |
| 11 | Confirm the earned Run Relic/build choice | PreparedIntegration | `RunBuildService` |
| 12 | Deliberately start another run | **BlockedLifecycle** | `OperationLifecycleService` |

The Lookout Cache is the sole optional first-session beat; skipping it cannot block the main route.

## Existing runtime seams

BA-060 reuses, rather than duplicates:

- the Forward Operations hub/station configuration;
- `ClassService` for class mutation;
- `WeaponLoadoutService` for weapon/loadout mutation;
- `ExpeditionLobbyService` plus the existing server lobby bridge for ready/launch and resolved-run return handling;
- `ExpeditionResultService` for result finalization;
- `RunBuildService` for Run Relic choice validation/application.

The safe-arrival launch boundary remains server-owned: mission/horde pressure is armed only after the lobby consumes a valid deliberate launch.

## Prepared content seams

The sequence references the already-authored dormant MVP packages rather than booting them:

- BA-050 first outdoor route;
- BA-051 outdoor encounter beats;
- BA-052 Lookout Cache discovery;
- BA-032 First Descent deterministic dungeon content;
- BA-033 elite/boss Run Relic reward-decision mapping.

A `PreparedData` or `PreparedIntegration` label is not a runtime acceptance claim.

## Explicit lifecycle blocker: deliberate replay

The intended MVP loop returns the player to safety, lets the player understand/apply the earned build change, and requires a deliberate action to start the next run.

The current `OperationLifecycleService` instead owns server-driven replay after debrief and automatically restarts the operation. BA-060 therefore marks the final replay step `BlockedLifecycle`.

This task does **not** change, stop, bypass, or replace `OperationLifecycleService`. That behavior may intersect accepted Blueprint v2.7 lifecycle evidence, so it must be reconciled as a dedicated runtime/integration change with the appropriate evidence discipline rather than as a side effect of onboarding work.

## Non-authority boundary

BA-060 does not:

- display or advance tutorial prompts;
- create RemoteEvents or fire remotes;
- mutate class/loadout/relic state;
- start/stop expeditions;
- spawn route/dungeon content;
- grant rewards;
- teleport/return players;
- write persistence;
- modify `OperationLifecycleService`;
- claim Studio/runtime acceptance.

## Validation

`games/living-kingdoms/tests/FirstSessionOnboardingConfig.test.luau` pins:

- the twelve-step arrival → deliberate-replay ordering;
- real class/loadout/lobby/result/run-build owner boundaries;
- references to the prepared route/discovery/dungeon/reward packages;
- exactly one optional discovery beat;
- exactly one lifecycle-blocked step, and only at deliberate replay;
- the explicit current auto-replay mismatch;
- absence of raw Workspace paths, DataStore ownership, RemoteEvents, or remote firing.

Studio/manual verification is not required for BA-060 because it is dormant orchestration data/specification. The later runtime integration and consolidated MVP exact-build Studio pass must validate whether a new player can actually understand and complete this journey without developer explanation.
