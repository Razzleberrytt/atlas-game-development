# Recovered Import Material

The chunked base64 archives beside this directory are damaged and no longer
restore. Everything that could still be proven byte-exact was extracted here as
plain text so it stops depending on a broken archive.

Full finding and the required Studio re-extraction steps:
`../../../../../docs/production/RBXL-IMPORT-INTEGRITY-2026-08-07.md`.

## Contents

- `legacy-src/**` — 17 Studio-only Luau sources, byte-identical to their
  `../manifest.json` entries. `../.gitattributes` keeps them out of line-ending
  normalization so the SHA-256 checks stay valid.
- `workspace-index-recovered.json` — the 122 Workspace hierarchy rows that
  survive, with explicit completeness bounds.

## Status

- 17 of 28 manifested Studio-only sources recovered; 11 lost.
- 122 of 1,775 Workspace instance rows recovered.
- `Workspace/HubTown` is complete at depth 2 (81 rows). No depth-3 row survives.
- `Workspace/WorldStructures` has no surviving rows at all.

## Authority rule (unchanged)

This directory is inert. Nothing here is mapped by `default.project.json`,
nothing here may be required by live code, and the current `src/` services stay
authoritative wherever responsibilities overlap. The preserved
`RPGServerBootstrap`, `CombatService`, `EnemyService` and `MonetizationService`
copies are archive material with a standing do-not-boot rule; recovering their
bytes does not authorize running them.

## Verification

```bash
python scripts/verify_studio_import_package.py
```

CI runs this on every change. It fails if a chunk file changes without review,
if a previously verified file stops verifying, or if the recoverable row count
drops. Re-extracted material should be committed here as plain text, then
recorded with `--update-baseline` so the baseline diff is reviewable.
