# Living Kingdoms — Canonical Runtime

This file is the short answer to **what is actually live and authoritative?**

## Canonical source

`games/living-kingdoms/src/` is the only gameplay-authoritative source tree.

The runtime currently boots from `src/server/init.server.luau` plus the dedicated expedition bootstrap scripts. Modern server systems own combat, enemies, operative life, missions, expedition runtime, inventory/persistence, loot/rewards, classes, weapons, progression, presentation state, and the generated operation world.

## Imported Studio content

`games/living-kingdoms/imports/studio-2026-08-07/` is preservation/reference material.

It exists so the older authored place can be reconciled without losing content. **Nothing under `imports/` is allowed to become a second gameplay authority.** In particular, do not boot the imported RPG bootstrap or its legacy combat, enemy, inventory, loot, player-data, or monetization managers beside the modern runtime.

## World-content bridge

Stable IDs live in:

- `src/shared/World/WorldContentContracts.luau`
- `src/shared/Config/WorldContentConfig.luau`

Gameplay should target these IDs rather than relying on legacy Studio instance names. The registry also records legacy aliases so imported content can be mapped deliberately.

Current status:

- `world.operation.forest` — **active** modern operation world.
- current operation landmarks — **active**.
- `world.hub.primary` / `HubTown` — **preserved, inactive**, pending preparation-flow integration.
- imported `WorldPath`, `Resources`, `WorldStructures`, `Buildings` — **preserved, inactive**, pending geometry/content reconciliation.
- imported tree/rock/iron resource concepts — **preserved, inactive**, pending canonical inventory/persistence integration.

## Merge rule

When old and new systems overlap, keep the modern authoritative owner and port only missing content, rules, presentation, or data into it.

Do not solve overlap by running both systems.

## Next integration order

1. Finish stable world-content IDs and imported-name mapping (BA-004).
2. Add HubTown as a presentation/preparation zone that delegates loadout, class, inventory, progression, and expedition launch to current owners.
3. Add a canonical expedition portal/launch interaction; do not reuse the old dungeon authority unchanged.
4. Port valuable dungeon/quest modifiers into current expedition + mission contracts.
5. Add gathering/crafting only through current persistence/inventory transaction boundaries.
6. Reconstruct remaining authored Studio geometry/properties after gameplay ownership is stable.
