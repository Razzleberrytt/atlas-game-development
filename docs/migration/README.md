# Combined-Game Migration Evidence

This directory contains two generations of migration evidence for the 2026-08-07 Studio place. **Do not mix them up.**

## Current post-repair evidence

Use these files for new reconstruction work:

- `REEXTRACTED-WORLD-EVIDENCE.md`
- `current/reextracted-world-evidence.json`

They summarize the direct re-extraction from the original `livingkingdoms.rbxl` after PR #228 repaired the preservation failure.

Current verified facts:

- **28 / 28** Studio-only source files preserved exactly
- **1,775 / 1,775** Workspace identity/hierarchy rows preserved
- `Workspace/HubTown` — 270 rows
- `Workspace/WorldStructures` — 1,190 rows
- `Workspace/WorldPath` — 190 rows, including contiguous `PathSegment_1` through `PathSegment_189`
- `Workspace/Resources` — 113 rows

This evidence proves identity and hierarchy. It does **not** yet prove CFrame, size, material, color, terrain voxel, mesh, light, particle, fire, or other property parity.

## Historical damaged-archive manifests

The following manifests were produced **before** the repair, when only 122 Workspace rows were available in the first damaged preservation archive:

| File | Task | Historical scope |
|---|---|---|
| `hubtown-migration-manifest.json` | BA-001 | partial recovered HubTown rows from the damaged archive |
| `HUBTOWN-MIGRATION-MANIFEST.md` | BA-001 | human-readable view of that historical data |
| `authored-world-migration-manifest.json` | BA-002 | partial recovered non-HubTown rows from the damaged archive |
| `AUTHORED-WORLD-MIGRATION-MANIFEST.md` | BA-002 | human-readable view of that historical data |
| `legacy-script-disposition-matrix.json` | BA-003 | classification of the 28 Studio-only scripts |
| `LEGACY-SCRIPT-DISPOSITION-MATRIX.md` | BA-003 | human-readable script disposition |
| `combined-game-integration-graph.json` | BA-070 | prepared dependency graph |
| `COMBINED-GAME-INTEGRATION-GRAPH.md` | BA-070 | human-readable graph |

The BA-001/BA-002 row counts and “missing subtree” conclusions are **superseded for current planning**. They remain in the repository because they record the original preservation failure and the decisions made against that evidence.

Do not cite these historical statements as current facts:

- only 122 / 1,775 Workspace rows survived
- HubTown has only 81 recoverable rows
- WorldStructures has no recoverable children
- WorldPath ends after PathSegment_12
- 1,653 Workspace rows still require re-extraction

PR #228 invalidated those missing-row conclusions by re-extracting the intact original RBXL.

## Canonical ownership rule

Migration evidence is inert. It never authorizes a second runtime authority.

When old and new systems overlap:

- keep the current source-managed owner
- migrate authored content, rules, presentation, or data into that owner
- never boot both implementations

The imported legacy combat, enemy, inventory, persistence, loot, monetization, quest, dungeon, gathering and RPG bootstrap services remain reference material unless explicitly adapted through current contracts.

## Validation

Three boundary checks keep current preservation truth separate from historical
manifest provenance:

```bash
python scripts/verify_studio_import_package.py
python scripts/validate_migration_manifests.py
python scripts/validate_migration_current_evidence.py
```

`verify_studio_import_package.py` validates the **current repaired preservation set**: all 28 sources and all 1,775 Workspace rows.

`validate_migration_manifests.py` still validates the older BA-001/BA-002 manifest generation against the frozen damaged-archive index they were authored from. A green result means those historical manifests are internally consistent; it does **not** mean their 122-row evidence base is the latest preservation truth.

`validate_migration_current_evidence.py` validates every required JSON under
`docs/migration/current/` against the canonical RBXL identity, the 28/28 source
baseline and the 1,775/1,775 Workspace baseline. It also requires the explicit
supersession marker and checks the human-readable evidence summary's counts.

The current machine-readable evidence lives under `docs/migration/current/` specifically so the historical manifest validator cannot mistake it for one of the old manifest schemas.

## Next use

BA-005 reconstruction must continue to consume the post-repair evidence in two
phases:

1. deterministic identity/hierarchy reconstruction behind the source hold
2. supported property extraction and property-backed parity assertions

Do not invent geometry or properties to fill gaps between those phases.
