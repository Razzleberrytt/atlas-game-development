# Studio Main World Import — 2026-08-11

This import preserves the dedicated Studio Main World place as reviewable source without replacing canonical runtime code.

## Source

- File: `livingkingdoms-mainWorld.rbxl`
- SHA-256: `e71ff34b2075e2da2314fc4c156b4ae1b1f0f20c42b82c517c2a4b9a7e3e43e1`
- Bytes: 3772509
- RBXL header: 81 classes, 1369 declared instances
- Preserved subtree: `Workspace/LivingKingdomsMainWorld`
- Preserved subtree instances: 884

## Merge disposition

The 35 authored top-level groups under `assets/recovered-world/models/main-world-studio-2026-08-11/` are the source-managed representation of the complete Main World subtree. Thirty are tracked directly as `.model.json`; the five oversized groups (`Castle`, `Zones`, `HubCore`, `Forest`, `NPCs`) are tracked losslessly as deterministic gzip payloads and materialized byte-for-byte before validation/build. Existing repository runtime scripts remain authoritative for overlapping paths. The four Studio-only presentation scripts are preserved under `scripts/` for review but are intentionally not wired into the runtime.

No existing recovered-world files are deleted by this import. `scripts/roblox/materialize_main_world_studio_snapshot.py` verifies the compressed payload hashes and restores the five generated `.model.json` files before the unified validator runs. The Main World Rojo project maps all 35 authored groups beneath `LivingKingdomsMainWorld`, while canonical `MainWorldServer` and `MainWorldClient` remain repo-owned.

## Review holds

- 199 MeshParts are saved with `Anchored = false`; this import preserves that authored state rather than silently changing physics.
- 8 object-reference properties are recorded in `reference-evidence.json` rather than guessed by the converter.
- `AmbientAnimation` compounds a sway rotation from the current pivot every Heartbeat; it should be corrected before any future activation.

## Preserved Studio-only scripts

- `AmbientAnimation` — `ServerScriptService/AmbientAnimation` (preserved, inactive)
- `NPCAnimation` — `ServerScriptService/NPCAnimation` (preserved, inactive)
- `DarkAtmosphere` — `ServerScriptService/DarkAtmosphere` (preserved, inactive)
- `ZoneAmbient` — `ServerScriptService/ZoneAmbient` (preserved, inactive)

## Materialization

Run `python scripts/validate.py fast` (or `full`) as usual. The unified validator materializes and hash-verifies the five compressed source groups before any checks or Rojo builds. The generated model files are gitignored; the gzip payloads plus manifest hashes are the durable source of truth.
