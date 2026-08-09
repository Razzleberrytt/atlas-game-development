# Atlas Game Development

Atlas is the GitHub-first home for a **cooperative action RPG on Roblox**: readable combat, run-based build decisions, durable progression, discovery, a recognizable Main World, and replayable cooperative operations.

Existing Living Kingdoms systems are preserved as working assets while the project converges on one authoritative runtime and presentation architecture.

## Start here

For day-to-day development, do **not** preload the entire roadmap stack.

1. [`docs/roadmap/EXECUTION-DASHBOARD.md`](docs/roadmap/EXECUTION-DASHBOARD.md) — **NOW / NEXT / LATER**, current status, progress, and stop conditions.
2. [`games/living-kingdoms/AGENTS.md`](games/living-kingdoms/AGENTS.md) — scoped architecture, coding, validation, and Studio rules.
3. Open specialist roadmap/specification documents only when the current task needs them.

The complete roadmap index is [`docs/roadmap/README.md`](docs/roadmap/README.md).

## Production rule

> **Always leave Atlas playable. Build the smallest coherent result, validate it at the right risk level, and verify coherent player-facing milestones instead of stopping after every tiny implementation.**

Normal rhythm:

```text
NOW task
→ small coherent implementation
→ automated validation
→ merge
→ continue through the coherent layer
→ milestone Studio/play/device pass
→ fix + replay
→ VERIFIED
→ next patch
```

## Current checkpoint — 2026-08-09

- **MVP 0.1 source loop:** **BUILT — VERIFICATION PENDING**; no known required source gap remains.
- **Human/Studio lane:** consolidated exact-build MVP 0.1 run/replay/device/performance pass.
- **Agent/source lane:** **Patch 0.2 Combat Feel + Readability**.
- **Current implementation overlap:** open PR #316 covers teammate melee presentation and should be resolved before duplicate work starts.
- **Estimated path to 1.0:** ~30% planning estimate only; evidence/status labels remain authoritative.

See the dashboard for the maintained queue.

## Product and roadmap authority

Use this precedence:

```text
accepted runtime evidence / current Roblox platform behavior
→ concrete Blueprint v2.7 runtime-safety requirements while applicable
→ EXECUTION-DASHBOARD.md for daily task selection
→ MVP-BUILD-THROUGH-TESTING-POLICY.md for built-vs-verified cadence
→ PLAYABLE-MVP-PATCH-EXECUTION.md for detailed patch scope
→ Current Product Authority + MASTER-ROADMAP.md for complete product direction/scope
→ specialist specifications / architecture / production controls
→ historical documents
```

Key documents:

- [`docs/bible/00-current-product-authority.md`](docs/bible/00-current-product-authority.md)
- [`docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md`](docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md)
- [`docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`](docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md)
- [`docs/roadmap/MASTER-ROADMAP.md`](docs/roadmap/MASTER-ROADMAP.md)
- [`docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md`](docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md)

Older charters/roadmaps remain provenance, not daily task authority.

## Player-facing path

```text
MVP 0.1  first complete repeatable run
0.2      combat feel + readability
0.3      loot + build replayability
0.4      RPG progression
0.5      Main World + environment
0.6      procedural/systemic replayability
0.7      durable persistence hardening
0.8      co-op/social/session expansion
0.9      content expansion + production pipeline
RC       production hardening
1.0      release
LIVE     measured upgrade patches
```

## First complete run

```text
safe arrival
→ prepare
→ humble melee start
→ deliberate expedition launch
→ explore / fight
→ discover or earn firearm
→ loot / reward decision
→ elite
→ boss / terminal
→ result
→ return
→ bank / equip / upgrade
→ replay
```

Target first-run duration remains roughly **5–10 minutes**, subject to play evidence. The important product signal is whether a tester can complete the loop without developer intervention and wants another run.

## Combined-world status

The original Studio preservation gap is repaired:

- 28/28 Studio-only source files preserved;
- 1,775/1,775 Workspace identity/hierarchy rows preserved;
- property-backed authored-world reconstruction exists;
- stable world-content IDs/contracts exist;
- Forward Operations Hub is the current preparation bridge;
- recovered authored overworld remains a separate future coordinate/lifecycle space;
- intended end state: **authored overworld / HubTown → canonical expedition launch → modern operation runtime → return**.

See [`games/living-kingdoms/CANONICAL-RUNTIME.md`](games/living-kingdoms/CANONICAL-RUNTIME.md).

## Engineering laws

1. Server owns valuable game truth; clients submit intent, never outcomes.
2. Do not create parallel authoritative systems.
3. Keep WIP low and inspect open PRs before implementation.
4. Prefer reusable owners, pure resolvers, stable IDs, validated references, and data/configuration over bespoke piles.
5. Source/static checks do not prove Studio behavior.
6. Pending Studio verification does not erase completed source work.
7. Valuable mutations must be replay/duplication safe where applicable.
8. Recovered Studio content is migration/presentation input, not permission to reboot legacy gameplay services.
9. Later roadmap detail is not a reason to leapfrog the current playable exit gate.
10. A known current-loop blocker preempts later breadth.

## Validation

One command is authoritative:

```bash
python scripts/validate.py docs
python scripts/validate.py fast
python scripts/validate.py full
```

Use the risk tiers in root `AGENTS.md`. CI automatically uses a lightweight docs profile for Markdown-only changes and the full profile for non-doc source/infrastructure changes.

## Repository map

- `games/living-kingdoms/` — canonical Roblox/Rojo project
- `docs/roadmap/` — execution dashboard, patch scope, full roadmap, safety/rollout authority, history
- `docs/bible/` — current product authority and historical product provenance
- `docs/specifications/` — detailed behavior inside accepted boundaries
- `docs/architecture/` — technical boundaries
- `docs/decisions/` — explicit product/architecture decisions
- `docs/production/` — evidence, workflow, migration, Definition of Done
- `scripts/` — repository validation and Roblox extraction/reconciliation tooling
- `prompts/` — reusable agent prompts
- `templates/` — task/specification/decision/bug templates

> **One dashboard for execution. One master roadmap for scope. Low WIP. Validate automatically. Verify meaningful milestones.**