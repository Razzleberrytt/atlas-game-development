# BA-005 — Recovered Main World Spawn Location

**Status:** PROPERTY-BACKED / DORMANT  
**Runtime activation:** No  
**Canonical content ID:** `spawn.main_world.arrival`  
**Source path:** `Workspace/SpawnLocation`

## Purpose

This slice preserves the Studio-authored Main World arrival marker as an exact, source-managed reconstruction contract without activating it in the current game runtime.

The source instance is independently pinned to the canonical `livingkingdoms.rbxl` SHA-256:

`e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`

The committed BA-005 property evidence identifies source ID `117` as a `SpawnLocation` at `(0, 7, 30)` with size `(6, 1, 6)`. The reconstruction preserves its decoded supported properties, including material/color, collision flags, `Enabled`, `Neutral`, and team color.

## Ownership boundary

`RecoveredSpawnLocationConfig` is evidence only. It does **not**:

- create a live SpawnLocation;
- move or teleport a player;
- replace the current operation insertion spawn;
- activate the authored Main World;
- decide overworld lifecycle or return behavior;
- make the imported Studio hierarchy authoritative at runtime.

The existing `WorldContentConfig` descriptor `spawn.main_world.arrival` remains inactive until a dedicated Main World lifecycle is accepted. `RecoveredWorldPlacementConfig` keeps this path in the separate `authored-overworld` coordinate space with absolute coordinates preserved at 1:1 scale.

## Evidence

Generation/validation sources:

- `docs/migration/current/reextracted-property-evidence.json`
- `docs/migration/current/reextracted-property-evidence-manifest.json`
- `scripts/validate_reextracted_property_evidence.py`

The evidence manifest pins the uncommitted full decoder output by byte count and SHA-256; the committed summary retains this SpawnLocation as a positive selected instance with its supported properties. The property-evidence validator independently verifies the canonical source place identity and decoded Workspace coverage.

## Validation

`games/living-kingdoms/tests/RecoveredSpawnLocationConfig.test.luau` locks:

- canonical content ID and source path;
- canonical source RBXL SHA and source ID;
- exact position, rotation ID, size, material, color, shape and visibility values;
- collision/query/touch/shadow, enabled, neutral and team-color values;
- dormant/no-authority ownership flags;
- the existing inactive Main World arrival descriptor;
- placement in the separate authored-overworld coordinate space.

Studio/manual verification is not required for this dormant evidence-preservation slice. Runtime spawn acceptance remains part of a later dedicated Main World lifecycle / consolidated Studio pass.
