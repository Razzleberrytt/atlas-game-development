# Atlas Game Development

Atlas is the GitHub-first home for a **cooperative action RPG on Roblox**: readable combat, run-based build decisions, durable progression, discovery, a recognizable Main World, and replayable cooperative operations.

Living Kingdoms is the canonical Roblox/Rojo game project. Existing systems are preserved as working assets while the project converges on one authoritative runtime, world, data, and presentation architecture.

## Start here

For day-to-day work, do **not** preload the entire documentation history.

1. [`AGENTS.md`](AGENTS.md) — repository operating contract, risk tiers, validation, WIP, and authority rules.
2. [`docs/roadmap/EXECUTION-DASHBOARD.md`](docs/roadmap/EXECUTION-DASHBOARD.md) — **current NOW / NEXT / blockers / open-work interpretation**.
3. [`games/living-kingdoms/AGENTS.md`](games/living-kingdoms/AGENTS.md) — scoped Roblox/Rojo architecture, coding, and Studio rules.
4. [`docs/README.md`](docs/README.md) — documentation authority map when you need to know which specialist document controls a question.

The complete roadmap index is [`docs/roadmap/README.md`](docs/roadmap/README.md).

## Production rule

> **Always leave Atlas playable. Build the smallest coherent result, validate it at the right risk level, and verify coherent player-facing milestones instead of stopping after every tiny implementation.**

Normal rhythm:

```text
current dashboard task
→ inspect fresh main + open PR overlap
→ small coherent implementation
→ automated validation
→ merge
→ continue through the coherent layer
→ milestone Studio/play/device pass when required
→ fix + replay
→ VERIFIED only with evidence
→ next task/patch
```

## Current checkpoint — 2026-08-16

The detailed daily checkpoint lives only in the execution dashboard so it does not drift across indexes.

At this refresh:

- `main` is a **Roblox/Rojo** source tree with canonical operation and dedicated Main World project mappings;
- Patch 0.7 durable-state hardening remains automated-acceptance complete except for its explicitly recorded deferred rows;
- the immediate maintenance lane is concrete startup/reliability hardening around bounded client network waits, while Main World topology/resilience is now measurable through repository-owned graph/failure-impact tooling;
- older open gameplay PRs are **candidates**, not automatic current work; they require fresh-main overlap/dependency review and current validation before adoption;
- a canonical `LK-001`–`LK-300` development-coverage ontology now maps broad concerns into existing engines/owners without creating 300 competing systems.

See [`docs/roadmap/EXECUTION-DASHBOARD.md`](docs/roadmap/EXECUTION-DASHBOARD.md) for the maintained NOW/NEXT truth.

## Product and execution authority

Use this question-oriented precedence:

```text
accepted runtime evidence / current Roblox platform behavior
→ canonical source + repository configuration
→ Current Product Authority for product identity
→ Parallel Development Policy for whether dependency-safe work may proceed
→ Execution Dashboard for NOW / NEXT
→ build-through-testing policy for built-vs-verified cadence
→ playable patch execution + master roadmap for planned scope
→ specialist architecture / specification / production documents
→ generated coverage views
→ historical provenance
```

Key current documents:

- [`docs/bible/00-current-product-authority.md`](docs/bible/00-current-product-authority.md)
- [`docs/roadmap/PARALLEL-DEVELOPMENT-POLICY.md`](docs/roadmap/PARALLEL-DEVELOPMENT-POLICY.md)
- [`docs/roadmap/EXECUTION-DASHBOARD.md`](docs/roadmap/EXECUTION-DASHBOARD.md)
- [`docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md`](docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md)
- [`docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`](docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md)
- [`docs/roadmap/MASTER-ROADMAP.md`](docs/roadmap/MASTER-ROADMAP.md)

Older charters/roadmaps remain provenance unless the current documentation router explicitly elevates them for a specialist boundary.

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

