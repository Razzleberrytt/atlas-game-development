# Agent Operating Contract

This repository is designed for GitHub-first development by humans and coding agents. The repository is the source of truth for gameplay code, configuration, tests, technical documentation, and reproducible builds.

## Primary project

The active Roblox game is `games/living-kingdoms`.

Read these files before changing it:

1. `docs/bible/00-current-product-authority.md` — current strategic product authority and conflict resolution
2. `docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md` — **current execution-cadence and roadmap-status authority**; separates built work from verified work and retires general roadmap locks
3. `docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` — **current player-facing sequencing authority**; identifies the preferred playable milestone order
4. `docs/roadmap/MASTER-ROADMAP.md` — complete v2.8 product path and requirements inventory
5. `games/living-kingdoms/AGENTS.md`
6. `games/living-kingdoms/CANONICAL-RUNTIME.md`
7. `games/living-kingdoms/README.md`
8. `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` — active runtime stabilization/safety authority while its applicable boundaries remain open
9. `docs/roadmap/PRODUCTION-CORE-V2.7.md`
10. `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` for prepared-work and dependency context when useful
11. `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md` when touching runtime state, remotes, presentation, lifecycle, Studio migration, or incident closure
12. `docs/production/V2.7-CUTOVER-LEDGER.md` for producer/consumer/presentation migration work
13. `docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md` before any Studio/runtime run intended to close a gate or promote evidence level

`docs/bible/00-project-charter.md` is historical Living Kingdoms product provenance. Read it when historical design context is relevant, but do not use it to override Current Product Authority, the Build-Through + Milestone Verification Policy, Playable MVP + Patch Execution v2.9, or Master Roadmap v2.8.

More specific `AGENTS.md` files override this file for their directory scope.

## Current roadmap rule

The roadmap layers coexist and have different jobs.

### 1. Runtime safety/stabilization lane

Blueprint v2.7 protects current runtime safety while its applicable boundaries remain open. Preserve server authority, canonical ownership, rollback integrity, lifecycle correctness, and evidence that downstream runtime work genuinely depends on.

Accepted runtime evidence and current Roblox platform behavior outrank all roadmap prose.

Do not turn ordinary phase order into a blocker. A real runtime block must name the concrete reason work cannot safely or correctly proceed.

### 2. Build-through and roadmap-status lane — controlling execution cadence

`docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md` controls how agents move through implementation and how work is labeled.

Use these meanings:

- **NOT STARTED** — no meaningful implementation exists yet.
- **BUILDING** — implementation is active or partial.
- **BUILT — VERIFICATION PENDING** — implementation exists and applicable automated/static checks pass, but required Studio/device/integration/human evidence is still open.
- **VERIFIED** — applicable acceptance evidence passed.
- **DEFERRED** — intentionally lower priority for now, not prohibited merely by roadmap order.
- **BLOCKED** — work cannot safely or correctly proceed because of a named dependency, safety issue, broken owner/interface, or evidence boundary.
- **HISTORICAL** — provenance only.

Do not collapse **BUILT — VERIFICATION PENDING** into either **NOT STARTED** or **VERIFIED**.

The normal rhythm is:

```text
choose highest-ROI useful work
→ implement a small diagnosable increment
→ run automated/static validation
→ record the real status
→ continue through the coherent milestone
→ run the milestone Studio/playtest pass
→ fix integration/gameplay defects
→ replay until verified
→ continue building
```

A tiny ticket, merge, patch fragment, or version label does not automatically require a human Studio handoff before development can continue.

Earlier manual/runtime evidence is still mandatory when a narrow exception applies, including data-loss/persistence risk, consequential security/authority changes, an active v2.7 safety boundary, engine-only behavior that later work cannot safely depend on without runtime proof, or a known blocker that makes further implementation unsafe or misleading.

### 3. Playable milestone lane — preferred player-facing sequence

`docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` identifies the preferred player-facing order:

```text
runtime stabilization where genuinely required
→ MVP 0.1 first complete run
→ 0.2 combat feel/readability
→ 0.3 loot/build replayability
→ 0.4 RPG progression
→ 0.5 Main World/environment expansion
→ 0.6 procedural/systemic replayability
→ 0.7 durable persistence hardening
→ 0.8 co-op/social/session expansion
→ 0.9 content expansion/production pipeline
→ release-candidate hardening
→ 1.0
→ measured live patches
```

This order is a prioritization map, not a blanket implementation permission system. Prefer work that advances the current playable milestone, but later-phase work may be implemented early when it directly helps that milestone, removes a real dependency, creates a needed canonical interface, or is a small isolated high-value improvement.

At a coherent player-facing milestone, stop broad expansion long enough to run the applicable Studio/playtest/debug/replay pass. Mark the milestone **VERIFIED** only when its required evidence passes.

### 4. Complete product path

`docs/roadmap/MASTER-ROADMAP.md` remains the complete destination and requirements inventory. Its systems and quality requirements are preserved and mapped into the playable development path rather than deleted.

Older `[L]`, `LOCKED`, or similar phase-order labels are interpreted through the Build-Through policy. Unless a concrete engineering reason is named, treat them as **DEFERRED**, not prohibited.

### Build-ahead context

`docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` is useful prepared-work and dependency context. Historical `READY`, `PREPARED`, and lock labels are prioritization/history signals, not permission boundaries.

When runtime verification is pending and repository work can continue, choose the highest-ROI dependency-safe task that either advances the current playable milestone or removes a real dependency. Do not duplicate work already present in an open PR.

## Product-authority rule

