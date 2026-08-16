# Atlas Roadmap Index

**Status:** CURRENT ROADMAP ROUTER  
**Refreshed:** 2026-08-16

This directory uses layered authority so product scope, execution state, technical safety, generated coverage, and historical provenance do not compete for the same job.

For the repository-wide documentation map, see [`../README.md`](../README.md).

## Read first

1. [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md) — **current daily execution authority**: NOW / NEXT / current blockers / current open-work interpretation.
2. [`PARALLEL-DEVELOPMENT-POLICY.md`](PARALLEL-DEVELOPMENT-POLICY.md) — which dependency-safe lanes may proceed in parallel. It defines eligibility, not target WIP.
3. [`AUTOMATED-FIRST-EXECUTION-POLICY.md`](AUTOMATED-FIRST-EXECUTION-POLICY.md) — automated implementation/validation cadence.
4. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — detailed player-facing patch scope and acceptance intent.
5. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — complete long-range product requirement inventory.

Product-direction conflicts are resolved by [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md).

## Specialist policy / safety authority

Load only when the current task touches the boundary:

- [`MVP-BUILD-THROUGH-TESTING-POLICY.md`](MVP-BUILD-THROUGH-TESTING-POLICY.md) — built-vs-verified status and milestone evidence cadence.
- [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md) — runtime-state/presentation stabilization requirements where that migration boundary is touched.
- [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md) — runtime production invariants and rollout mechanics.
- [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md) — current-state/presentation rollout and rollback evidence.
- [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md) — ownership/evidence traceability for the v2.7 boundary.
- [`DEVELOPMENT-FLYWHEEL.md`](DEVELOPMENT-FLYWHEEL.md) — leverage/compounding development decisions.
- [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md) — prepared dependency context; **not** the daily task queue.
- [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — specialist visual/environment production sequence.

## Cross-system development coverage

Broad gap/audit work uses the repository-wide 300-area ontology rather than creating another roadmap:

- [`../architecture/DEVELOPMENT_TAXONOMY.md`](../architecture/DEVELOPMENT_TAXONOMY.md) — stable `LK-001`–`LK-300` concern identities;
- [`../architecture/DEVELOPMENT-ATLAS.md`](../architecture/DEVELOPMENT-ATLAS.md) — engine/owner routing;
- `../../config/coverage/living-kingdoms-development.json` — machine-readable coverage source;
- [`../production/DEVELOPMENT-COVERAGE-REPORT.md`](../production/DEVELOPMENT-COVERAGE-REPORT.md) — generated gap/health view.

Coverage is not execution priority. The dashboard still chooses NOW/NEXT using current defects, player value, dependencies, overlap, evidence, and risk.

## Authority order

```text
accepted runtime evidence / current Roblox platform behavior
→ canonical source + repository configuration
→ Current Product Authority for product direction
→ PARALLEL-DEVELOPMENT-POLICY for work eligibility
→ AUTOMATED-FIRST-EXECUTION-POLICY for cadence
→ EXECUTION-DASHBOARD for NOW / NEXT
→ MVP-BUILD-THROUGH-TESTING-POLICY for built-vs-verified semantics
→ PLAYABLE-MVP-PATCH-EXECUTION for detailed patch scope
→ MASTER-ROADMAP for long-range destination
→ specialist architecture / specification / production guidance
→ generated coverage views
→ historical provenance
```

A pending manual/Studio test stays pending until evidence exists. It does **not** automatically convert completed source work back into unfinished work or freeze unrelated/dependency-safe development. A concrete failed runtime result preempts work when it directly blocks or makes that integration path unsafe.

## Current checkpoint — 2026-08-16

Do not maintain a duplicate detailed task list here. The dashboard owns changing execution detail.

At this refresh:

- Patch 0.7 durable-state hardening is automated-acceptance closed except for explicit deferrals recorded in its acceptance matrix/backlog.
- Current `main` has moved into concrete maintenance/audit hardening, including Main World road-failure metrics and bounded client network-wait repairs.
- Open PRs include both current maintenance candidates and older feature branches. **Open does not mean current**; stale/stacked branches require current-main overlap/dependency/validation review before adoption.
- Parallel lane eligibility remains broad, while root `AGENTS.md` deliberately keeps implementation WIP low.
- The development taxonomy/atlas/registry/report provide comprehensive concern coverage without becoming a second execution queue.

See [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md) for maintained details.

## Status vocabulary

Execution documents use:

```text
NOT STARTED
BUILDING
BUILT — VERIFICATION PENDING
VERIFIED
DEFERRED
BLOCKED — concrete reason required
HISTORICAL
```

The development-coverage registry intentionally uses a different lowercase coverage vocabulary because it answers a different question. A concern marked `substantial` is not automatically `VERIFIED`.

## Agent rule

When asked to `continue`, `implement next roadmap task`, `exhaustively improve`, or equivalent:

1. fetch current `main`;
2. inspect open PRs for overlap, base freshness, stack dependencies, and superseding merges;
3. read the dashboard NOW/NEXT queue;
4. fix any concrete regression/direct dependency that makes the selected path unsafe;
5. otherwise take the dashboard-selected work;
6. for broad audits, classify relevant `LK-###` concerns and route them through existing canonical engines/owners;
7. prefer the smallest modular/reversible implementation that removes a real gap;
8. run the required automated validation;
9. merge successful dependency-safe increments under repository WIP/merge rules;
10. mark source-complete work `BUILT — VERIFICATION PENDING` until required runtime evidence exists;
11. update the dashboard only when execution truth materially changes;
12. update development coverage only when concern coverage/evidence materially changes.

## Historical documents

Older roadmap versions remain useful provenance and idea inventory, but they are not daily execution authority. Examples include:

- `BLUEPRINT-V2.3-EXECUTION.md`
- `PRODUCTION-CORE-V2.3.md`
- `CROSS-SYSTEM-TRACEABILITY-V2.3.md`
- `QUALITY-AUDIT-V2.3.md`
- `BLUEPRINT-V2.0-EXECUTION.md`
- `BLUEPRINT-V1.9-EXECUTION.md`
- `P6-P12-EXECUTION-ROADMAP.md`
- `UNIFIED-MASTER-ROADMAP.md`
- `RECOMMENDED-PASSES.md`
- `SEQUENCING-EXCEPTION-P6-P7.md`

A historical file may remain valuable without being allowed to override current source, evidence, product authority, or dashboard execution state.

> **One dashboard for execution. One master roadmap for scope. One coverage registry for comprehensive gap accounting. History remains available without becoming a second present.**
