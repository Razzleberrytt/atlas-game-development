# Living Kingdoms — reconciled Studio place intake (2026-08-10)

## Source identity

- Incoming file: `livingkingdoms.rbxl`
- Type: Roblox binary place (`.rbxl`)
- Size: `1,808,699` bytes
- SHA-256: `7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b`
- RBXL version field: `0`
- Declared classes: `98`
- Declared instances: `2,342`
- Received: 2026-08-10
- Purpose: reconcile the user-supplied Studio version with the latest source-first Living Kingdoms repository without discarding either authored world work or newer repo runtime work.

The binary itself is not committed. The pre-intake repository state was checkpointed at `backup/living-kingdoms-pre-import-2026-08-10`.

## Inventory summary

The supplied place contains:

- `1,775` Workspace instances;
- `367` embedded scripts (`344` ModuleScripts, `16` Scripts, `7` LocalScripts);
- `20` RemoteEvents;
- authored HubTown content including `CentralFountain`, `GrandStaircase`, `HubArchway`, `DungeonPortal`, and related civic/world structures.

The historical 2026-08-07 import (`e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`) also recorded `1,775` Workspace instances with the same aggregate Workspace class distribution, but only `2,258` declared instances and `290` scripts. The new revision therefore has `+84` declared instances and `+77` scripts while preserving aggregate Workspace population/class counts. This supports the interpretation that Studio retained the authored world while additional repository/runtime material was synced into the place. It does not prove property-by-property equivalence with the historical binary.

## Reconciliation decision

Use a best-of-both merge:

1. **Latest repository source wins for overlapping runtime authority.** Do not replace current combat, enemy, inventory, persistence, expedition, networking, presentation, or bootstrapping code with embedded place copies.
2. **The supplied place is a checksum-pinned authored-world source revision.** Exact bounded world evidence may be promoted into source-managed held reconstruction contracts.
3. **Legacy overlapping RPG authority stays inert.** Do not wholesale activate the old `RPGServerBootstrap`, `CombatService`, `EnemyService`, `InventoryService`, `LootService`, `PlayerDataService`, or monetization bootstrap from the place.
4. **No binary/build artifact becomes canonical source.** The `.rbxl` remains evidence/provenance; Rojo/source files remain canonical.

## Material admitted in this intake

`Workspace/HubTown/CentralFountain` was admitted first as a bounded coherent civic unit and merged through PR #371:

- held reconstruction module: `games/living-kingdoms/src/shared/Config/RecoveredCentralFountainConfig.luau`;
- evidence: `games/living-kingdoms/imports/studio-2026-08-10/central-fountain.review.json`;
- semantic ownership: `main_world.hub_core.central_fountain` / `main_world.hub_core`;
- runtime remains disabled and source-held.

Additional exact supported geometry/light evidence is preserved at `games/living-kingdoms/imports/studio-2026-08-10/hub-civic-geometry-summary.json` for:

- `Workspace/HubTown/GrandStaircase` — 35 instances;
- `Workspace/HubTown/HubArchway` — 6 instances;
- `Workspace/HubTown/DungeonPortal` — 10 instances, to be used as current-revision parity/supplemental evidence for the already-held portal contract rather than creating duplicate gameplay authority.

These additional groups are preserved but intentionally not promoted in the same change. Future work should continue one coherent group at a time with property-parity regression coverage.

## Source preservation record

The import directory also contains `revision-manifest.json`, which records the source fingerprint, inventory, historical comparison, and authority policy. The 2026-08-07 preservation bundle remains intact for unique legacy RPG concepts/source and historical authored-world provenance.

## Validation boundary

PR #371 completed Atlas validation successfully before merge. This follow-up intake is inert import/documentation evidence only: it does not alter `default.project.json`, live runtime source, network schema, persistence schema, or operation-place mapping.

Studio runtime evidence is not claimed for this documentation-only preservation pass. Any later model asset or Main World mapping must satisfy the existing Main World creation/activation gates before becoming playable.
