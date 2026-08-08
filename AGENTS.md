# Agent Operating Contract

This repository is designed for GitHub-first development by humans and coding agents. The repository is the source of truth for gameplay code, configuration, tests, technical documentation, and reproducible builds.

## Primary project

The active Roblox game is `games/living-kingdoms`.

Read these files before changing it:

1. `docs/bible/00-current-product-authority.md` — current strategic product authority and conflict resolution
2. `docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` — **current implementation-sequencing authority**; decides which playable slice is built next
3. `docs/roadmap/MASTER-ROADMAP.md` — complete v2.8 product path and requirements inventory
4. `games/living-kingdoms/AGENTS.md`
5. `games/living-kingdoms/CANONICAL-RUNTIME.md`
6. `games/living-kingdoms/README.md`
7. `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` — active runtime stabilization/rollout authority while its gates remain open
8. `docs/roadmap/PRODUCTION-CORE-V2.7.md`
9. `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` when runtime evidence is blocked or build-ahead work is requested
10. `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md` when touching runtime state, remotes, presentation, lifecycle, Studio migration, or incident closure
11. `docs/production/V2.7-CUTOVER-LEDGER.md` for producer/consumer/presentation migration work
12. `docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md` before any Studio/runtime run intended to close a gate or promote evidence level

`docs/bible/00-project-charter.md` is historical Living Kingdoms product provenance. Read it when historical design context is relevant, but do not use it to override Current Product Authority, Playable MVP + Patch Execution v2.9, or Master Roadmap v2.8.

More specific `AGENTS.md` files override this file for their directory scope.

## Current roadmap rule

Three layers coexist and have different jobs.

### 1. Runtime stabilization lane

Blueprint v2.7 controls current runtime rollout/stabilization order while its applicable gates remain open. Implement only the next dependency-safe v2.7 work whose required evidence can honestly be produced.

Accepted runtime evidence and current Roblox platform behavior outrank all roadmap prose.

### 2. Playable patch lane — controlling implementation sequence

`docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` controls which player-facing implementation comes next once work is dependency-safe.

The controlling order is:

```text
Gate 0 runtime stabilization
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

Each player-facing milestone ends with a hard **STOP / PLAY / FIX / REPLAY / THEN EXPAND** gate. A known blocker that prevents the current loop from being played end to end blocks the next patch.

When a Master Roadmap phase contains more scope than the current playable patch needs, implement the **smallest coherent dependency-safe subset** required for the current patch exit gate. Do not complete a broad future phase merely because it is well specified.

### 3. Complete product path

`docs/roadmap/MASTER-ROADMAP.md` remains the complete destination and requirements inventory. Its systems and quality requirements are preserved and mapped into the playable patch order rather than deleted.

A phase appearing in Master Roadmap v2.8 does **not** make it executable. Later-patch breadth remains locked unless the active runtime gate and playable patch sequence make it eligible.

### Build-ahead lane

When runtime evidence is blocked or the task explicitly requests safe preparation, use `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` and select only a task marked `READY` after fetching current `main` and inspecting related open PRs.

Among multiple READY tasks, prefer the work that most directly enables the **current playable milestone**. Preparation for later patches must not displace a blocker or high-ROI enabler for the current patch.

## Product-authority rule

- Atlas is currently governed by `docs/bible/00-current-product-authority.md`.
- Existing Living Kingdoms runtime systems are assets to preserve, not disposable prototypes.
- Do not infer a camera/combat rewrite from strategic product language. Camera mode, aiming model, combat presentation, and other foundational runtime behavior change only through an explicit scoped decision/migration with tests and evidence.
- The current world architecture separates the recovered authored overworld from the modern operation forest.
- Intended end state: `authored overworld / HubTown → canonical expedition launch → modern operation runtime → return`.
- The Forward Operations Hub is a temporary preparation bridge, not the final Main World.
- Before broadening a system, prove the smallest player-facing version inside the current playable patch whenever practical.

## MVP 0.1 priority rule

After Gate 0 is sufficiently stable for safe activation, the highest-priority player-facing target is the **First Complete Run**:

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

Do not block MVP 0.1 on the final Main World, full economy/crafting, huge skill trees, broad matchmaking, hundreds of items, multiple regions, launch analytics, or monetization. Use minimal canonical implementations sufficient to test the loop, while preserving server authority and future migration safety.

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

For MVP 0.1, build or retain only the smallest coherent preparation/return surface needed for the complete run. Broader environment expansion is a first-class focus in Patch 0.5.

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
- Prefer depth sufficient to test the current patch over breadth for breadth's sake.

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

For playable patches, static tests also do not replace the STOP / PLAY / FIX gate. The prior playable baseline must remain regression-tested, and required Studio evidence must be captured before claiming a player-facing patch complete.

## Change discipline

- Fetch current `main` and inspect related open PRs before editing.
- Identify the current playable patch before selecting a task.
- Make the smallest coherent change that advances that patch's exit gate.
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
- Do not begin later-patch breadth while a known blocker prevents the current patch from being played end to end.

## Roblox Studio boundary

Routine code development should happen through GitHub, agents, local editors, Rojo, Lune, Selene, StyLua and CI.

Roblox Studio remains required for engine-level playtesting, visual world authoring, terrain, animation authoring, asset permissions, certain instance properties, device emulation, performance profiling, streaming behavior, active network timing, world composition/readability, atmosphere/audio review and publishing.

Follow `docs/production/RBXL-IMPORT-MIGRATION.md` when reconciling a newer place with repository source.

For current rollout evidence, follow `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`, update `docs/production/V2.7-CUTOVER-LEDGER.md`, preserve the named rollback/build checkpoint and create a fresh evidence packet with exact build/commit/place identity.

For playable patch acceptance, use Studio to exercise the full representative loop and replay it. Capture multiplayer, device, performance, streaming, lifecycle or outside-player evidence when the current patch's exit gate requires those dimensions.

## Completion report

When finishing a task, report:

- active playable patch and active roadmap/runtime ticket or build-ahead ID;
- files changed;
- behavior changed (or explicitly none for docs/data-only work);
- validation performed and exact results;
- ownership/authority boundaries touched;
- cutover ledger rows changed where applicable;
- before/after runtime counters where applicable;
- evidence packet or Studio-only checks still required;
- STOP / PLAY / FIX gate status for the current playable patch;
- rollback checkpoint/flag state for migration work;
- current patch blocker status;
- next highest-ROI task for the current playable patch;
- risks, assumptions and unresolved follow-up work.
