# Roblox Place Import and Reconciliation

This procedure reconciles a newer Roblox Studio place (`.rbxl` or `.rbxlx`) with the GitHub-first Living Kingdoms project.

The repository remains canonical for Luau source, configuration, tests, documentation, and reproducible Rojo builds. An incoming place is **runtime evidence and an import source**, not permission to blindly replace repository source.

**Current rollout authority:**

- `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md`
- `docs/roadmap/PRODUCTION-CORE-V2.7.md`
- `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`
- `docs/production/V2.7-CUTOVER-LEDGER.md`

If the incoming place contains behavior relevant to the active v2.7 incidents, update the cutover ledger from observed/source evidence rather than guessing.

## Why reconciliation is required

A Roblox place can contain several categories of state:

1. Script source that belongs in Git.
2. Reviewable instance structure representable by Rojo mappings or model files.
3. Uploaded asset references such as meshes, images, audio, and animations.
4. Visual authoring such as terrain, map layout, lighting, and effects.
5. Runtime-generated or plugin/editor state that should not become canonical source.
6. Stale copies of scripts older than the repository implementation.
7. Place-only producers, listeners, remotes, Highlights, or presentation objects not represented in current Git source.

Treating these categories as interchangeable can delete tested systems, reintroduce stale code, hide an insecure authority path, or erase the very runtime evidence needed to close the v2.7 rollout.

## Safety branches and rollback identity

Before processing an incoming place, preserve the current default branch:

```text
backup/living-kingdoms-pre-import-YYYY-MM-DD
```

Perform reconciliation on a separate branch:

```text
migration/living-kingdoms-place-YYYY-MM-DD
```

Record the exact pre-import commit SHA. Never force-update or delete the backup branch as part of the import.

If the import is used during an R0–R5 rollout stage, also record the known-good rollback place/build/configuration.

## Intake record

Record before extraction:

- original file name;
- format (`rbxl` or `rbxlx`);
- byte size;
- SHA-256 hash;
- date received;
- source or author;
- known purpose of the newer version;
- associated Git commit/branch if known;
- whether the place opens successfully in Roblox Studio;
- Roblox Studio version;
- whether unpublished or permission-restricted assets are present;
- whether the place demonstrates any active v2.7 queue/Highlight symptom;
- current rollout feature-flag configuration if applicable.

Do not commit the incoming binary place to ordinary source directories. Store it outside the repository or in a deliberately managed archival location.

## Inventory before merging

Create an inventory grouped by Roblox service and category.

### Script inventory

Capture every `Script`, `LocalScript`, and `ModuleScript` with:

- full DataModel path;
- class;
- enabled/disabled state;
- run context where applicable;
- source hash;
- corresponding repository path, if one exists;
- whether it creates or connects a RemoteEvent;
- whether it creates a `Highlight` or other long-lived presentation primitive;
- likely lifecycle scope: application, character, operation, or unknown.

### Network and service inventory

Capture:

- RemoteEvents and RemoteFunctions;
- BindableEvents and BindableFunctions;
- all `HordeNetwork.State` producers (`FireClient`, `FireAllClients`, wrappers, and indirect publisher paths);
- all effective `HordeNetwork.State.OnClientEvent` listeners;
- when each listener is created relative to the first server publish;
- whether listeners/producers are recreated on reset or respawn;
- service-level settings affecting runtime behavior;
- CollectionService tags and attributes used by code;
- collision groups;
- spawn locations;
- important folders or named runtime anchors.

For every state producer/consumer discovered, update `docs/production/V2.7-CUTOVER-LEDGER.md` or explicitly record why the row is outside the active rollout.

### Current-state semantics inventory

For each independent current fact carried by the legacy state path, record:

```text
legacy call site
runtime domain
mechanical owner
semantic key candidate
mutation/change-token source
payload fields
current send rate if measured
whether the value must survive delayed readiness / late join
```

Do not collapse independent facts into one row merely because they share a physical RemoteEvent.

### Highlight and presentation inventory

Capture every runtime `Highlight` producer and observed instance with:

- creating script/controller;
- parent;
- `Adornee`;
- `DepthMode`;
- fill/outline settings;
- semantic purpose/channel;
- lifecycle owner;
- cleanup trigger;
- whether the target is broad (`Workspace`, world root, biome root, whole character when a narrow target was intended);
- behavior on stream-out and stream-in.

Also inventory route, landmark, objective, status/mark, camera, viewmodel, animation-marker, and temporary-VFX owners when relevant to the import.

### Visual and asset inventory

Capture:

- terrain;
- map models and authored geometry;
- lighting and atmosphere;
- particle, beam, trail, sound, and post-processing instances;
- animations and asset IDs;
- mesh, image, texture, and audio references;
- UI instances not generated by code.

## Script reconciliation

Classify each incoming script:

