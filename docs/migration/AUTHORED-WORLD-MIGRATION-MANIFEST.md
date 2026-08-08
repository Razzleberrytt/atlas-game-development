# Authored-World Migration Manifest — BA-002

**Task:** BA-002 (build-ahead lane, P0 combined-game migration truth)
**Status:** **PARTIAL.** BA-002 cannot be completed from the repository.
**Machine-readable source of truth:** [`authored-world-migration-manifest.json`](authored-world-migration-manifest.json)
**Evidence level:** source-proven only. No Studio or runtime evidence is claimed.
**Runtime posture:** inert. Nothing is wired, bootstrapped, or activated.

## Why this is partial

BA-002 asks for a manifest covering "structures, ruins, landmarks, resources,
portals, NPC structures, lighting and VFX." Most of that is gone.

`Workspace/WorldStructures` — the folder holding the authored structures, ruins
and landmarks this task is named for — survived as an identity with **not one
child row**. `Workspace/WorldPath` is truncated after `PathSegment_12`. Of 1,775
Workspace instances, 122 survive, and no transform, size, material or colour
survived for any of them. The cause is recorded in
[`../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md`](../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md).

This manifest therefore covers what is provable — all 41 recovered rows outside
HubTown, each claimed exactly once and CI-enforced — and states the rest as
required Studio extraction rather than inferring it.

Portals and NPC structures are not missing from this manifest by oversight: the
only recovered portal is `Workspace/HubTown/DungeonPortal`, which BA-001 owns,
and no NPC structure row survives outside HubTown's vendor folders. The place's
4 `Humanoid` instances are the only evidence that authored NPC bodies existed
anywhere, and their location is unknown.

## The canonical world already exists

This matters more than the losses. `WorldFoundationConfig` declares the world
root, seed, playable extent, insertion position, eight named landmarks — Ranger
Station, Logging Road, Lookout Tower, Campground, Creek Crossing, Rocky
Overlook, Military Roadblock, Extraction Clearing — plus vegetation budgets and
lighting constants. `WorldFoundationService` builds it, including four named
outer routes: North Service Trail, Marsh Boardwalk Route, Southern Fire Road and
Quarry Haul Road.

So the legacy world is a migration *input* into an existing owner, not a
greenfield import. That is why most entries below are `REPLACE`, and it is why
BA-050 and BA-052 are not actually blocked on re-extraction: they can design
against canonical landmarks and routes today.

## Entries

| Entry | Disposition | Rows | Extraction | Canonical owner |
|---|---|---|---|---|
| `world.root` | REPLACE | 1 | recovered | `WorldFoundationConfig.luau`; `WorldFoundationService.luau` |
| `world.structures` | MIGRATE | 1 | **needs Studio** | `WorldFoundationConfig.luau`; `WorldFoundationService.luau`; `WorldMaterialLanguageConfig.luau` |
| `world.buildings` | ARCHIVE | 1 | recovered | none intended (empty folder) |
| `world.terrain` | MIGRATE | 1 | **needs Studio** | `WorldFoundationService.luau` |
| `world.spawn.primary` | REPLACE | 1 | recovered | `default.project.json`; `WorldFoundationConfig.luau` |
| `world.spawn.bootstrap-safety` | KEEP | 2 | recovered | `default.project.json` |
| `world.camera` | ARCHIVE | 1 | recovered | none intended (engine-managed) |
| `world.path.corridor` | REPLACE | 25 | **needs Studio** | `WorldFoundationService.luau`; `WorldFoundationConfig.luau` |
| `world.resources.groups` | MIGRATE | 4 | **needs Studio** | none yet (BA-023) |
| `world.vfx.ambient-fireflies` | REPLACE | 2 | recovered | `VisualAssetConfig.luau`; `VisualAssetContracts.luau`; `PresentationAccessibilityConfig.luau` |
| `world.sky.clouds` | REPLACE | 2 | recovered | `WorldFoundationConfig.luau`; `WorldFoundationService.luau` |

## Findings

**1. `Workspace/Buildings` is provably empty, not truncated.** Recovered rows
sort by path within each depth level, and rows for `Workspace/Camera` survived —
which sorts after any `Workspace/Buildings/…` child would. So the folder really
has no children. Its id (116) sits immediately before `SpawnLocation` (117) and
`HubTown` (118), suggesting it was created with the hub and never filled.

**2. The bootstrap safety pair is a positive control.**
`BootstrapSafetyFloor` and `BootstrapSafetySpawn` are the only `KEEP` here, and
only because they are not legacy content at all — they are declared in
`default.project.json` and appear in the place because the place had been synced
from canonical source. Finding them in the recovered index confirms the index
reflects a place that already carried canonical source, which is useful when
judging what else in the place is legacy versus canonical.

**3. The path corridor should not be migrated as parts.** Contiguous ids
1682–1701 map to `PathSegment_100`–`119` and 1583/1592/1593/1594 map to
`PathSegment_1/10/11/12`, so segments were created in numeric order from id
1583 — implying roughly 119 or more segments existed. `WorldFoundationService`
already expresses routes as ordered control points with clearance-aware
vegetation, which is a strictly better representation than a folder of loose
parts. Target that regardless of what re-extraction finds.

**4. The resource groups cross-confirm the gathering record.** `Trees`, `Rocks`
and `IronOre` are complete at depth 2 and match the three groups documented in
`GATHERING-CRAFTING-CONCEPTS.md` exactly — two independent records agreeing. Id
gaps suggest roughly 45, 16 and 49 instances respectively, but those are
id-range inferences and must not be treated as node counts.

**5. Place-wide class counts cannot be attributed.** The import records 1,305
`Part`, 211 `Model`, 146 `PointLight`, 31 `ParticleEmitter`, 22 `Fire`, 10
`TextLabel`, 4 `BillboardGui`, 4 `Humanoid`, 2 `SurfaceGui` and 1
`ProximityPrompt`, but with 122 of 1,775 rows surviving, none of it can be
assigned to a subtree. Use the counts only as a scale check after re-extraction.

## Open gaps

| Gap | Blocks | Resolution |
|---|---|---|
| `gap.world.structures-lost` | BA-002, BA-050, BA-052 | Re-extract. Meanwhile design against canonical landmarks. |
| `gap.world.path-truncated` | BA-050 | Re-extract, or author the first route directly in canonical route form. |
| `gap.world.no-properties` | BA-002, BA-050, BA-052 | Re-extract with properties, or re-author geometry canonically. |
| `gap.world.class-counts-unattributed` | BA-002 | Scale check only, after re-extraction. |
| `gap.world.unverified-fragments` | — | Hints for the re-extractor only. **Not evidence.** |

### About that last gap

The corrupted region of the workspace-index stream emits fragments that *look*
like real path names — `MountainBeacons/Beacon8`, `OreDeposit_1` under an
`IronOre` path, further `PathSegment` names. They come from a desynchronized
DEFLATE stream and may be reconstructed noise. They are recorded in the JSON
solely so whoever performs the re-extraction knows what to look for. They are
never cited as recovered content and never enter a manifest entry.

## What this unblocks, and what it does not

**Unblocked:** BA-050 (first authored outdoor route) and BA-052 (landmark and
discovery definitions) can proceed against the canonical `WorldFoundationConfig`
landmarks and `WorldFoundationService` routes. The queue lists them as blocked on
BA-002, and this manifest resolves that dependency in the only honest way
available: by establishing that the legacy world contributes almost nothing
recoverable, so the canonical world is the design base.

**Still blocked:** any attempt to reconstruct the legacy authored structures.
BA-002 stays open until re-extraction, and this file should be revised — not
replaced — when that happens.
