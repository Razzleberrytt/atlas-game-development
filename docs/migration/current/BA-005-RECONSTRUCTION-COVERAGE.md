# BA-005 — Authored-World Reconstruction Coverage

**Status:** CURRENT EVIDENCE BOUNDARY  
**Runtime activation:** No  
**Coordinate space:** `authored-overworld`

## Current recoverable set

Current committed evidence supports the already-held reconstructions for:

- `Workspace/WorldPath` → `RecoveredWorldPathConfig`;
- `Workspace/HubTown/DungeonPortal` → `RecoveredDungeonPortalConfig`;
- `Workspace/HubTown/quest_board` → `RecoveredQuestBoardConfig`;
- `Workspace/SpawnLocation` → `RecoveredSpawnLocationConfig`.

These are preservation contracts, not permission to boot the imported world.

## Current evidence ceiling

The repaired preservation bundle proves all 1,775 Workspace identities/hierarchy rows. The property decoder independently verified 1,699 supported-property rows, but the full 1,546,379-byte property artifact is not committed; only its SHA-256 and a compact selected-instance summary are reviewable on `main`.

That selected summary is insufficient to reconstruct complete `Workspace/Resources` or `Workspace/WorldStructures` groups: it contains only selected Iron Ore and structure children. Presentation evidence likewise does not contain complete atmosphere groups.

A checksum-verified diagnostic of the recovered source bundle (closed PR #291, intentionally unmerged) confirmed that the recovered resource gameplay source consumes already-existing `Workspace/Resources` nodes. It does not author their geometry or placement. Randomness in that source concerns harvest yield, so it cannot substitute for the missing authored transforms.

Therefore no new Resources, WorldStructures, AmbientFireflies, or WorldClouds geometry may be promoted from current committed evidence.

## Resume conditions

BA-005 geometry reconstruction may resume for a new coherent group only when at least one of these is true:

1. the checksum-pinned full property artifact is made reviewably available; or
2. the canonical place source is re-extracted for the target group's complete supported properties.

After evidence expansion, validate one coherent group, keep it dormant, and merge it before choosing another group.

`AuthoredWorldRecoveryCoverageConfig` is the fail-closed source contract for this boundary. Broad hierarchy/property coverage must never be interpreted as evidence for properties that are not reviewably present for the selected group.
