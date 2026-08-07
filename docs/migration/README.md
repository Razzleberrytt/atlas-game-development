# Combined-Game Migration Manifests

Machine-readable migration truth for the preserved 2026-08-07 Studio place.
These manifests are the P0 deliverables of the build-ahead lane described in
`../roadmap/AGENT-BUILD-AHEAD-QUEUE.md`.

They are **inert data**. Nothing here is mapped by `default.project.json`, read
by runtime code, or evidence of Studio behavior. They exist so that when the
v2.7 runtime gates open, integration is a review of prepared decisions rather
than an archaeology exercise.

## Files

| File | Task | Scope |
|---|---|---|
| `hubtown-migration-manifest.json` | BA-001 | `Workspace/HubTown` and the legacy hub service |
| `HUBTOWN-MIGRATION-MANIFEST.md` | BA-001 | Human-readable view of the same data |

## Evidence base

Every legacy reference resolves to preserved import material:

- instance rows — `games/living-kingdoms/imports/studio-2026-08-07/recovered/workspace-index-recovered.json`
- script identity — `games/living-kingdoms/imports/studio-2026-08-07/manifest.json`

The preservation archives are damaged; only part of the place survives in the
repository. Read `../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md` before
treating any absence here as an absence in the real place.

## Dispositions

| Value | Meaning |
|---|---|
| `KEEP` | Legacy representation is already correct for the canonical architecture. |
| `MIGRATE` | Authored value worth reconstructing as source-managed canonical content. |
| `REPLACE` | Overlaps an existing canonical owner; reproduce the intent through that owner. |
| `ARCHIVE` | Reference only. Never boot, require, or map into the active project. |

`extraction_status` is separate from disposition. `recovered` means the row's
identity is proven from the repository; `requires_studio_extraction` means the
identity is proven but the contents beneath it were lost and must come from the
source place.

## Validation

```bash
python scripts/validate_migration_manifests.py
```

CI runs this on every change. It fails when an entry references a Workspace path
or instance id that was never recovered, a script that is not in the import
manifest, a canonical owner module that does not exist, an unknown build-ahead
task, a dependency cycle, or when a manifest with a declared `path_scope` leaves
a recovered row unclaimed or claims one twice.

That last rule is what makes a manifest trustworthy: the HubTown manifest cannot
silently omit content, because every recovered `Workspace/HubTown` row must be
claimed by exactly one entry.

## Rules these manifests follow

- Do not create a second authority path. Where a canonical owner exists, the
  disposition is `REPLACE` and the owner is named by file path.
- Do not invent asset ids, place ids, or product ids. Missing assets are
  recorded as open gaps.
- Do not infer content that was lost. An unrecovered subtree is
  `requires_studio_extraction`, never a guess.
- Keep runtime activation out. Every entry carries a `runtime_gate`, and none of
  them is open today.
