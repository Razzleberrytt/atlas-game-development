# Studio RBXL Import — Preservation Integrity Finding

**Date:** 2026-08-07
**Scope:** `games/living-kingdoms/imports/studio-2026-08-07`
**Evidence level:** source-proven only. Nothing here is Studio/runtime evidence and nothing here changes active-place behavior.
**Raised by:** build-ahead queue Lane B, while sourcing BA-001/BA-002/BA-003 from the preserved import.

## Summary

The checked-in import package does not restore. Both chunked base64 archives are
damaged in the committed blobs, so `restore-import.py` fails outright:

| Archive | Declared content | Actually restorable |
|---|---|---|
| `legacy-src.tar.gz.b64.part01…16` | 28 Studio-only Luau sources | 17 files, SHA-256-verified |
| `workspace-index.json.gz.b64.part01…05` | 1,775 Workspace instance rows | 122 rows |

`VALIDATION.md` previously asserted "File SHA-256 / byte-count mismatches: **0**"
and a complete 1,775-instance round trip. That claim is not reproducible from
the repository and has been corrected.

This is a preservation defect, not a gameplay defect. No canonical runtime
system reads the import package, and `default.project.json` does not map it.

## What was measured

Reproduce with:

```bash
python scripts/verify_studio_import_package.py
```

### `legacy-src.tar.gz.b64.part*`

- Concatenated base64 length is **86,771** characters. A well-formed encoding of
  this archive is 86,772 characters (`4 × ceil(65,079 / 3)`), and chunk sizes
  (`5,424 × 15 + 5,412`) confirm 86,772 was intended.
- `part09` is 5,423 characters where every other full chunk is 5,424, so at
  least one base64 character was dropped inside that chunk.
- The gzip member inflates cleanly well past that point and yields 17 members
  whose bytes and SHA-256 match `manifest.json` exactly. The stream then
  desynchronizes and the remaining 11 members are lost.

### `workspace-index.json.gz.b64.part*`

- Concatenated base64 length is **24,456** characters, which is exactly the
  correct length for the 18,342-byte gzip member. No characters are missing.
- Inflation produces well-formed JSON for the header and the first 122 instance
  rows, then desynchronizes; the gzip CRC-32 and `ISIZE` trailer both mismatch.

### Repair attempts (exhausted)

| Attempt | Space searched | Result |
|---|---|---|
| Single-character insertion into `legacy-src` `part09` | 5,424 positions × 64 alphabet characters | no repair |
| Single-character substitution across `workspace-index` | 24,456 positions × 63 alternatives | no repair |
| Chunk reordering for `workspace-index` | all 120 permutations | no repair |
| Alternate branches (`integration/rbxl-merge-2026-08-07`, `archive/pre-rbxl-merge-2026-08-07`) | full blob comparison | byte-identical damaged blobs |

A single-bit flip in the compressed stream is a subset of the substitution
sweep, so both archives carry **more than one** corrupted character. Without the
original bytes there is no redundancy left to reconstruct them from, so the
remaining loss is not recoverable inside this repository.

The most likely cause is transcription loss when the chunk files were authored,
not Git: `.gitattributes` normalizes line endings only, the working tree matches
the committed blobs byte for byte, and the damaged blobs are identical on every
branch that carries them.

## What was preserved instead

Recovery is no longer trapped behind a fragile archive. The verified material is
now stored as plain, reviewable text under `imports/studio-2026-08-07/recovered/`:

- `recovered/legacy-src/**` — the 17 byte-exact Studio-only sources, each still
  checked against its `manifest.json` SHA-256 on every CI run.
- `recovered/workspace-index-recovered.json` — the 122 recoverable Workspace
  rows with explicit completeness bounds.

`INTEGRITY-BASELINE.json` pins the current recovery level.
`scripts/verify_studio_import_package.py` fails when a chunk file changes
without review, when a previously verified file stops verifying, or when the
recoverable row count drops. It never rewrites the baseline implicitly.

## What the recovered Workspace rows do and do not cover

The original extractor emitted rows breadth-first by depth and ascending path
within each depth, and that ordering is preserved. Because the truncation lands
inside depth 2 at `Workspace/WorldPath/PathSegment_12`, completeness is knowable
rather than guessed:

| Subtree | Depth-2 completeness | Deeper levels |
|---|---|---|
| `Workspace` roots (12 + `Workspace`) | complete | n/a |
| `Workspace/HubTown` | **complete** (81 rows) | lost |
| `Workspace/Resources` | complete (3 group folders) | lost |
| `Workspace/Buildings` | complete (folder is empty in the place) | n/a |
| `Workspace/AmbientFireflies`, `Workspace/WorldClouds` | complete | n/a |
| `Workspace/WorldPath` | truncated at `PathSegment_12` | lost |
| `Workspace/WorldStructures` | **absent** | lost |

No depth-3 row survives, so shop interiors, dungeon-portal parts, fountain and
archway internals, resource-node instances and every authored structure under
`WorldStructures` are unavailable from the repository.

## Required action outside this repository

Full fidelity needs a re-extraction from the source place. It cannot be produced
by any repository-side tool.

1. Locate `livingkingdoms.rbxl`, SHA-256
   `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`
   (1,639,392 bytes). Confirm the hash before extracting; a different hash is a
   different place and must be recorded as a new import.
2. Re-export the 11 lost sources listed in `INTEGRITY-BASELINE.json` under
   `archives.legacy-src.unrecoverable_files`.
3. Re-export the full 1,775-row Workspace hierarchy index.
4. Commit the results as plain text under `recovered/`, not as base64 chunks,
   then run `python scripts/verify_studio_import_package.py --update-baseline`
   and review the baseline diff.

Follow `RBXL-IMPORT-MIGRATION.md` for the surrounding procedure. Until step 4
lands, any manifest built from this import must mark the affected rows
`REQUIRES_STUDIO_EXTRACTION` rather than inferring content.

## Impact on the build-ahead queue

- **BA-001** is deliverable. The HubTown depth-2 composition is complete and
  verifiable; only sub-folder interiors are gated.
- **BA-002** is partially blocked. `WorldStructures` has no surviving rows, so
  the authored-world manifest can cover roots, resources and the path corridor
  but must defer structure-level detail to Studio re-extraction.
- **BA-003** is deliverable. Every one of the 28 manifested scripts can still be
  classified; 11 are classified from `manifest.json` identity plus the readable
  reference layer rather than from recovered source, and that provenance is
  recorded per row.

## Mirrored copies worth knowing about

Two of the 11 lost sources survive as normalized, non-byte-exact copies in
`imports/studio-2026-08-07/readable-reference/`: `HubTownService.luau` and
`QuestService.luau`. They are readable references, not preservation-grade
copies, and their hashes intentionally do not match `manifest.json`.
`GATHERING-CRAFTING-CONCEPTS.md` similarly retains the design content of the
lost `SurvivalGatheringService.server.luau`.

`DungeonService.luau` also has a readable-reference copy, but it was recovered
byte-exact as well, so `recovered/legacy-src/` is authoritative for it.