- Atlas is currently governed by `docs/bible/00-current-product-authority.md`.
- Existing Living Kingdoms runtime systems are assets to preserve, not disposable prototypes.
- Do not infer a camera/combat rewrite from strategic product language. Camera mode, aiming model, combat presentation, and other foundational runtime behavior change only through an explicit scoped decision/migration with tests and evidence.
- The current world architecture separates the recovered authored overworld from the modern operation forest.
- Intended end state: `authored overworld / HubTown → canonical expedition launch → modern operation runtime → return`.
- The Forward Operations Hub is a temporary preparation bridge, not the final Main World.
- Before broadening a system, prove the smallest player-facing version inside the current playable milestone whenever practical.

## MVP 0.1 priority rule

The highest-priority player-facing target is the **First Complete Run**:

```text
spawn / arrive
→ orient and prepare
→ choose a weapon/build
→ enter one expedition
→ explore a readable route
→ fight
→ receive loot/reward decisions
→ defeat an elite
→ defeat one boss / terminal encounter
→ return
→ equip or apply an upgrade
→ start another run
```

Target first-run duration is roughly 5–10 minutes, subject to play evidence.

Do not make MVP 0.1 wait on the final Main World, full economy/crafting, huge skill trees, broad matchmaking, hundreds of items, multiple regions, launch analytics, or monetization. Use minimal canonical implementations sufficient to test the loop, while preserving server authority and future migration safety.

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

BA-010 and the subsequent Main World specifications define the accepted audit/representation direction. Do not discard those findings, but do not require the final broad Main World before the core MVP can be tested.

The target Main World loop is:

```text
Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return
```

For MVP 0.1, build or retain only the smallest coherent preparation/return surface needed for the complete run. Broader environment work becomes increasingly valuable as the loop matures and may be implemented earlier when it directly improves or enables the current playable milestone.

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
- Treat monetization as **DEFERRED** until outside-player fun/repeat-intent evidence makes it worth evaluating; supporting infrastructure may be implemented earlier when explicitly useful and safe.
- Prefer depth sufficient to test the current milestone over breadth for breadth's sake.

## Required validation

From the repository root, install the pinned tools in `rokit.toml`, then run:

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

StyLua covers `src`, `tests` and `tools`. Selene is scoped to `src` only; it needs the Roblox API dump, which some sandboxes cannot reach.

A documentation-only roadmap/authority change must still be checked for broken links, contradictory authority claims, and stale status facts — run `python scripts/validate_roadmap_authority.py` to check link integrity, historical-checkpoint leakage, and dangling commit references, and manually confirm status prose still matches the current task table/checkpoint. Do not claim runtime validation from a docs-only change.

For v2.7 runtime migration tickets, static tests do not replace required Studio evidence such as listener timing, reset/respawn baselines, queue warnings, streaming rebind, multiplayer disconnect behavior, or profiling captures.

Passing static/automated checks permits the next dependency-safe task to continue when no narrow early-runtime exception applies. Those checks do not prove Studio behavior; record unresolved Studio/device/integration verification as **BUILT — VERIFICATION PENDING** and group it into the next coherent milestone pass when safe.

For player-facing milestones, static tests likewise do not replace milestone acceptance. Preserve the prior playable baseline with regression coverage and capture required Studio/runtime evidence before declaring the coherent milestone **VERIFIED**.

## Change discipline

- Fetch current `main` and inspect related open PRs before editing.
- Identify the current playable milestone before selecting a task.
- Make the smallest coherent high-ROI change that advances the milestone or removes a real dependency.
- Later-phase work is allowed when it directly helps, but avoid broad speculative expansion with no near-term payoff.
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
- Stop and resolve a concrete blocker when later work would necessarily build on unsafe or known-wrong behavior; do not stop merely because the roadmap phase is later.

## Roblox Studio boundary

Routine code development should happen through GitHub, agents, local editors, Rojo, Lune, Selene, StyLua and CI.

Roblox Studio remains required for engine-level playtesting, visual world authoring, terrain, animation authoring, asset permissions, certain instance properties, device emulation, performance profiling, streaming behavior, active network timing, world composition/readability, atmosphere/audio review and publishing.

Follow `docs/production/RBXL-IMPORT-MIGRATION.md` when reconciling a newer place with repository source.

For current rollout evidence, follow `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`, update `docs/production/V2.7-CUTOVER-LEDGER.md`, preserve the named rollback/build checkpoint and create a fresh evidence packet with exact build/commit/place identity.

Studio-only checks should be recorded as **BUILT — VERIFICATION PENDING** when implementation is otherwise complete rather than forcing a routine human handoff after every increment. At a coherent player-facing milestone, use Studio to exercise the representative loop/layer and replay it before marking that milestone verified. Earlier Studio/runtime proof remains required for the narrow exceptions defined in `docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md`.

For milestone acceptance, capture multiplayer, device, performance, streaming, lifecycle or outside-player evidence when the milestone's claim actually requires those dimensions.

## Completion report

When finishing a task, report:

- current playable milestone and active roadmap/runtime ticket or build-ahead ID where useful;
- files changed;
- behavior changed (or explicitly none for docs/data-only work);
- validation performed and exact results;
- ownership/authority boundaries touched;
- cutover ledger rows changed where applicable;
- before/after runtime counters where applicable;
- current status: NOT STARTED / BUILDING / BUILT — VERIFICATION PENDING / VERIFIED / DEFERRED / BLOCKED / HISTORICAL;
- evidence packet or Studio/device/integration checks still required;
- rollback checkpoint/flag state for migration work;
- concrete blocker status, if any;
- next highest-ROI dependency-safe task;
- risks, assumptions and unresolved follow-up work.