- **Identical:** source hash and intended path match; no action.
- **Repository newer:** keep repository source and document the stale place copy.
- **Place newer:** port the intentional change into the correct repository module and add tests.
- **Parallel implementation:** compare behavior and architecture; merge deliberately rather than choosing by timestamp alone.
- **Unmapped:** decide whether it belongs in client, server, shared, a development harness, or should be discarded.
- **Runtime-only compatibility path:** preserve long enough to measure/migrate it, but do not silently canonize it as permanent architecture.

Do not preserve an insecure authority boundary merely because it exists in the newer place. Client-originated combat, rewards, inventory, progression, health, persistence, or other consequential truth must remain behind server validation.

Do not remove a legacy state/listener/presentation path merely because a replacement exists in Git. Compatibility removal follows the v2.7 ledger-row gate and requires accepted replacement evidence plus a rollback checkpoint.

## Destination rules

- Local input, camera, HUD, audio, and visual presentation belong under `src/client`.
- Consequential runtime truth belongs under `src/server`.
- Contracts, configuration, semantic IDs, and deterministic resolvers belong under `src/shared` where appropriate.
- Focused fixtures and source audits belong under `tests`.
- Stable reviewable DataModel structure belongs in `default.project.json` or a deliberately tracked model representation.
- Large authored maps, terrain, and engine-edited visual state may remain Studio-owned, but their ownership and required anchors must be documented.
- Migration-only diagnostics must have an owner and removal/production-disable rule.

## Reconciliation manifest

Create a manifest for each import under:

```text
docs/production/imports/YYYY-MM-DD-<short-name>.md
```

The manifest must contain:

- intake metadata and SHA-256;
- pre-import Git/rollback identity;
- script comparison summary;
- files added, changed, retained, or rejected;
- network/authority changes;
- `HordeNetwork.State` producer and listener discoveries;
- semantic current-state discoveries;
- Highlight/presentation ownership discoveries;
- cutover-ledger rows added or changed;
- instance structure represented in Git;
- Studio-owned content retained outside Git;
- asset/permission risks;
- feature flags introduced/changed;
- repository validation results;
- Studio evidence packet links;
- publishing status.

## Required repository validation

Run from repository root:

```bash
python scripts/validate_living_kingdoms_layout.py
stylua --check games/living-kingdoms/src
selene games/living-kingdoms/src

find games/living-kingdoms/tests -type f -name '*.test.luau' -print0 \
  | sort -z \
  | xargs -0 -n1 lune run

rojo build games/living-kingdoms/default.project.json \
  --output /tmp/LivingKingdoms.rbxlx
```

The Rojo build proves repository source can produce a place file. It does not prove engine behavior, assets, terrain, lifecycle correctness, queue health, presentation ownership, performance, or publishing configuration.

## Required Studio verification

Before merging an import intended to become playable or publishable, verify at minimum:

1. The Rojo-built place opens without project-mapping errors.
2. Server/client bootstraps start without blocking runtime errors.
3. Build/commit/place identity is recorded.
4. Current `HordeNetwork.State` producer/listener counts and any queue warnings are recorded.
5. Runtime Highlights and their owners/Adornees are inventoried.
6. A local solo smoke test reaches the intended supported loop.
7. A multiplayer test confirms remotes, authority, replication, and respawn behavior where applicable.
8. Character movement, camera, combat, enemies, objectives, failure/result, and current presentation behave as expected for the imported scope.
9. Reset/respawn cleanup is checked when lifecycle-sensitive code changed.
10. UI is checked on desktop and representative mobile safe areas when UI changed.
11. Required meshes, images, audio, and animations load for the publishing owner/group.
12. Terrain, lighting, collisions, streaming, and spawn locations are visually inspected.
13. Performance/memory/network behavior is sampled when the import changes representative runtime load.
14. Publishing targets the correct universe/place.

For a run used to close a v2.7 runtime gate, create an evidence packet from `docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md`. A generic “Studio smoke test passed” note is not sufficient for promotion or incident closure.

## v2.7 active-place acceptance additions

When the import participates in the active rollout, run the matrices applicable to the changed stage:

- delayed-ready / ClientReady reconstruction;
- five-reset gauge comparison;
- three-respawn gauge comparison;
- late join;
- stream-out/rebind;
- two-player reset/disconnect;
- 100 animation plays for marker-lifetime changes;
- ten-minute network/presentation soak before incident closure.

A warning disappearing is not enough. The intended listener count, semantic send rate, connection gauges, Highlight leases, and cleanup behavior must match the accepted evidence.

## Completion standard

An import is complete only when:

- intentional script changes are represented and reviewed in Git;
- repository validation passes;
- all remaining Studio-owned content is inventoried;
- place-only runtime producers/listeners/presentation owners are either reconciled or explicitly recorded;
- cutover ledger changes are accurate;
- required Studio evidence is recorded at the correct level;
- no unperformed runtime gate is represented as passed;
- the backup/rollback point remains available;
- the migration branch or pull request clearly states whether publishing occurred.

> Import the facts, not the assumptions. Reconcile source deliberately, measure runtime ownership, and preserve the rollback road until the replacement is proven.
