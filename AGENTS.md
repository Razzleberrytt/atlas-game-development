# Agent Operating Contract

This repository is designed for GitHub-first development by humans and coding agents. The repository is the source of truth for gameplay code, configuration, tests, technical documentation, and reproducible builds.

## Primary project

The active Roblox game is `games/living-kingdoms`.

Read these files before changing it:

1. `docs/bible/00-current-product-authority.md` — current strategic product authority
2. `docs/roadmap/MASTER-ROADMAP.md` — complete v2.8 dependency-gated product path
3. `games/living-kingdoms/AGENTS.md`
4. `games/living-kingdoms/CANONICAL-RUNTIME.md`
5. `games/living-kingdoms/README.md`
6. `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` — active runtime execution authority
7. `docs/roadmap/PRODUCTION-CORE-V2.7.md`
8. `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` when runtime evidence is blocked or build-ahead work is requested
9. `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md` when touching runtime state, remotes, presentation, lifecycle, Studio migration, or incident closure
10. `docs/production/V2.7-CUTOVER-LEDGER.md` for producer/consumer/presentation migration work
11. `docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md` before any Studio/runtime run intended to close a gate or promote evidence level

`docs/bible/00-project-charter.md` is historical Living Kingdoms product provenance. Read it when historical design context is relevant, but do not use it to override Current Product Authority or Master Roadmap v2.8.

More specific `AGENTS.md` files override this file for their directory scope.

## Current roadmap rule

Two execution lanes exist:

### Runtime lane

Blueprint v2.7 controls current runtime rollout order. Implement only the next dependency-safe v2.7 work whose required evidence can honestly be produced.

The current R1 acceptance run must be re-pinned to a recorded CI artifact at/after client-bootstrap fix `91a1ebe3d04b6d99495f19e7a809bc2b4135fd97`; the older acceptance artifact is invalid because a client-bootstrap stall prevented a trustworthy complete-client R1 capture.

### Build-ahead lane

When runtime evidence is blocked or the task explicitly requests safe preparation, use `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` and select only a task marked `READY` after fetching current `main` and inspecting related open PRs.

A phase appearing in Master Roadmap v2.8 does **not** make it executable. Future phases remain locked unless the active runtime authority or build-ahead queue opens them.

Accepted runtime evidence and current Roblox platform behavior outrank roadmap prose.

## Product-authority rule

- Atlas is currently governed by `docs/bible/00-current-product-authority.md`.
- Existing Living Kingdoms runtime systems are assets to preserve, not disposable prototypes.
- Do not infer a camera/combat rewrite from strategic product language. Camera mode, aiming model, combat presentation, and other foundational runtime behavior change only through an explicit scoped decision/migration with tests and evidence.
- The current world architecture separates the recovered authored overworld from the modern operation forest.
- Intended end state: `authored overworld / HubTown → canonical expedition launch → modern operation runtime → return`.
- The Forward Operations Hub is a temporary preparation bridge, not the final Main World.

## Source-of-truth rules

- Treat `games/living-kingdoms/src` as canonical for Luau source.
- Treat `games/living-kingdoms/default.project.json` as canonical for the Rojo DataModel mapping.
- Treat `games/living-kingdoms/tests` as required regression coverage.
- Treat `games/living-kingdoms/imports` as preservation/reference material, not a second gameplay source tree.
- Do not edit generated `.rbxl`, `.rbxlx`, sourcemap, or build-output files as source code.
- Do not import a Roblox place by blindly replacing the existing `src` tree.
- Preserve server authority for combat, progression, persistence, rewards, inventory, health, enemy state, economy, mission state, and other consequential gameplay.
- Never trust client-provided positions, timestamps, damage, targets, cooldown completion, currency, inventory, progression, rewards, or ownership without server validation.
- Do not create a second authoritative state/presentation path when the task is to migrate, observe, or extend an existing owner.
- Stable IDs and validated content references should bridge recovered/authored content into canonical systems.

## Main World / environment rule

Do not generate broad world geometry before the structured Main World/environment audit has defined what should be kept, refined, rebuilt, replaced, removed, or added.

The target Main World loop is:

```text
Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return
```

Main World work must consider:

- spawn/re-entry flow;
- navigation, traversal pacing and dead travel;
- landmarks/POIs/boundaries;
- terrain/vegetation/props/structures and repetition;
- scale/silhouette/sightlines;
- environmental storytelling;
- lighting/sky/fog/materials/VFX;
- ambient audio/music-zone architecture where applicable;
- streaming, instance cost, collision, replication and mobile/low-graphics performance;
- future NPC/vendor/quest/crafting/gathering/dungeon/social expansion seams.

