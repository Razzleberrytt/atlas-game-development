# Atlas Documentation Map

**Status:** CURRENT DOCUMENTATION ROUTER  
**Refreshed:** 2026-08-16  
**Purpose:** keep current authority, execution state, long-range scope, generated coverage, evidence, and historical provenance from competing with one another.

Atlas has a large and useful documentation history. The repository should preserve that history without allowing old checkpoints or versioned plans to masquerade as current truth.

## Read this way

For ordinary Living Kingdoms implementation, keep startup context small:

1. [`../AGENTS.md`](../AGENTS.md) — repository operating contract, risk tiers, source-of-truth and merge discipline.
2. [`roadmap/EXECUTION-DASHBOARD.md`](roadmap/EXECUTION-DASHBOARD.md) — current execution truth: NOW / NEXT / current blockers / open-work interpretation.
3. [`../games/living-kingdoms/AGENTS.md`](../games/living-kingdoms/AGENTS.md) — scoped Roblox/Rojo architecture and validation rules.

Load additional documents only for the concern being changed.

## Authority layers

| Question | Current authority | What it is not |
|---|---|---|
| What game are we building? | [`bible/00-current-product-authority.md`](bible/00-current-product-authority.md) | daily task queue |
| What may proceed in parallel? | [`roadmap/PARALLEL-DEVELOPMENT-POLICY.md`](roadmap/PARALLEL-DEVELOPMENT-POLICY.md) | permission for unlimited WIP |
| What should happen now? | [`roadmap/EXECUTION-DASHBOARD.md`](roadmap/EXECUTION-DASHBOARD.md) | permanent product specification |
| What is the patch/release destination? | [`roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`](roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md) and [`roadmap/MASTER-ROADMAP.md`](roadmap/MASTER-ROADMAP.md) | proof that a feature exists |
| How is source-complete different from verified? | [`roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md`](roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md) | substitute for actual Studio/device evidence |
| What runtime-safety constraints still apply? | Blueprint/Production Core v2.7 documents when their boundaries are touched | blanket feature freeze |
| Which development concerns exist across the whole game? | [`architecture/DEVELOPMENT_TAXONOMY.md`](architecture/DEVELOPMENT_TAXONOMY.md) | 300 independent modules or a task queue |
| Which canonical engine/owner should absorb a concern? | [`architecture/DEVELOPMENT-ATLAS.md`](architecture/DEVELOPMENT-ATLAS.md) | permission to duplicate an owner |
| What is the machine-readable coverage state? | `../config/coverage/living-kingdoms-development.json` | runtime evidence by itself |
| What are the current coverage gaps? | [`production/DEVELOPMENT-COVERAGE-REPORT.md`](production/DEVELOPMENT-COVERAGE-REPORT.md) | release-readiness score |
| What actually happened in a merged change? | Git history + accepted automated/runtime evidence | roadmap prose |

## Precedence

When documents disagree, resolve the disagreement by question rather than by file age alone:

```text
accepted runtime evidence / current Roblox platform behavior
→ canonical source and repository configuration
→ current product authority for product intent
→ current governance policy for whether work may proceed
→ execution dashboard for NOW / NEXT
→ patch execution + master roadmap for planned scope
→ specialist architecture/specification/production docs
→ generated coverage views
→ historical/versioned provenance
```

A generated coverage document never outranks canonical source or accepted evidence. A historical document never becomes current merely because a newer file links to it for provenance.

## Current-state rule

Only the execution dashboard should carry a detailed changing daily checkpoint. Root/index documents may summarize the current lane, but they should link back to the dashboard rather than maintain independent task lists that drift.

When a meaningful merge changes the active lane, blocker, dependency, or next action, update the dashboard in the same coherent documentation pass. Do not update dozens of old roadmap versions to repeat the same status.

## Development taxonomy rule

The `LK-001` through `LK-300` taxonomy is a **coverage ontology**. It exists to make gaps discoverable and measurable while routing work into the existing architecture.

Use this sequence:

```text
detect gap or regression
→ classify LK concern(s)
→ map to canonical engine(s)
→ locate the real existing owner
→ implement the smallest coherent change
→ validate / measure
→ update coverage evidence if it materially changed
→ merge
```

Do not create one module, service, registry, metric, or PR per taxonomy row. One strong canonical owner may satisfy many concerns.

## Documentation maintenance rules

- Current authority documents must use the repository's canonical status vocabulary.
- Dated/current checkpoint prose belongs in the dashboard, not copied into multiple indexes.
- Generated taxonomy/atlas/report files are regenerated from the coverage registry; do not hand-edit their state independently.
- Versioned Blueprint/Production Core/Cross-System documents are specialist authority only for the boundaries the current indexes explicitly elevate.
- Older roadmap versions, superseded acceptance narratives, and completed migration plans are retained for provenance unless deletion materially improves safety or discoverability.
- A file may be historically useful without being current execution authority.
- Broken links, historical authority leaks, stale generated coverage, and invalid taxonomy structure are repository validation failures.

## Validation

Documentation coherence is part of the normal repository gate:

```bash
python scripts/validate.py docs
python scripts/development_coverage.py validate --check-generated
```

Regenerate the coverage views after registry edits:

```bash
python scripts/development_coverage.py sync
```

> **One product authority. One execution dashboard. One canonical source tree. One machine-readable development-coverage registry. History stays available without becoming a second present.**
