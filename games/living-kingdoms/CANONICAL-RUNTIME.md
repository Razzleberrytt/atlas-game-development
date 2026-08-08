# Living Kingdoms — Canonical Runtime

This file is the short answer to **what is live and authoritative right now?**

## Canonical source

`games/living-kingdoms/src/` is the only gameplay-authoritative source tree.

The modern runtime owns combat, enemies, operative life, missions, expedition runtime, inventory/persistence boundaries, loot/rewards, classes, weapons, progression, presentation state, the generated operation world, and the source-managed preparation shell.

## Imported Studio content

`games/living-kingdoms/imports/studio-2026-08-07/` is preservation/reference material.

It exists so the older authored place can be reconciled without losing content. **Nothing under `imports/` is allowed to become a second gameplay authority.** Do not boot the imported RPG bootstrap or its legacy combat, enemy, inventory, loot, player-data, monetization, quest, dungeon, or gathering managers beside the modern runtime.

## Current preservation and reconstruction truth

The repaired direct re-extraction verifies:

- all **28 / 28** Studio-only source files
- all **1,775 / 1,775** Workspace identity/hierarchy rows

BA-005 property recovery now also verifies:

- **1,699** base geometry/light/world-property rows
- **1,742** rows after adding SurfaceGui, TextLabel and ParticleEmitter presentation decoding
- zero failures among the current allowlisted property types

Current evidence:

- `../../docs/migration/REEXTRACTED-WORLD-EVIDENCE.md`
- `../../docs/migration/current/reextracted-world-evidence.json`
- `../../docs/migration/current/reextracted-property-evidence.json`
- `../../docs/migration/current/reextracted-presentation-evidence.json`

Older migration files that cite only 122 recovered Workspace rows describe the damaged first archive. Do not use those missing-row conclusions as current reconstruction evidence.

## Two coordinate spaces

### Authored Overworld

The recovered Studio world is a separate future overworld coordinate space. Preserve its authored coordinates at 1:1 scale.

Source roots include:

- legacy HubTown
- Resources
- WorldPath
- WorldStructures
- original overworld spawn/environment presentation

Do not scale/translate these roots into the current combat forest and do not parent them under `WorldFoundationService` merely to make them fit.

The placement contract is:

`src/shared/Config/RecoveredWorldPlacementConfig.luau`

It remains held and runtime-disabled.

### Modern Operation Space

The current `LivingKingdomsWorld` forest remains the modern operation/expedition space with its existing ±640-stud design and server-authoritative gameplay systems.

The intended end-state transition is:

**authored overworld / HubTown → canonical expedition launch → modern operation runtime**

The current Ranger Station Forward Operations Hub is the temporary preparation bridge until the dedicated overworld lifecycle/place boundary exists.

## World-content bridge

Stable IDs live in:

- `src/shared/World/WorldContentContracts.luau`
- `src/shared/Config/WorldContentConfig.luau`

Gameplay should target stable IDs rather than legacy Studio instance names.

Current live status:

- `world.operation.forest` — **active** modern operation world
- current operation landmarks — **active**
- `zone.hub.forward_operations` — **active** temporary preparation shell
- `station.hub.class` — **active**, delegates to current class selection
- `station.hub.weapon` — **active**, delegates to current weapon loadout
- `portal.expedition.primary` — **active presentation entry point**, delegates launch authority to current expedition lobby/runtime
- `world.hub.primary` / legacy `HubTown` — **reconstruction source; legacy runtime authority inactive**

## Held authored-overworld reconstruction contracts

### WorldPath

`src/shared/Config/RecoveredWorldPathConfig.luau`

The 189 identical Studio path slabs are represented by one deterministic route contract rather than promoted as 189 canonical runtime instances.

- source hold enabled
- runtime disabled
- 1:1 authored coordinate evidence retained

### DungeonPortal

`src/shared/Config/RecoveredDungeonPortalConfig.luau`

The first recovered HubTown group now accounts for all 10 identities:

- 1 generated container
- 9 / 9 non-container nodes with property-backed reconstruction data
- recovered Parts, PointLights, Attachment, SurfaceGui, TextLabel and ParticleEmitter
- one known visual omission: TextLabel `FontFace`

The old sign text and particle behavior are evidence/presentation only. No prompt is invented and no old dungeon authority returns.

Future portal gameplay still delegates to:

- `portal.expedition.primary`
- `ExpeditionLobbyService`

## Forward Operations Hub

The live hub shell does **not** claim to be the reconstructed legacy HubTown.

It removes preparation-screen clutter by making existing specialist, armory, and expedition lobby surfaces available through physical Ranger Station stations. The existing `C` / `I` / `K` RPG menu remains the character/inventory/skills owner.

## Merge rule

When old and new systems overlap, keep the modern authoritative owner and port only missing content, rules, presentation, or data into it.

Do not solve overlap by running both systems.

## Next integration order

1. Reconstruct the legacy **quest board** as a held authored-overworld presentation contract using recovered Part/SurfaceGui/TextLabel evidence.
2. Recover its remaining BillboardGui container properties and keep old `[B]` / `[G]` shortcut wording presentation-only.
3. Design a quest-board adapter into the current mission contracts / `MissionDirectorService`; do not revive legacy QuestService authority.
4. Reconstruct other coherent HubTown presentation groups such as Central Fountain and vendor stalls.
5. Reconstruct Resources and high-value WorldStructures groups behind the authored-overworld hold.
6. Implement the dedicated authored-overworld project/lifecycle boundary.
7. Add gathering/crafting and vendor/economy gameplay only through canonical inventory/persistence/currency owners.
8. Collect Studio/runtime/multiplayer evidence before describing the combined game as fully fused.
