# Re-extracted World Evidence — Current Planning Truth

This document records the **post-repair** Workspace identity/hierarchy evidence recovered directly from the original `livingkingdoms.rbxl`.

It supersedes the damaged first archive **for current migration planning**. The older 122-row recovered index and BA-001/BA-002 manifests remain useful as historical records of the first failed preservation pass, but their missing-row conclusions are no longer current facts.

## Verified source

- Source RBXL SHA-256: `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`
- Source RBXL bytes: `1,639,392`
- Re-extracted Workspace rows: **1,775 / 1,775**
- Workspace index bytes: `278,542`
- Workspace index SHA-256: `320d1ec49b0bc3a0feaed7fdc07348a18ebc248682bddc1a338514c82421b6c3`
- CI preservation verifier: **28 / 28 Studio-only sources + 1,775 Workspace rows**

Machine-readable summary: [`current/reextracted-world-evidence.json`](current/reextracted-world-evidence.json).

## What is actually present

| Top-level subtree | Verified rows |
|---|---:|
| `Workspace/WorldStructures` | **1,190** |
| `Workspace/HubTown` | **270** |
| `Workspace/WorldPath` | **190** |
| `Workspace/Resources` | **113** |
| `Workspace/AmbientFireflies` | 3 |
| `Workspace/WorldClouds` | 2 |
| `Workspace/Buildings` | 1 |
| `Workspace/Terrain` | 1 |
| `Workspace/SpawnLocation` | 1 |
| `Workspace/BootstrapSafetyFloor` | 1 |
| `Workspace/BootstrapSafetySpawn` | 1 |
| `Workspace/Camera` | 1 |

Together with the Workspace root, these account for all **1,775** rows.

## Authored world structures

`Workspace/WorldStructures` is not empty. It contains **1,190 rows** across 17 named top-level groups:

- `AncientBridge` — 36 rows
- `CrystalTower` — 32
- `DarkCitadel` — 31
- `DarkMist` — 11
- `DestinyMonolith` — 25
- `EnergyBeams` — 7
- `FalloutRuins` — 122
- `FloatingDebris` — 16
- `FloatingIslands` — 42
- `GlowingCracks` — 25
- `GrandEntrance` — 10
- `MagicalAtmosphere` — 37
- `MountainBeacons` — 25
- `MountainRanges` — 98
- `SkyElements` — 10
- `WorldDetails` — 201
- `WorldVegetation` — 461

Class scale inside this subtree: 894 `Part`, 175 `Model`, 79 `PointLight`, 25 `ParticleEmitter`, 8 `Fire`, 7 `Attachment`, plus the folder and one `Shirt` instance.

This is now valid identity/hierarchy evidence for BA-005 planning. It is **not** enough for property-perfect reconstruction by itself.

## HubTown

`Workspace/HubTown` contains **270 rows** and 46 unique immediate child paths.

Verified examples include:

- `DungeonPortal` — 10 rows
- `quest_board` — 16
- `apothecary` — 20
- `armor_smith` — 20
- `weapon_smith` — 20
- `merchant` — 15
- `CentralFountain` — 11
- `GrandStaircase` — 35
- `HubArchway` — 6

The subtree also contains four `Humanoid`, one `ProximityPrompt`, multiple UI instances, lights, fire, particles and welds. That confirms the imported hub was substantially authored rather than a placeholder folder.

The live game still uses the modern source-managed **Forward Operations Hub** shell. The legacy HubTown remains a migration source, not a second runtime authority.

## WorldPath

`Workspace/WorldPath` contains one folder plus **189 contiguous `PathSegment_1` through `PathSegment_189` parts**.

The earlier claim that the path ended at `PathSegment_12` was an artifact of the damaged first archive and is superseded.

The canonical target should still be route/control-point data rather than 189 loose path parts, but BA-005 can now use the complete legacy identity sequence as reconstruction evidence.

## Resources

`Workspace/Resources` contains **113 rows**:

- `Trees` — 46 rows
- `Rocks` — 17
- `IronOre` — 49
- root folder — 1

The subtree includes 62 `Part`, 29 `Model`, 18 `PointLight` and four folders. This confirms that the gathering concepts preserved in legacy scripts correspond to substantial authored world content.

## Important limitation

The current re-extraction proves **identity and hierarchy**. It does not yet claim parity for:

- `CFrame` / position / rotation
- size
- color
- material
- transparency / reflectance
- meshes and asset IDs
- light properties
- particle/fire properties
- Terrain voxels
- Studio streaming/runtime behavior

BA-005 therefore has two safe phases:

1. **Identity reconstruction:** deterministic source-managed hierarchy and stable mapping IDs, behind the source hold.
2. **Property reconstruction:** extend the RBXL extractor to recover supported properties, then generate property-backed source definitions and parity checks.

Do not substitute guessed geometry for missing properties merely because the hierarchy is now complete.

## Superseded planning assumptions

The following statements are historical, not current:

- “only 122 of 1,775 Workspace rows survived”
- “HubTown contains 81 recovered rows”
- “WorldStructures has no recovered children”
- “WorldPath is truncated after PathSegment_12”
- “1,653 Workspace rows require a new Studio extraction”

They describe the damaged first preservation archive. PR #228 repaired that preservation gap from the original RBXL.