Visual/environment claims require Studio/gameplay-camera evidence when source inspection cannot prove them.

## Runtime-state and presentation rules

When touching current-state delivery or active-place presentation:

- inventory existing producers and consumers before adding another path;
- record affected rows in `docs/production/V2.7-CUTOVER-LEDGER.md`;
- bind required current-state listeners before declaring the client ready;
- identify independent current facts with semantic keys;
- suppress unchanged state using a mutation-derived revision/change token;
- retain pre-ready current state by player + remote + semantic key where retention is required;
- route production Highlights through the shared presentation owner/registry rather than allocating competing Highlights;
- keep application, character, operation/round and world lifecycle scopes explicit;
- preserve semantic truth across streaming even when a local Instance is temporarily absent;
- capture before/after rates and cleanup gauges for migration work;
- create a new evidence packet for evidence-bearing Studio/runtime runs instead of editing an older packet to fit a later result.

## Content/economy expansion rules

- Prefer reusable engines, pure resolvers, contracts and data/configuration over bespoke feature piles.
- Quests, NPCs, vendors, crafting, gathering, dungeons, items, affixes, routes and discoveries should use stable IDs and reference validation.
- Add validators for duplicate IDs, orphan references, dependency cycles, impossible prerequisites and invalid reward/economy references.
- Do not activate vendor/crafting/gathering systems without a coherent canonical economy model and persistence/inventory ownership.
- Do not invent party-leader/matchmaking authority as a side effect of an unrelated expedition task.
- Monetization remains locked behind the outside-player fun/repeat-intent gate except for explicitly authorized non-product infrastructure work.

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

StyLua covers `src`, `tests` and `tools`. Selene is scoped to `src` only; it needs the Roblox API dump, which some sandboxes cannot reach.

A documentation-only roadmap/authority change must still be checked for broken links, contradictory authority claims, and stale status facts. Do not claim runtime validation from a docs-only change.

For v2.7 runtime migration tickets, static tests do not replace required Studio evidence such as listener timing, reset/respawn baselines, queue warnings, streaming rebind, multiplayer disconnect behavior, or profiling captures.

## Change discipline

- Fetch current `main` and inspect related open PRs before editing.
- Make the smallest coherent change that completes the task.
- Preserve existing architecture unless the task explicitly requires a migration.
- Prefer pure modules for rules/calculations and explicit runtime owners for side effects.
- Keep client, server and shared responsibilities separated.
- Do not invent asset IDs, animation IDs, product IDs, place IDs, universe IDs or secrets.
- Do not commit credentials, cookies, tokens, local Studio settings or generated build artifacts.
- Do not weaken tests/security checks to make CI pass.
- Update relevant documentation when changing architecture, setup, controls, data contracts, rollout flags, runtime state semantics, world lifecycle, economy ownership or Studio boundary.
- Compatibility/feature flags require an owner, rollback trigger, evidence gate and removal condition.
- Compatibility removal must update the cutover ledger and retain the required rollback checkpoint.
- Do not duplicate work already present in an open PR.

## Roblox Studio boundary

Routine code development should happen through GitHub, agents, local editors, Rojo, Lune, Selene, StyLua and CI.

Roblox Studio remains required for engine-level playtesting, visual world authoring, terrain, animation authoring, asset permissions, certain instance properties, device emulation, performance profiling, streaming behavior, active network timing, world composition/readability, atmosphere/audio review and publishing.

Follow `docs/production/RBXL-IMPORT-MIGRATION.md` when reconciling a newer place with repository source.

For current rollout evidence, follow `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`, update `docs/production/V2.7-CUTOVER-LEDGER.md`, preserve the named rollback/build checkpoint and create a fresh evidence packet with exact build/commit/place identity.

## Completion report

When finishing a task, report:

- active roadmap ticket/build-ahead ID and lane;
- files changed;
- behavior changed (or explicitly none for docs/data-only work);
- validation performed and exact results;
- ownership/authority boundaries touched;
- cutover ledger rows changed where applicable;
- before/after runtime counters where applicable;
- evidence packet or Studio-only checks still required;
- rollback checkpoint/flag state for migration work;
- roadmap status/next dependency-safe task;
- risks, assumptions and unresolved follow-up work.
