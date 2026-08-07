# RBXL Merge Ledger — 2026-08-07

**Purpose:** operational ledger for reconciling the supplied `livingkingdoms.rbxl` with the current Atlas/Living Kingdoms source tree without silently losing either version.

## Incoming build

| Fact | Value |
|---|---|
| Source file | `livingkingdoms.rbxl` |
| Size | 1,639,392 bytes |
| SHA-256 | `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16` |
| Place instances | 2,258 |
| Script/module instances | 290 |
| Workspace instances | 1,775 |
| Pre-merge checkpoint | `archive/pre-rbxl-merge-2026-08-07` |

## Authority policy

The current repository wins where the two versions implement the same consequential runtime responsibility. The incoming place wins only as a source of unique authored content or concepts that are absent from the canonical implementation.

This is not a license to delete old work. Unique incoming source is archived losslessly and incoming Workspace hierarchy is indexed before feature integration.

## Reconciliation matrix

| Incoming area | Canonical disposition | Reason |
|---|---|---|
| Current-style client/server/shared modules embedded in place | `REPO_WINS` when source hash matches or repo is newer | Avoid two copies of the same maintained system. |
| `RPGServerBootstrap` | `PRESERVE_ONLY` | Would create overlapping boot/runtime ownership; references missing legacy deps. |
| Old `CombatService` | `PRESERVE_ONLY` | Current combat pipeline is newer, tested, server-authoritative. |
| Old `EnemyService` | `PRESERVE_ONLY` | Current `EnemyDirectorService`/encounter stack owns enemy truth. |
| Old `InventoryService` | `PRESERVE_ONLY` | Current live inventory/session/persistence stack owns mutation. |
| Old `LootService` | `PRESERVE_ONLY` | Current survival/enemy/equipment reward systems own drops/rewards. |
| Old `PlayerDataService` | `PRESERVE_ONLY` | Current persistence contracts/adapters/session ownership are safer. |
| `MonetizationService` | `PRESERVE_ONLY` | Product scope and receipt authority require focused integration. |
| `HubTownService` | `PORT_CONCEPTS` | High-value preparation/vendor/meta layer; adapt to current lobby/expedition flow. |
| `QuestService` | `PORT_CONCEPTS` | Useful short-session quest/modifier layer; must become data-driven/current-authority. |
| `DungeonService` | `PORT_CONCEPTS` | Preserve encounter/modifier ideas; current `Expedition*` room assembly remains owner. |
| `SurvivalGatheringService` + Hatchet | `FEATURE_GATED_PORT` | Distinct gameplay; preserve now, activate only after core expedition evidence. |
| Old RPG/Shop UI | `PORT_PRESENTATION_IDEAS` | Useful structure but must not duplicate current centralized presentation owners. |
| Authored Workspace world | `PRESERVE_AND_RECONSTRUCT` | Valuable authored content; hierarchy captured now, geometry/property promotion requires focused world-source pass. |

## Unique content preservation

The inert import package at `games/living-kingdoms/imports/studio-2026-08-07/` contains:

- lossless archive of all 28 unique old-RPG source files;
- complete Workspace instance hierarchy/path index;
- script reconciliation manifest with incoming/repo source hashes;
- source-place fingerprint;
- restore helper.

It is deliberately outside the live Rojo mapping.

## World roots found in the Studio place

- `HubTown`
- `Resources`
- `Buildings`
- `WorldStructures`
- `WorldPath`
- authored spawn/safety objects
- Terrain/Camera
- ambience/cloud/firefly objects

Notable descendant naming includes dungeon portal, ruins, resource nodes/fields, citadel/tower/monolith structures and authored hub objects. The hierarchy index is the preservation record; it is not yet runtime acceptance.

## Integration order

### M0 — preservation

- [x] Fingerprint incoming place.
- [x] Inventory classes/scripts/world hierarchy.
- [x] Identify duplicate vs unique script source by hash/path.
- [x] Create pre-merge Git checkpoint.
- [x] Store unique incoming source in inert import namespace.
- [x] Store complete Workspace hierarchy index.

### M1 — safe preparation/hub bridge

- [ ] Extract vendor/daily-deal/rarity-upgrade mechanics into canonical config/resolver shapes.
- [ ] Integrate only through current lobby/preparation lifecycle.
- [ ] Define authoritative transaction and inventory mutation boundary.
- [ ] Add tests before activation.

### M2 — quest reconciliation

- [ ] Extract quest archetypes/modifiers into shared config.
- [ ] Ensure quest progress derives from authoritative current events, never client claims.
- [ ] Define expedition-session vs account-persistent quest ownership.
- [ ] Add deterministic tests.

### M3 — dungeon enrichment

- [ ] Map old dungeon room/modifier/encounter ideas onto current `RoomSequenceAssembler`, placement, encounter, elite, boss, secret-branch and reward systems.
- [ ] Do not create a second dungeon runtime.

### M4 — authored world promotion

- [ ] Reconstruct selected Studio geometry/properties into source-managed world assets/builders.
- [ ] Start with HubTown + portal + highest-value landmarks.
- [ ] Preserve current operation world until the replacement passes Studio evidence.

### M5 — optional scope

- [ ] Evaluate gathering/hatchet/crafting against repeat-session evidence.
- [ ] Evaluate monetization only after core loop and ownership/persistence gates pass.

## Promotion rule

Preservation completion is not runtime completion. The repository remains at its existing evidence level until Studio evidence verifies each ported capability. No old service becomes authoritative merely because its source is preserved here.
