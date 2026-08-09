# BA-032 — First Repeatable Dungeon Content

**Status:** DONE as authored data; runtime consumption remains intentionally unwired.

**Primary source:** `games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau`

## Goal

BA-030 added the dungeon-content seam (`EncounterSlotId`, `EncounterIntensity`, and elite/boss reward references) without choosing concrete enemies. BA-032 supplies the first real authored run against that seam while preserving the existing combat, enemy, horde-role, room-assembly, and reward authorities.

This is not a second dungeon runtime and does not spawn anything by itself.

## Canonical repeatable run

The content pins seed `202` for the existing deterministic `RoomSequenceAssembler`. That seed currently resolves to the seven-room path below:

1. `descent-entry` — safe arrival, no encounter
2. `collapsed-gallery` — light patrol: 2 basic Exclusion Stalkers
3. `warden-barracks` — standard squad: 2 basic Stalkers + 1 Runner
4. `broken-sanctum` — light patrol: 2 Crawlers
5. `sunken-archive` — standard squad: 2 basic Stalkers + 1 Blight Spitter
6. `warden-threshold` — elite guard: 1 Brute + 1 Screamer; preserves the BA-030 `Elite` reward reference
7. `keeper-core` — boss encounter: 1 Progenitor; preserves the BA-030 `Boss` reward reference

`FirstDungeonContentConfig.test.luau` independently verifies that seed `202` still assembles this exact path, so later room-pool edits cannot silently mutate the first authored dungeon.

## Canonical-system references

The content does not invent enemy IDs or spawning vocabulary:

- enemy archetypes come from `EnemyContracts.EnemyArchetypeIds`;
- all authored dungeon waves use `EnemyContracts.EnemySpawnSourceIds.AuthoredWave`;
- Stalker variants use role IDs from `HordeExperienceConfig.Roles`;
- room slots/intensity/reward references must exactly match `RoomAssemblyConfig` / `RoomAssemblyContracts`;
- the boss uses the existing `boss.progenitor` archetype already owned by the canonical boss/enemy runtime.

The config validates those relationships at load time.

## Why seed 202

A fixed canonical seed lets the first content package reuse the already-tested deterministic room assembler instead of introducing a parallel fixed-route system. The wider room pool still retains its seeded variation for future content; BA-032 simply identifies one stable, short path suitable for the first repeatable authored dungeon.

## Explicitly not activated here

BA-032 does **not** change `ExpeditionServerBootstrap.resolveEncounter`, `EnemyDirectorService`, `HordeExperienceService`, boss runtime code, equipment rewards, inventory, persistence, or the lobby return path. A future integration ticket may consume `FirstDungeonContentConfig`, but it must adapt the data into the existing authoritative systems rather than creating a competing spawner/reward owner.

## Follow-on

BA-033 may now author the elite/boss **reward-decision data** against the already-existing loot/item/run-build owners. It should not broaden BA-032 into a new inventory or persistence path.
