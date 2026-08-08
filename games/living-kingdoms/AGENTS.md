# Living Kingdoms Agent Guide

This file applies to everything under `games/living-kingdoms`.

Living Kingdoms is developed repository-first. Coding agents should be able to inspect, modify, test, and review most gameplay work without opening Roblox Studio.

## Active production authority

Before selecting implementation work, read:

1. `../../docs/roadmap/MASTER-ROADMAP.md`
2. `../../docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md`
3. `../../docs/roadmap/PRODUCTION-CORE-V2.7.md`
4. `../../docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`
5. `../../docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` when the user/maintainer wants useful work to continue while a Studio-only v2.7 runtime gate is still pending.
6. `../../docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md` when the change touches player-facing replicated or presentation state.

Blueprint v2.7 is the active **runtime** execution authority. Historical v1.9/v2.0/v2.3 queues are provenance, not task selection. Accepted runtime evidence and current Roblox platform behavior outrank authored roadmap prose.

The active runtime queue is Tickets 331–360. Do not skip its stop conditions to activate persistence, broad visual expansion, networking cutovers, or deferred gameplay integration.

The controlled build-ahead queue is a separate preparation lane. It allows agents to prepare migration manifests, pure contracts, content schemas, validation tooling, tests, and isolated/dormant gameplay branches while runtime evidence is pending. It does **not** authorize early runtime activation or false evidence promotion.

Roadmap adoption does not prove the active Studio incidents are fixed. Preserve E1 unless a captured Studio evidence packet justifies promotion.

## Build-ahead branch rules

When working from `AGENT-BUILD-AHEAD-QUEUE.md`:

- fetch current `main` before selecting the task;
- check related open PRs to avoid duplicate work;
- prefer one task or tightly coupled task group per branch;
- use `[BUILD-AHEAD]` or `[BUILD-AHEAD/BLOCKED]` in the PR title;
- keep future runtime wiring separate from preparatory modules/data;
- do not merge or activate PR #221/#222 ahead of their documented gates;
- do not implement/activate R3 semantic suppression before R2 evidence;
- do not boot preserved legacy gameplay services alongside canonical services;
- keep source-proven facts separate from Studio-only facts;
- leave gameplay-prep PRs draft/blocked when their runtime activation gate is not yet open.

Docs, tooling, source audits, pure validators and migration inventories that do not change active runtime behavior may be independently reviewable. Runtime-affecting gameplay preparation should remain isolated until its promotion gate is accepted.

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

## Agent completion checklist

- [ ] Read the active roadmap documents and, when applicable, the build-ahead queue.
- [ ] Re-fetched current `main` and checked for overlapping open PRs.
- [ ] Preserved client/server authority boundaries.
- [ ] Kept preparatory work separate from gated runtime activation.
- [ ] Added or updated focused tests.
- [ ] Ran layout, formatting, lint, fixture, and Rojo build checks.
- [ ] Documented any Studio-only validation.
- [ ] Avoided committing generated place files or secrets.
- [ ] Updated the applicable roadmap/build-ahead task status when appropriate.
- [ ] Summarized changed behavior and remaining risks.
