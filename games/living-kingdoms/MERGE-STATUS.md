# Living Kingdoms Merge Status

**Current merge:** original Studio `livingkingdoms.rbxl` + canonical Atlas/Living Kingdoms Rojo source  
**Import date:** 2026-08-07  
**Current main milestone:** preservation repaired, canonical ownership clarified, forward-operations hub shell integrated  
**Runtime evidence posture:** repository/CI proven; full Studio multiplayer acceptance is still outstanding

## Read this first

This file is the current human-facing merge status.

Older migration documents that say only **122 / 1,775** Workspace rows survived describe the damaged first archive. They are historical planning evidence, not the current preservation state.

Current repaired evidence lives in:

- `../../docs/migration/REEXTRACTED-WORLD-EVIDENCE.md`
- `../../docs/migration/current/reextracted-world-evidence.json`
- `imports/studio-2026-08-07/reextracted/`

## Canonical rule

`games/living-kingdoms/src/` is the only gameplay-authoritative source tree.

The Studio import is preservation and migration input. It must never become a second combat, persistence, inventory, loot, enemy, mission, networking, monetization, or expedition authority.

Do **not** boot the imported `RPGServerBootstrap`, `CombatService`, `EnemyService`, `InventoryService`, `LootService`, `PlayerDataService`, or `MonetizationService` beside the modern runtime.

## Preservation status

The original uploaded RBXL is intact and has been re-extracted directly.

Verified facts:

- source RBXL: `1,639,392` bytes
- source SHA-256: `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`
- Studio-only sources: **28 / 28** preserved exactly
- Workspace identity/hierarchy: **1,775 / 1,775** rows preserved
- Workspace index SHA-256: `320d1ec49b0bc3a0feaed7fdc07348a18ebc248682bddc1a338514c82421b6c3`

The preservation verifier now checks the repaired set rather than treating the damaged first archive as the recovery ceiling.

## Recovered world scale

Current identity/hierarchy evidence proves:

- `Workspace/WorldStructures` — **1,190 rows** across 17 named top-level authored groups
- `Workspace/HubTown` — **270 rows** across 46 immediate child paths
- `Workspace/WorldPath` — **190 rows**, including contiguous `PathSegment_1` through `PathSegment_189`
- `Workspace/Resources` — **113 rows** (`Trees`, `Rocks`, `IronOre`)

This is identity/hierarchy evidence only. Property-perfect geometry has **not** yet been recovered into source definitions.

## What is live now

### Modern runtime

The modern source tree remains authoritative for:

- combat and weapons
- enemies and encounter direction
- operative life / revive / failure
- missions and results
- inventory, loot, survival resources and persistence boundaries
- class selection and class actions
- run progression and build state
- expedition lobby/runtime/lifecycle
- world foundation and operation landmarks

### Forward Operations Hub

PR **#230** added a source-managed preparation shell at the current Ranger Station/insertion area.

It provides three physical access points:

1. Specialist Assignment
2. Armory Rack
3. Expedition Terminal

These stations only reveal existing modern UI/services. They do not own gameplay state.

The existing `C` / `I` / `K` RPG character, inventory and skills menu remains canonical and is advertised on the hub field board instead of being duplicated.

The archived Studio `HubTown` remains **preserved and inactive**. The live Forward Operations Hub is a safe bridge, not a claim that the old authored town has already been reconstructed.

## Current validation

PR #230 head `de3485e389f46f51b13534f21858a018574206ea` passed Luau validation run **#834** (`31234335708`), including:

- repository contract validation
- complete Studio preservation verification
- migration-manifest validation
- StyLua
- Selene
- all discovered Lune fixtures
- Rojo build
- reproducible build artifact upload

PR #230 merged to `main` as `d09d6affb8c67809d01de3e5341222c28a1e1834`.

## What is not complete

Do not describe the games as fully fused yet.

Still open:

- property-backed reconstruction of the imported authored world
- true separate town/preparation lifecycle versus always-started operation runtime
- authored Studio HubTown visual parity
- quest-board integration into canonical mission contracts
- dungeon portal/modifier integration into canonical expedition runtime
- gathering/crafting through canonical inventory/persistence transaction boundaries
- vendor/economy integration through canonical owners
- legacy UI concept harvesting where it improves current presentation
- Studio runtime / multiplayer evidence for the combined build
- any unresolved historical v2.7 runtime-evidence packet remains an evidence concern; it does not authorize bypassing runtime validation

## Next highest-ROI task

**BA-005 — deterministic authored-world reconstruction, behind the source hold.**

Use two phases:

1. **Identity phase:** generate deterministic source-managed hierarchy/content definitions from the complete 1,775-row re-extraction and stable world-content IDs. No guessed transforms or materials.
2. **Property phase:** extend the RBXL extractor to recover supported part/light/VFX properties, generate property-backed definitions, and add parity assertions before activation.

The old 122-row BA-001/BA-002 manifests may still be validated as historical artifacts, but BA-005 planning must use the post-repair evidence files named above.

## Recovery

- untouched pre-RBXL-merge repository: `archive/pre-rbxl-merge-2026-08-07` at `852de4953155379a4cc4733fe8dd05cd6f51477e`
- repaired preservation merge: PR #228
- canonical-runtime/world-ID cleanup: PR #229
- Forward Operations Hub shell: PR #230
