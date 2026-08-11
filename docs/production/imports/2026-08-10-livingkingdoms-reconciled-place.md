# Living Kingdoms — reconciled Studio place intake (2026-08-10)

## Source identity

- Incoming file: `livingkingdoms.rbxl`
- Type: Roblox binary place (`.rbxl`)
- Size: `1,808,699` bytes
- SHA-256: `7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b`
- RBXL version field: `0`
- Declared classes: `98`
- Declared instances: `2,342`
- Workspace instances: `1,775`
- Embedded scripts: `367` (`344` ModuleScripts, `16` Scripts, `7` LocalScripts)
- Received: 2026-08-10

The binary itself is not committed. The pre-intake repository state remains preserved on the backup branch created before reconciliation.

## Final reconciliation decision

The 2026-08-10 place and current repository are now reconciled under a best-of-both authority boundary:

1. **Current GitHub/Rojo source remains authoritative for gameplay/runtime.** Combat, enemies, inventory, loot, persistence, expedition, networking, presentation, monetization, and bootstrap ownership stay with current `games/living-kingdoms/src` code.
2. **The incoming RBXL is a checksum-pinned authored-world source revision.** Useful exact world evidence is preserved as inert review artifacts and held reconstruction contracts.
3. **Overlapping legacy runtime is quarantined.** `RPGServerBootstrap`, the old monetization bootstrap, and overlapping Combat/Enemy/Inventory/Loot/PlayerData services are not mapped by the active Rojo project and cannot become a second gameplay authority through this import.
4. **Unique historical source remains preserved.** Script reconciliation confirmed all but one of the 28 historically unique legacy sources are present in the new place; the missing `RNGConfig.luau` remains preserved in the 2026-08-07 archive.
5. **No binary/build artifact becomes canonical source.** The active project maps repository `src` paths, not this import directory or the incoming `.rbxl`.

The explicit quarantine record is `games/living-kingdoms/imports/studio-2026-08-10/legacy-runtime-quarantine.json`.

## Authored-world material admitted

The useful bounded current-revision civic evidence has been exhausted without guessing missing properties:

- **Central Fountain — PR #371:** exact 11-instance checksum-pinned held reconstruction with parity coverage.
- **Grand Staircase — PR #377:** exact 35-instance held reconstruction covering corrected 80-stud steps, rails, lanterns, collision/material data, and lights.
- **Hub Archway — PR #379:** exact 6-instance held reconstruction covering pillars, beam, crystal, and light.
- **Dungeon Portal — PR #380:** current-revision parity record confirms the already-held portal's supported geometry, lights, attachment, and identity graph. The richer historical UI/particle properties remain preserved rather than being overwritten by the narrower current summary.

`Workspace/WorldPath`, the held quest board, and the held arrival/spawn contract remain valid historical reconstruction inputs. Other Resources, WorldStructures, atmosphere, Terrain, NPC/vendor/quest, and asset-specific details do not have enough complete current-revision property evidence committed to justify additional promotion. They remain partial/hierarchy evidence rather than fabricated source truth.

## Script reconciliation

The current place contains 367 embedded scripts versus 290 in the historical 2026-08-07 place. The reconciliation does **not** treat that increase as permission to import an alternate runtime. Current repository source wins wherever responsibilities overlap.

The historical archive remains the preservation source for unique legacy concepts and for the one historically unique source absent from the current place: `ReplicatedStorage/Shared/Config/RNGConfig.luau`.

## Validation and completion boundary

The source reconciliation is **complete** when this closeout is merged:

- source fingerprint and inventory are pinned;
- useful current civic evidence is admitted or parity-recorded;
- overlapping embedded runtime is explicitly quarantined;
- unique historical source is preserved;
- current GitHub/Rojo authority remains unambiguous;
- remaining incomplete property evidence is truthfully classified rather than guessed.

Ordinary Studio/device/play/streaming/performance verification remains **pending** and must not be called VERIFIED until run. Under the build-through testing policy, that pending manual evidence does not hold source development hostage.

The next source-development work should therefore return to normal Patch 0.5 Main World progression using the admitted held evidence and existing creation/activation gates, rather than continuing a generic RBXL gap chase.
