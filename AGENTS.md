# Agent Operating Contract

Atlas is developed GitHub-first. The repository is the source of truth for gameplay code, configuration, tests, technical documentation, and reproducible builds.

## Read-first rule

For ordinary Living Kingdoms work, keep startup context small. Read only:

1. `docs/roadmap/EXECUTION-DASHBOARD.md` — current task, NOW/NEXT/LATER, progress, and stop conditions.
2. `games/living-kingdoms/AGENTS.md` — scoped architecture, coding, validation, and Studio rules.

Then load specialist documents **only when the task touches them**:

| Task type | Additional authority to read |
|---|---|
| Product identity / design conflict | `docs/bible/00-current-product-authority.md` |
| Patch scope / exit criteria | `docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` |
| Long-range requirement lookup | `docs/roadmap/MASTER-ROADMAP.md` |
| Repeated implementation friction / reusable-system decision / leverage tie-break | `docs/roadmap/DEVELOPMENT-FLYWHEEL.md`, `docs/production/ENGINEERING-EFFICIENCY-OPS.md` |
| Runtime safety, current-state delivery, lifecycle, remotes, rollback | `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md`, `docs/roadmap/PRODUCTION-CORE-V2.7.md`, and when applicable `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md` |
| Replicated/presentation ownership migration | `docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md` and `docs/production/V2.7-CUTOVER-LEDGER.md` |
| Evidence-bearing Studio run | `docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md` |
| Main World / environment | applicable `docs/specifications/main-world-*` documents |
| Prepared later-phase dependency work | `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` |
| Importing/reconciling a Roblox place | `docs/production/RBXL-IMPORT-MIGRATION.md` |

Do **not** preload the entire roadmap stack for an ordinary isolated change. More-specific `AGENTS.md` files override this file within their directory scope.

Accepted runtime evidence and current Roblox platform behavior outrank roadmap prose.

## Task-selection rule

When asked to continue or implement the next roadmap task:

1. fetch current `main`;
2. inspect open PRs for overlap;
3. read the dashboard NOW/NEXT/LATER queue;
4. if a concrete runtime, authority, lifecycle, data-safety, or milestone failure exists, fix it first;
5. otherwise take NOW, or NEXT only when NOW is externally blocked and the work does not overlap;
6. implement the smallest coherent player-facing or dependency-removing increment;
7. when similarly valuable dependency-safe implementations exist, prefer the one that reduces future implementation cost through reuse, data/configuration, regression protection, tooling, or clearer agent execution; use `DEVELOPMENT-FLYWHEEL.md` when that choice is non-obvious;
8. validate according to the risk tier below;
9. merge successful dependency-safe work without inventing a manual-test stop after every small change;
10. update roadmap status only when meaningful task/progress/blocker truth changes.

Do not duplicate work already present in an open PR. Do not use leverage as an excuse for speculative frameworks or for bypassing an active dependency/safety gate.

## Status vocabulary

Use only:

- **NOT STARTED**
- **BUILDING**
- **BUILT — VERIFICATION PENDING**
- **VERIFIED**
- **DEFERRED**
- **BLOCKED — <concrete reason>**
- **HISTORICAL**

Source-complete work does not become unfinished merely because Studio verification is pending. It also does not become VERIFIED without the required evidence.

## Change-risk tiers

Classify the change before implementation. Use the lowest tier that truthfully covers the highest-risk boundary touched.

| Tier | Typical scope | Minimum repository validation | Runtime evidence expectation |
|---|---|---|---|
| **R0** | docs, roadmap prose, comments, non-runtime metadata | `python scripts/validate.py docs` | none unless the claim itself is runtime evidence |
| **R1** | presentation, pure resolvers, configuration, tooling, isolated low-consequence logic | `python scripts/validate.py fast` | milestone-grouped Studio verification when behavior is engine/player-facing |
| **R2** | gameplay authority, remotes, combat, mission lifecycle, inventory/progression behavior | `python scripts/validate.py full` | milestone Studio/device evidence; earlier only if downstream safety depends on it |
| **R3** | persistence/value, migrations, security/trust boundaries, rollback-critical runtime cutovers | `python scripts/validate.py full` plus focused targeted checks | targeted runtime evidence before unsafe downstream dependency is allowed |

