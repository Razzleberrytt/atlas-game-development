# Living Kingdoms Agent Guide

This file applies to everything under `games/living-kingdoms`.

Living Kingdoms is developed repository-first. Coding agents should be able to inspect, modify, test, and review most gameplay work without opening Roblox Studio.

## Active production authority

Before selecting implementation work, read:

1. `../../docs/bible/00-current-product-authority.md`
2. `../../docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md`
3. `../../docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`
4. `../../docs/roadmap/MASTER-ROADMAP.md`
5. `../../docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md`
6. `../../docs/roadmap/PRODUCTION-CORE-V2.7.md`
7. `../../docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`
8. `../../docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` for prepared work, dependency context, and useful repository tasks when Studio-only runtime verification is pending.
9. `../../docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md` when the change touches player-facing replicated or presentation state.

`MVP-BUILD-THROUGH-TESTING-POLICY.md` is the current execution-cadence and roadmap-status authority. `PLAYABLE-MVP-PATCH-EXECUTION.md` supplies the preferred player-facing milestone order. Blueprint v2.7 remains the active **runtime safety/stabilization** authority. Historical v1.9/v2.0/v2.3 queues are provenance, not task selection. Accepted runtime evidence and current Roblox platform behavior outrank authored roadmap prose.

Do not bypass concrete v2.7 safety boundaries involving server authority, current-state ownership, rollback integrity, lifecycle correctness, or evidence that downstream runtime work genuinely depends on. Merely belonging to a later roadmap phase is not a blocker.

## Build-through and milestone verification

Do not require a human Studio playtest after every intermediate implementation task, merge, patch fragment, or version label. Run all applicable automated/static validation, keep changes diagnosable and reversible, and continue through useful dependency-safe work until a coherent player-facing milestone is ready to evaluate.

Use these meanings when reporting roadmap work:

- **NOT STARTED** — no meaningful implementation exists yet.
- **BUILDING** — implementation is active or partial.
- **BUILT — VERIFICATION PENDING** — implementation exists and applicable source/static checks pass, but required Studio/device/integration/human evidence is still open.
- **VERIFIED** — applicable acceptance evidence passed.
- **DEFERRED** — lower priority for now; not prohibited merely by phase order.
- **BLOCKED** — work cannot safely or correctly proceed because of a named dependency, safety issue, broken owner/interface, or evidence boundary.
- **HISTORICAL** — provenance only.

The distinction between **BUILT — VERIFICATION PENDING** and **VERIFIED** is mandatory. Never erase completed source work merely because runtime evidence is pending, and never promote untested work to verified.

Earlier Studio/runtime evidence is still mandatory when a narrow exception applies: data-loss or irreversible persistence risk, consequential security/authority changes, an active v2.7 safety gate, engine-only behavior that later work cannot safely depend on without runtime proof, or another concrete blocker that makes continued implementation unsafe or misleading.

At a coherent player-facing milestone, stop broad expansion long enough to run the applicable Studio/playtest/debug/replay pass. Fix integration defects and mark the milestone **VERIFIED** only when its required evidence passes. Then continue building.

## Build-ahead and later-phase work

`AGENT-BUILD-AHEAD-QUEUE.md` is useful prepared-work and dependency context. Its historical `READY`, `PREPARED`, `BLOCKED`, and lock language does not override the current Build-Through status policy.

Later-phase work may be implemented when it is dependency-safe and one of these is true:

- it directly advances the current playable milestone;
- it removes a real blocker or expensive near-term dependency;
- it creates a reusable canonical owner/interface required by near-term work;
- it is a small isolated improvement with clear value and low integration risk.

Avoid broad speculative expansion with no near-term payoff. Prefer visible playable progress and real dependency reduction.

Roadmap adoption does not prove Studio behavior. Preserve the actual evidence level until a captured Studio/device/runtime packet justifies promotion.

## Build-ahead branch rules

When working from `AGENT-BUILD-AHEAD-QUEUE.md` or another later-phase roadmap area:

- fetch current `main` before selecting the task;
- check related open PRs to avoid duplicate work;
- prefer one task or tightly coupled task group per branch;
- keep risky runtime cutovers separate from preparatory modules/data when rollback or evidence requires that separation;
- do not implement/activate R3 semantic suppression before R2 when the current runtime design genuinely depends on that ordering;
- do not boot preserved legacy gameplay services alongside canonical services;
- keep source-proven facts separate from Studio-only facts;
- use **BUILT — VERIFICATION PENDING** when source work is complete but runtime acceptance remains open;
- use **BLOCKED** only when the concrete blocking reason is named.

Docs, tooling, source audits, pure validators, migration inventories, content/data work, and isolated gameplay improvements may be independently reviewable when they preserve canonical ownership and do not create an unsafe activation path.

## Canonical layout

```text
games/living-kingdoms/
├── default.project.json  # Rojo DataModel mapping
├── src/
│   ├── client/           # Local input, camera, HUD, audio, presentation
│   ├── server/           # Authoritative runtime systems and domain logic
│   └── shared/           # Contracts, configuration, and pure shared modules
├── tests/                # Lune fixtures and source audits
├── assets/               # Asset manifests and source material
└── README.md
```

Rojo maps:

- `src/client` to `StarterPlayer/StarterPlayerScripts/Client`;
- `src/server` to `ServerScriptService/Server`;
- `src/shared` to `ReplicatedStorage/Shared`.

Do not change those destinations casually. Any mapping change requires a migration note, build validation, and a Studio smoke test.

## Architecture boundaries

### Client

Client code may own:

- local input collection;
- camera behavior;
- HUD and menu rendering;
- audio and visual presentation;
- non-authoritative prediction or interpolation;
- sending narrowly scoped intent messages.

