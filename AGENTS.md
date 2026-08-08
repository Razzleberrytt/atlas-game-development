# Agent Operating Contract

This repository is designed for GitHub-first development by humans and coding agents. The repository is the source of truth for gameplay code, configuration, tests, technical documentation, and reproducible builds.

## Primary project

The active Roblox game is `games/living-kingdoms`.

Read these files before changing it:

1. `games/living-kingdoms/AGENTS.md`
2. `games/living-kingdoms/README.md`
3. `docs/bible/00-project-charter.md`
4. `docs/bible/01-mvp.md`
5. `docs/architecture/technical-blueprint.md`
6. `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` (active authority)
7. `docs/roadmap/PRODUCTION-CORE-V2.7.md`
8. `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md` when touching runtime state, remotes, presentation, lifecycle, Studio migration, or incident closure
9. `docs/production/V2.7-CUTOVER-LEDGER.md` for producer/consumer/presentation migration work
10. `docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md` before any Studio/runtime run intended to close a gate or promote evidence level

More specific `AGENTS.md` files override this file for their directory scope.

## Current roadmap rule

Blueprint v2.7 controls execution order. Implement the lowest-numbered incomplete v2.7 ticket that can honestly be completed in the current environment.

Accepted runtime evidence and current Roblox platform behavior outrank roadmap prose. Older v2.3/v2.0/v1.9 roadmap files are historical provenance, not current instructions.

Do not claim an E2–E5 result from source inspection alone. The current active-place queue/highlight incidents remain open until the v2.7 closure evidence is recorded.

## Source-of-truth rules

- Treat `games/living-kingdoms/src` as canonical for Luau source.
- Treat `games/living-kingdoms/default.project.json` as canonical for the Rojo DataModel mapping.
- Treat `games/living-kingdoms/tests` as required regression coverage.
- Do not edit generated `.rbxl`, `.rbxlx`, sourcemap, or build-output files as source code.
- Do not import a Roblox place by blindly replacing the existing `src` tree.
- Preserve server authority for combat, progression, persistence, rewards, inventory, health, enemy state, and other consequential gameplay.
- Never trust client-provided positions, timestamps, damage, targets, cooldown completion, currency, inventory, or progression state without server validation.
- Do not create a second authoritative state/presentation path when the v2.7 task is to migrate or observe the existing one.

## Runtime-state and presentation rules

When touching current-state delivery or active-place presentation:

- inventory existing producers and consumers before adding another path;
- record affected rows in `docs/production/V2.7-CUTOVER-LEDGER.md`;
- bind required current-state listeners before declaring the client ready;
- identify independent current facts with semantic keys;
- suppress unchanged state using a mutation-derived revision/change token;
- retain pre-ready current state by player + remote + semantic key where retention is required;
- route production Highlights through the shared presentation owner/registry rather than allocating competing Highlights;
- keep application, character, and operation/round connection scopes explicit;
- preserve semantic truth across streaming even when a local Instance is temporarily absent;
- capture before/after rates and cleanup gauges for migration work;
- create a new evidence packet for evidence-bearing Studio/runtime runs instead of editing an older packet to fit a later result.

## Required validation

From the repository root, install the pinned tools in `rokit.toml`, then run:

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

StyLua covers `src`, `tests` and `tools`. Selene is scoped to `src` only; it
needs the Roblox API dump, which some sandboxes cannot reach.

A change is not complete merely because it compiles. Update or add focused tests for behavior changes and document any Roblox-engine behavior that cannot be validated outside Studio.

For v2.7 runtime migration tickets, static tests do not replace required Studio evidence such as listener timing, reset/respawn baselines, queue warnings, streaming rebind, multiplayer disconnect behavior, or profiling captures.

## Change discipline

- Make the smallest coherent change that completes the task.
- Preserve existing architecture unless the task explicitly requires a migration.
- Prefer pure modules for rules and calculations; keep Roblox service integration at clear runtime boundaries.
- Keep client, server, and shared responsibilities separated.
- Do not invent asset IDs, animation IDs, product IDs, place IDs, universe IDs, or secrets.
- Do not commit credentials, cookies, tokens, local Studio settings, or generated build artifacts.
- Do not weaken tests or remove security checks to make CI pass.
- Update relevant documentation when changing architecture, setup, controls, data contracts, rollout flags, runtime state semantics, or the Studio boundary.
- Compatibility/feature flags introduced for migration require an owner, rollback trigger, evidence gate, and removal condition.
- Compatibility removal must update the cutover ledger and retain the required rollback checkpoint.

## Roblox Studio boundary

Routine code development should happen through GitHub, agents, local editors, Rojo, Lune, Selene, StyLua, and CI. Roblox Studio is still required for engine-level playtesting, visual world authoring, terrain, animation authoring, asset permissions, certain instance properties, device emulation, performance profiling, streaming behavior, active network timing, and publishing.

Follow `docs/production/RBXL-IMPORT-MIGRATION.md` whenever a newer `.rbxl` or `.rbxlx` place must be reconciled with repository source.

For the current rollout, follow `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`, update `docs/production/V2.7-CUTOVER-LEDGER.md`, and preserve the named rollback/build checkpoint before each architectural stage change.

For any Studio/runtime run used as acceptance evidence, create a packet from `docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md` and record the exact build/commit/place identity.

## Completion report

When finishing a task, report:

- v2.7 ticket number and rollout stage;
- files changed;
- behavior changed;
- validation performed and exact results;
- cutover ledger rows changed;
- before/after runtime counters where applicable;
- evidence packet or Studio-only checks still required;
- rollback checkpoint/flag state for migration work;
- risks, assumptions, or follow-up work.