This is the product path, not the live task queue. The dashboard may select maintenance, defect, evidence, migration, or dependency work when that is the highest-ROI safe next action.

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

Target first-run duration remains roughly **5–10 minutes**, subject to actual play evidence. The important product signal is whether a tester can complete the loop without developer intervention and wants another run.

## Combined-world direction

The intended world/runtime direction remains:

**authored overworld / HubTown → canonical expedition launch → modern operation runtime → return**

Recovered Studio content is preservation/migration input, not a parallel runtime authority. The dedicated Main World Rojo project and current environment/traversal validation must remain coherent with canonical source and evidence.

See [`games/living-kingdoms/CANONICAL-RUNTIME.md`](games/living-kingdoms/CANONICAL-RUNTIME.md).

## Development coverage system

Living Kingdoms has a canonical 300-area concern ontology:

- [`docs/architecture/DEVELOPMENT_TAXONOMY.md`](docs/architecture/DEVELOPMENT_TAXONOMY.md) — `LK-001` through `LK-300`;
- [`docs/architecture/DEVELOPMENT-ATLAS.md`](docs/architecture/DEVELOPMENT-ATLAS.md) — conceptual engine/owner routing;
- `config/coverage/living-kingdoms-development.json` — machine-readable source;
- [`docs/production/DEVELOPMENT-COVERAGE-REPORT.md`](docs/production/DEVELOPMENT-COVERAGE-REPORT.md) — generated coverage/gap view.

The taxonomy is **not a task queue and not a module list**. Broad work follows:

```text
detect gap
→ classify LK concern(s)
→ map engine(s)
→ locate existing canonical owner
→ implement/test/measure
→ update coverage evidence if it materially changed
→ merge
```

## Engineering laws

1. Server owns valuable game truth; clients submit intent, never outcomes.
2. Do not create parallel authoritative systems.
3. Keep WIP low and inspect open PRs for freshness/overlap before implementation.
4. Prefer reusable owners, pure resolvers, stable IDs, validated references, and data/configuration over bespoke piles.
5. Source/static checks do not prove Studio behavior.
6. Pending Studio verification does not erase completed source work.
7. Valuable mutations must be replay/duplication safe where applicable.
8. Recovered Studio content is migration/presentation input, not permission to reboot legacy gameplay services.
9. Development coverage measures concerns; it does not override player value, dependencies, or current execution truth.
10. A known current-loop/safety blocker preempts later breadth when it directly affects the path being changed.

## Validation

Use the unified repository entry point:

```bash
python scripts/validate.py docs
python scripts/validate.py fast
python scripts/validate.py full
```

Coverage-specific inspection is available through:

```bash
python scripts/development_coverage.py report
python scripts/development_coverage.py atlas
python scripts/development_coverage.py validate --check-generated
```

Use the risk tiers in root `AGENTS.md`. CI uses the repository validation workflow; generated coverage drift and documentation-authority problems are validation failures.

## Repository map

- `games/living-kingdoms/` — canonical Roblox/Rojo project
- `docs/README.md` — documentation authority/router
- `docs/roadmap/` — execution dashboard, patch scope, master roadmap, policy, history
- `docs/bible/` — current product authority and product provenance
- `docs/architecture/` — technical boundaries + Development Taxonomy/Atlas
- `docs/specifications/` — detailed behavior inside accepted boundaries
- `docs/decisions/` — explicit product/architecture decisions
- `docs/production/` — evidence, workflow, migration, coverage report, Definition of Done
- `config/coverage/` — machine-readable development coverage
- `config/efficiency/` — reusable capability/extension/effect-routing metadata
- `scripts/` — validation, coverage, metrics, Roblox extraction/reconciliation tooling
- `prompts/` — reusable agent prompts
- `templates/` — task/specification/decision/bug templates

> **One product authority. One execution dashboard. One canonical source tree. One development-coverage registry. History stays useful without becoming a second present.**
