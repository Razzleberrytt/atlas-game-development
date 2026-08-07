# Living Kingdoms Merge Status

**Current merge:** Studio `livingkingdoms.rbxl` + canonical Atlas/Living Kingdoms Rojo source  
**Import date:** 2026-08-07  
**Evidence level:** E1 source/reconciliation only

## Canonical rule

The active `src/` tree remains authoritative for combat, enemies, operative life state, inventory, persistence, rewards, expedition runtime, networking, and presentation. The Studio import is additive and inert until each unique feature is reconciled against those owners.

## Preserved Studio material

- 28 Studio-only source files preserved losslessly under `imports/studio-2026-08-07/` as a restorable source archive.
- 1,775 Workspace objects preserved by identity/path in the restorable Workspace hierarchy index.
- Authored HubTown, dungeon portal, resource fields, landmarks/ruins, world structures, lighting/VFX and NPC structures retained as migration inputs.
- Legacy quest, gathering/crafting, vendor/economy, dungeon and UI concepts retained for best-of-both integration.

## Do not boot unchanged

`RPGServerBootstrap`, legacy `CombatService`, `EnemyService`, `InventoryService`, `LootService`, `PlayerDataService`, and `MonetizationService` are reference implementations only. They overlap newer server authority.

## Where to continue

1. Read `../../docs/production/RBXL-MERGE-2026-08-07.md` for tickets M-01 through M-08.
2. Read `../../docs/decisions/2026-08-07-living-kingdoms-rbxl-merge.md` for the merge decision and authority rules.
3. Read `imports/studio-2026-08-07/README.md` and `manifest.json` before touching the preserved import.
4. **Next highest-ROI task: M-01 + M-03** — reconstruct the authored HubTown/world into source-managed assets and connect the hub preparation/launch flow to canonical expedition/loadout services.

## Recovery

The untouched pre-merge repository is frozen at `archive/pre-rbxl-merge-2026-08-07` (commit `852de4953155379a4cc4733fe8dd05cd6f51477e`).