CI deliberately treats non-doc source changes conservatively and runs the full profile. Local/agent work may use `fast` for R1 iteration, then `full` when the PR risk requires it.

## Source-of-truth and authority rules

- `games/living-kingdoms/src` is canonical Luau source.
- `games/living-kingdoms/default.project.json` is canonical Rojo mapping.
- `games/living-kingdoms/tests` is required regression coverage.
- `games/living-kingdoms/imports` is preservation/reference material, not a second source tree.
- Do not edit generated `.rbxl`, `.rbxlx`, sourcemaps, or build output as source.
- Preserve server authority for combat, health, enemies, missions, rewards, inventory, progression, persistence, economy, and ownership.
- Never trust client-provided damage, targets, positions, timestamps, cooldown completion, currency, inventory, progression, rewards, or ownership without server validation.
- Do not create a second authoritative state or presentation path when extending or migrating an existing owner.
- Prefer stable IDs, validated references, pure resolvers, reusable owners, and data/configuration over bespoke feature piles.

## Compounding-development rule

The repository should become easier to extend as it grows. When proportionate to the current task:

- extend proven owners instead of cloning behavior;
- after a repeated shape is understood, move future variants toward validated data/configuration;
- turn meaningful bugs into focused regression defenses when practical;
- automate deterministic repeated agent/developer friction;
- keep ownership, extension points, validation commands, and exit signals discoverable;
- run a bounded leverage pass when a pattern reaches roughly its third implementation, a failure class repeats, or a patch is about to scale content breadth.

Use the repository tooling rather than relying on memory:

```bash
python scripts/efficiency.py bootstrap
python scripts/efficiency.py registry
python scripts/efficiency.py audit
python scripts/dev_metrics.py
```

The capability registry is `config/efficiency/capabilities.json`. Update it when a durable reusable owner or extension point is created, materially changed, or retired. Audit/telemetry findings are advisory candidates, not automatic refactor orders.

When two roadmap candidates are otherwise similarly valid, use `python scripts/efficiency.py score ...` to make the leverage tie-break explicit. Player value and dependency removal remain weighted above leverage.

Player value, dependency order, server authority, and evidence gates remain primary. Never build abstraction for abstraction's sake.

## Change discipline

- Keep one coherent result per PR when practical.
- Keep implementation PR WIP low: one active PR for the current capability; at most one additional non-overlapping feature PR when the first is externally blocked.
- Preserve existing architecture unless the task explicitly requires migration.
- Keep client, server, and shared responsibilities separated.
- Add focused tests for gameplay-rule changes and integration/source audits for wiring/security boundaries.
- Do not weaken tests or security checks just to make CI pass.
- Compatibility/feature flags require an owner, rollback trigger, evidence gate, and removal condition.
- Do not commit credentials, cookies, tokens, local Studio settings, or generated build artifacts.
- For routine safe PRs, enable auto-merge when available after required checks are configured; merged same-repository branches are cleaned automatically by workflow.

## Studio boundary

Routine code development belongs in GitHub/local tooling. Studio remains required for engine-only behavior, actual play feel, terrain/world composition, animations/assets, device emulation, performance/memory/network profiling, streaming, live timing, audio/lighting review, and publishing.

A Studio-only check is normally recorded as **BUILT — VERIFICATION PENDING** and grouped into the next coherent milestone pass. Earlier evidence is mandatory for R3 changes, active safety gates, known runtime failures, or engine-only facts that later work cannot safely assume.

## Completion report

Report only the useful execution facts:

- current patch/capability;
- risk tier;
- files/behavior changed;
- validation run and exact result;
- authority/data/lifecycle boundaries touched;
- leverage outcome when applicable (reuse, data conversion, regression defense, tooling, capability-registry update, or intentionally none);
- status: BUILDING / BUILT — VERIFICATION PENDING / VERIFIED / etc.;
- Studio/device evidence still pending, if any;
- concrete blocker, if any;
- next highest-ROI task.

Keep the report short unless a migration/evidence packet genuinely needs detail.