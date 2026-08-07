# Import Package Validation

**Original validation:** 2026-08-07
**Corrected:** 2026-08-07 after the archives were re-checked from the committed blobs
**Scope:** deterministic preservation package only; not Roblox Studio runtime evidence

## Correction notice

An earlier revision of this file reported a lossless package: 28 of 28 restored
sources, zero SHA-256 mismatches, and a complete 1,775-instance Workspace round
trip. **That result is not reproducible from this repository.** Both chunked
base64 archives are damaged in the committed blobs and `restore-import.py` fails
before producing any output.

The finding, the measurements, the exhausted repair attempts and the required
Studio re-extraction steps are recorded in
`../../../../docs/production/RBXL-IMPORT-INTEGRITY-2026-08-07.md`.

## Current results

Reproduce with `python scripts/verify_studio_import_package.py` from the
repository root.

- Manifested Studio-only files: **28**
- Restorable and SHA-256-verified: **17**
- Unrecoverable from this repository: **11**
- Declared Workspace hierarchy instances: **1,775**
- Recoverable Workspace instance rows: **122**
- `legacy-src` archive restores completely: **no**
- `workspace-index` archive restores completely: **no**
- Source place SHA-256 recorded by the manifest:
  `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`

Workspace roots are fully recovered and include `HubTown`, `Resources`,
`WorldPath`, `WorldStructures`, `Buildings`, `Terrain`, spawn/bootstrap objects,
camera and ambience objects. Below the roots, `Workspace/HubTown` is complete at
depth 2 (81 rows), `Workspace/WorldPath` is truncated, `Workspace/WorldStructures`
has no surviving rows, and no depth-3 row survives anywhere.

## Where the verified material lives

`recovered/` holds the proven material as plain text:

- `recovered/legacy-src/**` — the 17 byte-exact sources
- `recovered/workspace-index-recovered.json` — the 122 surviving rows

`INTEGRITY-BASELINE.json` pins this recovery level so a future change cannot
quietly lose more of it.

## Evidence boundary

This records how much of the preservation archive is still provable and pins it
against further loss. It does **not** prove property-perfect Workspace
reconstruction, does not restore the 11 lost sources, and does not count as E2+
Roblox Studio startup or gameplay evidence.