Client code must not establish consequential game truth.

### Server

Server code owns:

- combat resolution and target legality;
- enemy state and spawning;
- health, incapacitation, revival, and death;
- loot, rewards, progression, classes, and run builds;
- mission and operation lifecycle;
- validation of client intent;
- persistence and monetization when added.

Remote handlers must validate identity, state, range, cadence, permissions, and payload shape as applicable. Rate-limit or otherwise bound repeatable intents.

### Shared

Shared modules should contain:

- stable contracts and type declarations;
- configuration values;
- deterministic resolvers that can be tested through Lune;
- presentation-safe data structures intentionally disclosed to clients.

Avoid coupling pure shared modules to live Roblox services unless the module is explicitly an integration boundary.

## Coding conventions

- Use strict Luau for new source files.
- Follow the existing lifecycle pattern where controllers and services expose appropriate `init`, `start`, `stop`, or `destroy` behavior.
- Make repeated lifecycle calls safe when the surrounding architecture expects them to be safe.
- Keep functions deterministic when they can be deterministic.
- Return copied state from pure resolvers instead of mutating caller-owned inputs.
- Prefer explicit reason IDs and contracts over free-form hidden coupling.
- Reuse existing network folders and contracts when suitable; do not create duplicate remotes for the same authority boundary.
- Keep configuration centralized under `src/shared/Config` rather than scattering balance constants through runtime code.
- Preserve accessibility and mobile behavior when changing controls or presentation.

## Testing expectations

A gameplay rule change should normally include a focused `*.test.luau` fixture. Integration changes should include either an integration fixture or a source audit that proves the intended wiring and security boundary.

Run from repository root:

```bash
python scripts/validate_living_kingdoms_layout.py
python scripts/verify_studio_import_package.py
python scripts/validate_migration_manifests.py
python scripts/validate_roadmap_authority.py

stylua --check \
  games/living-kingdoms/src \
  games/living-kingdoms/tests \
  games/living-kingdoms/tools
selene games/living-kingdoms/src

find games/living-kingdoms/tests -type f -name '*.test.luau' -print0 \
  | sort -z \
  | xargs -0 -n1 lune run

rojo build games/living-kingdoms/default.project.json \
  --output /tmp/LivingKingdoms.rbxlx
```

StyLua covers `src`, `tests` and `tools` — format new fixtures and tooling, not
just runtime source. Selene remains scoped to `src`: it downloads the Roblox API
dump from `setup.rbxcdn.com`, which some sandboxes block, so it is a CI-only
check there. Extending Selene to `tests` and `tools` is unfinished work; do it
from an environment that can actually run it.

Do not delete or loosen an existing test because a new implementation fails it unless the underlying documented requirement has intentionally changed.

Passing applicable automated/static validation permits the next dependency-safe task to continue when no narrow early-runtime exception applies. Static tests do not prove Studio behavior; record unresolved Studio/device/integration checks as **BUILT — VERIFICATION PENDING** and group them into the next coherent milestone acceptance pass when safe.

## Working with a newer Roblox place

A `.rbxl` or `.rbxlx` file is an import source, not an automatic replacement for this directory.

Before reconciling one:

1. Preserve the current Git commit with a backup branch or tag.
2. Record the incoming file name, byte size, SHA-256 hash, and origin.
3. Inventory scripts, services, remotes, non-script instances, terrain, assets, and settings in the place.
4. Diff extracted script sources against this repository.
5. Merge intentional changes into `src/client`, `src/server`, and `src/shared` according to authority boundaries.
6. Represent stable instance structure in `default.project.json` or dedicated `.rbxmx` model files only when reviewable and appropriate.
7. Record everything that remains Studio-owned.
8. Run all repository validation.
9. Perform a Studio smoke test before publishing.

Never overwrite the repository with extracted place contents without review. Place files may contain stale copies of scripts, generated instances, plugin artifacts, or Studio-only state.

See `../../docs/production/RBXL-IMPORT-MIGRATION.md` for the full migration procedure.

## Studio-only checks

Flag these clearly rather than pretending they were validated by CI:

- actual multiplayer play behavior;
- character and physics behavior;
- terrain and authored map appearance;
- animations and asset ownership permissions;
- lighting and audio in the live engine;
- UI across device safe areas;
- streaming and network ownership behavior;
- DataStore behavior in an appropriate test environment;
- performance and memory;
- publishing configuration.

The existence of a Studio-only check does not by itself create a hard manual gate. Defer it to the next coherent milestone pass unless the Build-Through policy's early-runtime exception applies. Work awaiting that evidence should be labeled **BUILT — VERIFICATION PENDING**, not reverted to not-started or falsely marked verified.

## Agent completion checklist

- [ ] Read the active roadmap documents and the Build-Through + Milestone Verification policy.
- [ ] Re-fetched current `main` and checked for overlapping open PRs.
- [ ] Identified the current playable milestone and the highest-ROI useful task.
- [ ] Preserved client/server authority boundaries.
- [ ] Kept dangerous runtime migrations separable where rollback/evidence requires it.
- [ ] Added or updated focused tests.
- [ ] Ran layout, formatting, lint, fixture, roadmap-authority, and Rojo build checks as applicable.
- [ ] Labeled implementation truthfully as building, built-verification-pending, verified, deferred, or concretely blocked.
- [ ] Documented Studio-only validation as completed, required early, or pending for the next coherent milestone pass.
- [ ] Avoided committing generated place files or secrets.
- [ ] Updated the applicable roadmap/build-ahead task status when appropriate.
- [ ] Summarized changed behavior, current verification status, and remaining risks.