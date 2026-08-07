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

## Active v2.7 incident gate

The active-place network/Highlight incident still outranks feature expansion.

Current source containment on `main` now includes:

- an R1 `HordeStateEarlyListener` that binds `HordeNetwork.State` before the remaining client controller graph;
- bounded client diagnostics for listener-bound state, received/invalid message counts, and last revision;
- a conservative `BroadHighlightGuardController` that disables only Workspace/Terrain/very-large top-level world-root Highlight targets;
- bounded diagnostics for rejected broad Highlights and the last rejected target;
- temporary rollout flags in `RuntimeRolloutConfig`;
- rollback branch `archive/pre-v2.7-r1-containment-2026-08-07` at `6d88a33df1742981839c59933289eb0381e82074`;
- prepared runtime packet `../../docs/production/evidence/2026-08-07-336-r1-state-highlight-containment.md`.

These are E1 source facts only. The incident is **not closed** until a Studio/runtime packet proves the R1 behavior.

## Where to continue

1. Run/fill `../../docs/production/evidence/2026-08-07-336-r1-state-highlight-containment.md` against the active development place.
2. If R1 passes, update `../../docs/production/V2.7-CUTOVER-LEDGER.md` with measured facts.
3. Consolidate the remaining `HordeHUDController` and `MassacreCrescendoController` direct `State` listeners onto the application bridge.
4. Implement R2 `ClientReady` gating, then R3 semantic-key/change-token suppression with before/after send-rate evidence.
5. Only after the v2.7 stop conditions are accepted should work resume on the preserved HubTown/preparation bridge, authored-world reconstruction, quest reconciliation, and procedural dungeon integration.

## Merge references

1. `../../docs/production/RBXL-MERGE-2026-08-07.md` — reconciliation matrix and M0–M5 integration order.
2. `../../docs/decisions/2026-08-07-living-kingdoms-rbxl-merge.md` — merge decision and authority rules.
3. `imports/studio-2026-08-07/README.md`, `manifest.json`, and `VALIDATION.md` — preserved Studio import details.

## Recovery

- Untouched pre-RBXL-merge repository: `archive/pre-rbxl-merge-2026-08-07` at `852de4953155379a4cc4733fe8dd05cd6f51477e`.
- Pre-v2.7-R1-containment repository: `archive/pre-v2.7-r1-containment-2026-08-07` at `6d88a33df1742981839c59933289eb0381e82074`.
