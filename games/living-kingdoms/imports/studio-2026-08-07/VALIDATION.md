# Import Package Validation

**Validated:** 2026-08-07  
**Scope:** deterministic preservation package only; not Roblox Studio runtime evidence

The checked-in import artifacts were assembled locally with `restore-import.py` and verified against `manifest.json`.

## Results

- Restored Studio-only Luau files: **28**
- Manifested Studio-only files: **28**
- File SHA-256 / byte-count mismatches: **0**
- Restored Workspace hierarchy instances: **1,775**
- Workspace source SHA matches manifest source SHA: **yes**
- Source place SHA-256: `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`

Workspace roots recovered by the hierarchy index include `HubTown`, `Resources`, `WorldPath`, `WorldStructures`, `Terrain`, spawn/bootstrap objects, camera and ambience objects.

## Evidence boundary

This validates that the preservation archive is internally lossless for the 28 unique extracted source files and that the complete 1,775-instance Workspace identity/path hierarchy round-trips from the checked-in chunks. It does **not** prove property-perfect Workspace reconstruction and does not count as E2+ Roblox Studio startup or gameplay evidence.
