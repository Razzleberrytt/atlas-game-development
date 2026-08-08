# Living Kingdoms — Canonical Runtime

This file is the short answer to **what is live and authoritative right now?**

## Canonical source

`games/living-kingdoms/src/` is the only gameplay-authoritative source tree.

The modern runtime owns combat, enemies, operative life, missions, expedition runtime, inventory/persistence boundaries, loot/rewards, classes, weapons, progression, presentation state, the generated operation world, and the source-managed preparation shell.

## Imported Studio content

`games/living-kingdoms/imports/studio-2026-08-07/` is preservation/reference material.

It exists so the older authored place can be reconciled without losing content. **Nothing under `imports/` is allowed to become a second gameplay authority.** In particular, do not boot the imported RPG bootstrap or its legacy combat, enemy, inventory, loot, player-data, monetization, quest, dungeon, or gathering managers beside the modern runtime.

## Current preservation truth

The repaired direct re-extraction verifies:

- all **28 / 28** Studio-only source files
- all **1,775 / 1,775** Workspace identity/hierarchy rows

Current world evidence is summarized in:

- `../../docs/migration/REEXTRACTED-WORLD-EVIDENCE.md`
- `../../docs/migration/reextracted-world-evidence.json`

Older migration files that cite only 122 recovered Workspace rows describe the damaged first archive. Do not use those missing-row conclusions as current BA-005 evidence.

## World-content bridge

Stable IDs live in:

- `src/shared/World/WorldContentContracts.luau`
- `src/shared/Config/WorldContentConfig.luau`

Gameplay should target these IDs rather than relying on legacy Studio instance names. The registry also records legacy aliases so imported content can be mapped deliberately.

Current status:

- `world.operation.forest` — **active** modern operation world
- current operation landmarks — **active**
- `zone.hub.forward_operations` — **active** source-managed preparation shell at the Ranger Station
- `station.hub.class` — **active**, delegates to current class selection
- `station.hub.weapon` — **active**, delegates to current weapon loadout
- `portal.expedition.primary` — **active presentation entry point**, delegates launch authority to current expedition lobby/runtime
- `world.hub.primary` / legacy `HubTown` — **preserved, inactive** as a runtime owner
- imported `WorldPath`, `WorldStructures`, `Resources`, legacy gathering nodes — **preserved migration inputs**, not yet property-reconstructed

## Forward Operations Hub

The live hub shell intentionally does **not** reproduce the entire old HubTown yet.

It removes preparation-screen clutter by making the existing specialist, armory, and expedition lobby surfaces available through physical stations. The existing `C` / `I` / `K` RPG menu remains the character/inventory/skills owner.

The expedition lifecycle controller may force preparation surfaces closed while a run is active. Outside a run, the hub interaction layer decides when those surfaces open.

## Merge rule

When old and new systems overlap, keep the modern authoritative owner and port only missing content, rules, presentation, or data into it.

Do not solve overlap by running both systems.

## Next integration order

1. **BA-005 identity reconstruction:** turn the complete re-extracted hierarchy into deterministic, source-managed authored-world definitions behind the source hold.
2. **BA-005 property reconstruction:** extend the RBXL extractor for supported CFrame/size/material/color/light/VFX properties and generate property-backed definitions/parity checks.
3. Reconstruct valuable legacy HubTown authored presentation against the modern preparation shell; do not resurrect legacy authority.
4. Port dungeon portal/modifier concepts into current expedition contracts/runtime.
5. Port quest-board concepts into current mission contracts.
6. Add gathering/crafting only through current inventory/persistence transaction boundaries.
7. Reconcile vendor/economy concepts only through canonical currency/inventory owners.
8. Collect Studio/runtime/multiplayer evidence before describing the combined game as fully fused.
