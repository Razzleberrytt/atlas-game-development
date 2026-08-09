# BA-030 — Dungeon/Expedition Content Contract

**Status:** DONE (content contract only; no runtime activation)
**Scope:** `games/living-kingdoms/src/shared/Expeditions/RoomAssemblyContracts.luau` and `games/living-kingdoms/src/shared/Config/RoomAssemblyConfig.luau`.

## Why this exists

`RoomAssemblyContracts`/`RoomAssemblyConfig` already defined the room *layout* (role, weight, depth bounds, tags) that `RoomSequenceAssembler` orders into a `RoomPlan`. Nothing in that shape said what populates a room or what it grants, so `ExpeditionServerBootstrap.resolveEncounter` invented wave composition procedurally from the expedition's 7-phase timeline instead of from authored room content. This closes that gap at the content-contract level, matching the "Dungeon IDs, room/encounter sequence, elite/boss slots, reward refs, return path, difficulty metadata" deliverable in `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` (BA-030).

## What was added

- `RoomDefinition.EncounterSlotId: EncounterSlotId` — one of `None | LightPatrol | StandardSquad | EliteGuard | BossEncounter`. This names a *category* only; concrete enemy archetype selection (which existing `EnemyConfig`/`SpecialEnemyConfig` roles populate a squad) remains a future runtime spawner's decision, not this contract's — consistent with "do not create a second gameplay authority."
- `RoomDefinition.EncounterIntensity: number` — a small non-negative integer (0 for the entry, 1 for light patrols, 2 for standard squads, 3 for the boss). This is the difficulty metadata BA-030 asked for; it mirrors the count values already hardcoded in `ExpeditionServerBootstrap.resolveEncounter` (1/2/3) so a future consumer has an authored number instead of a `PhaseId`-keyed literal.
- `RoomDefinition.RewardSourceId: RoomRewardSourceId?` — `nil` except on the Elite/Boss rooms, where it is `"Elite"` / `"Boss"`. These are the same two literal strings `EquipmentRewardContracts.RewardSourceId` already uses; the type is declared locally rather than imported so `RoomAssemblyContracts.luau` stays a standalone, dependency-free contract (multiple existing fixtures load it without a `script`/`require` stub).
- `RoomAssemblyConfig.luau`'s existing per-room load-time validation now also asserts: every room declares a non-negative `EncounterIntensity`; only `Elite`/`Boss` rooms declare a `RewardSourceId`; `Elite` rooms use the `EliteGuard` slot and the `Elite` reward source; `Boss` rooms use the `BossEncounter` slot and the `Boss` reward source.
- `tests/RoomAssemblyEncounterContent.test.luau` locks the same invariants as an independent regression fixture.

## Dungeon ID

`RoomAssemblyConfig.DefinitionId` (`"first-expedition-room-plan"`) already served as the stable identity for the current authored room pool; BA-030 did not introduce a second `DungeonId` field or a multi-dungeon registry, since only one dungeon definition exists today. A future multi-dungeon ticket should key additional pools by new `DefinitionId` values rather than inventing a parallel identity field.

## Return path

No new field was needed. `expedition-lobby.server.luau`'s existing `returnToLobby` handler is already the canonical return-to-safety path: once `ExpeditionLiveRuntimeService.readSnapshot().OutcomeId` leaves `InProgress` (i.e., the boss room's terminal state resolves), a player may request `"ReturnToLobby"`, which calls `ExpeditionLiveRuntimeService.stopExpedition("ReturnedToLobby")` and clears room placement. The boss room (`RoleIds.Boss`, `RoomPlan.BossIndex`) is structurally the terminal node in the linear route, so "return path" for this content contract is: reach the boss room, resolve its outcome, then use the existing return-to-lobby remote. No second return mechanism was created.

## Explicitly out of scope

- No spawner change: `ExpeditionServerBootstrap.resolveEncounter`, `ExpeditionRoomPlacementService`, `EnemyDirectorService`, and `EquipmentRewardService` are untouched. The new fields are available for a future ticket (tracked as BA-032, blocked on this one) to consume; leaving them unwired keeps this change data-only.
- No new reward vocabulary: `RoomRewardSourceId` intentionally mirrors `EquipmentRewardContracts.RewardSourceId` instead of introducing a competing reward-reference shape.
- No multi-dungeon registry, no branch/graph return path beyond the existing linear route and lobby-return remote.
