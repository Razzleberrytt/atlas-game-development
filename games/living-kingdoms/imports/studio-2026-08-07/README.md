# Studio RBXL Import — 2026-08-07

This directory is the loss-avoidance import package for `livingkingdoms.rbxl` supplied on 2026-08-07.

## Source identity

- File: `livingkingdoms.rbxl`
- Size: 1,639,392 bytes
- SHA-256: `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`
- Binary place instances: 2,258
- Scripts/modules: 290
- Workspace instances: 1,775

The original binary cannot be safely treated as source-of-truth over the tested Rojo tree. The import therefore preserves the material that is unique to the Studio place while leaving the newer repo implementation authoritative where the two overlap.

## What is preserved here

1. **Every unique old-RPG source file** that is not already represented by the current repo: 28 files in the lossless `legacy-src.tar.gz.b64.part01` … `part16` bundle (restored to `legacy-src/` with `restore-import.py`).
2. **Every Workspace instance identity and hierarchy path** from the supplied place in `workspace-index.json` (restored from `workspace-index.json.gz.b64.part01` … `part05` by `restore-import.py`) (1,775 entries), including the authored hub, dungeon portal, resources, landmarks/ruins, lighting objects, NPC structures, and other world content.
3. A complete **script reconciliation manifest** in `manifest.json`, including source hashes and whether the canonical repo or preserved legacy copy owns each script after the import.
4. The exact source-file fingerprint above, so later conversion/recovery can prove it is operating on the same Studio place.

## Merge rule

**Current repo wins for overlapping runtime responsibilities.** In particular, the current server-authoritative combat, enemy, operative life, inventory, persistence, expedition, reward, networking, and presentation systems remain the live implementation.

The preserved legacy layer is intentionally **not mapped by `default.project.json`**, so copying it into the repository cannot accidentally start a second combat engine or data layer.

### Never boot these unchanged

The following are preserved because they contain useful ideas/code, but they overlap current authority and must be reconciled before activation:

- `RPGServerBootstrap`
- `Services/CombatService`
- `Services/EnemyService`
- `Services/InventoryService`
- `Services/LootService`
- `Services/PlayerDataService`
- `MonetizationService`

The legacy RPG bootstrap also references dependencies that were not present in the supplied place (`AbilityDefinitions`, `HubTownConfig`, `HubTownContracts`), another reason it must not become the active bootstrap unchanged.

## Best-of-both targets

The highest-value unique pieces to adapt into the canonical architecture are:

- authored **HubTown** as a preparation/social/meta layer;
- rotating vendor/daily-deal and rarity-upgrade concepts from `HubTownService`;
- quest modifiers and short-session quest generation from `QuestService`;
- resource gathering/hatchet/crafting concepts from `SurvivalGatheringService` (feature-gated until they fit scope);
- old dungeon modifier/encounter ideas folded into the newer `Expedition*` room/sequence systems;
- useful RPG/shop HUD layout ideas, while keeping the current centralized presentation owners;
- world landmarks such as the dungeon portal, resource fields, ruins, citadel/tower/monolith structures and ambience.

## World note

`workspace-index.json (restored from `workspace-index.json.gz.b64.part01` … `part05` by `restore-import.py`)` is a hierarchy-preservation artifact, not a claim of property-perfect reconstruction. The supplied world is valuable authored content and should be promoted into an active source-managed world only after its geometry/properties have been reconstructed and tested against the current operation runtime. Until then, the exact source hash and complete object hierarchy prevent the import from becoming an undocumented black box.

## Recovery

The untouched repository state immediately before this import is permanently checkpointed at:

`archive/pre-rbxl-merge-2026-08-07`

This directory is additive and inert by design. It can be removed from an active build without deleting the original pre-merge Git history.
