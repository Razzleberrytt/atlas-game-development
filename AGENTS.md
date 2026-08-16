# Agent Operating Contract

Atlas is developed GitHub-first. The repository is the source of truth for gameplay code, configuration, tests, technical documentation, and reproducible builds.

## Read-first rule

For ordinary Living Kingdoms work, keep startup context small. Read only:

1. `docs/roadmap/EXECUTION-DASHBOARD.md` — current task, NOW/NEXT/LATER, progress, and stop conditions.
2. `games/living-kingdoms/AGENTS.md` — scoped architecture, coding, validation, and Studio rules.

Then load specialist documents **only when the task touches them**:

| Task type | Additional authority to read |
|---|---|
| Documentation authority / coherence | `docs/README.md` |
| Product identity / design conflict | `docs/bible/00-current-product-authority.md` |
| Patch scope / exit criteria | `docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` |
| Implementation cadence / verification gating | `docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md` |
| Long-range requirement lookup | `docs/roadmap/MASTER-ROADMAP.md` |
| Development coverage / cross-system gap / taxonomy audit | `docs/architecture/DEVELOPMENT_TAXONOMY.md`, `docs/architecture/DEVELOPMENT-ATLAS.md`, `config/coverage/living-kingdoms-development.json` |
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

When asked to continue or implement the roadmap:

1. fetch current `main`;
2. inspect open PRs for overlap and distinguish current/rebased work from stale candidate branches;
3. read the dashboard NOW/NEXT/LATER queue;
4. if a **known concrete** runtime, authority, lifecycle, security, data-safety, or automated-validation failure makes downstream work unsafe/incorrect, fix it first;
5. otherwise take NOW and continue through coherent source milestones even when prior Studio/device/play evidence is pending;
6. implement the smallest coherent player-facing or dependency-removing increment;
7. when similarly valuable dependency-safe implementations exist, prefer the one that reduces future implementation cost through reuse, data/configuration, regression protection, tooling, or clearer agent execution;
8. validate according to the risk tier below;
9. merge successful dependency-safe work;
10. record **BUILT — VERIFICATION PENDING** when manual/engine evidence remains;
11. continue to the next source task/patch instead of creating a manual-test lock;
12. stop only when roadmap work is exhausted or a real named blocker makes further implementation unsafe/impossible.

Do not duplicate work already present in an open PR. An old open PR is not automatically current work: re-check its base, overlap, architecture, and validation before adopting it. Pending ordinary Studio/device/play-feel evidence is not, by itself, a source-development blocker.

## Status vocabulary

Use only:

- **NOT STARTED**
- **BUILDING**
- **BUILT — VERIFICATION PENDING**
- **VERIFIED**
- **DEFERRED**
- **BLOCKED — <concrete reason>**
- **HISTORICAL**

Source-complete work does not become unfinished merely because Studio verification is pending. It also does not become VERIFIED without the required evidence. `BLOCKED` requires a concrete technical/safety reason; missing ordinary manual verification alone is not sufficient.

The development-coverage registry uses a separate lowercase coverage vocabulary (`unknown`, `not-started`, `partial`, `substantial`, `complete`, `deferred`, `blocked`, `not-applicable`) because it measures concern coverage rather than patch execution status. Do not translate `substantial` into `VERIFIED`.

## Change-risk tiers

Classify the change before implementation. Use the lowest tier that truthfully covers the highest-risk boundary touched.

| Tier | Typical scope | Minimum repository validation | Runtime evidence expectation |
|---|---|---|---|
| **R0** | docs, roadmap prose, comments, non-runtime metadata | `python scripts/validate.py docs` | none unless the claim itself is runtime evidence |
| **R1** | presentation, pure resolvers, configuration, tooling, isolated low-consequence logic | `python scripts/validate.py fast` | grouped Studio verification later when behavior is engine/player-facing |
| **R2** | gameplay authority, remotes, combat, mission lifecycle, inventory/progression behavior | `python scripts/validate.py full` | grouped milestone evidence; earlier only if downstream safety genuinely depends on it |
| **R3** | persistence/value, migrations, security/trust boundaries, rollback-critical runtime cutovers | `python scripts/validate.py full` plus focused targeted checks | targeted runtime evidence only when required before an unsafe/irreversible dependent step |

CI deliberately treats non-doc source changes conservatively and runs the full profile. Local/agent work may use `fast` for R1 iteration, then `full` when the PR risk requires it.

## Source-of-truth and authority rules

- `games/living-kingdoms/src` is canonical Luau source.
- `games/living-kingdoms/default.project.json` and `games/living-kingdoms/main-world.project.json` are canonical Rojo mappings for their respective places.
- `games/living-kingdoms/tests` is required regression coverage.
- `games/living-kingdoms/imports` is preservation/reference material, not a second source tree.
- `config/coverage/living-kingdoms-development.json` is canonical development-coverage metadata; it never overrides runtime source or accepted evidence.
- Do not edit generated `.rbxl`, `.rbxlx`, sourcemaps, or build output as source.
- Preserve server authority for combat, health, enemies, missions, rewards, inventory, progression, persistence, economy, and ownership.
- Never trust client-provided damage, targets, positions, timestamps, cooldown completion, currency, inventory, progression, rewards, or ownership without server validation.
- Do not create a second authoritative state or presentation path when extending or migrating an existing owner.
- Prefer stable IDs, validated references, pure resolvers, reusable owners, and data/configuration over bespoke feature piles.
- The `LK-001`–`LK-300` taxonomy is a coverage ontology, not a request for one module/service per row.

## Compounding-development rule

The repository should become easier to extend as it grows. When proportionate to the current task:

- extend proven owners instead of cloning behavior;
- after a repeated shape is understood, move future variants toward validated data/configuration;
- turn meaningful bugs into focused regression defenses when practical;
- automate deterministic repeated agent/developer friction;
- keep ownership, extension points, validation commands, and exit signals discoverable;
- run a bounded leverage pass when a pattern reaches roughly its third implementation, a failure class repeats, or a patch is about to scale content breadth;
- classify broad cross-system work against the development taxonomy, then route it into the existing canonical engine/owner instead of inventing a parallel architecture;
- update the coverage registry when a coherent change materially moves concern coverage or evidence.

Use the repository tooling rather than relying on memory:

```bash
python scripts/efficiency.py bootstrap
python scripts/efficiency.py registry
python scripts/efficiency.py audit
python scripts/dev_metrics.py
python scripts/development_coverage.py report
python scripts/development_coverage.py validate --check-generated
```

The capability registry is `config/efficiency/capabilities.json`. Update it when a durable reusable owner or extension point is created, materially changed, or retired. The development-coverage registry is `config/coverage/living-kingdoms-development.json`. Audit/telemetry/coverage findings are advisory candidates, not automatic refactor or feature orders.

When two roadmap candidates are otherwise similarly valid, use `python scripts/efficiency.py score ...` to make the leverage tie-break explicit. Player value and dependency removal remain weighted above leverage.

Never build abstraction for abstraction's sake.

## Change discipline

- Keep one coherent result per PR when practical.
- Keep implementation PR WIP low: one active PR for the current capability; at most one additional non-overlapping feature PR when the first is externally blocked.
- Parallel-development eligibility means work *may* proceed across lanes; it does not authorize unlimited simultaneous implementation branches.
- Preserve existing architecture unless the task explicitly requires migration.
- Keep client, server, and shared responsibilities separated.
- Add focused tests for gameplay-rule changes and integration/source audits for wiring/security boundaries.
- Do not weaken tests or security checks just to make CI pass.
- Compatibility/feature flags require an owner, rollback trigger, evidence obligation, and removal condition.
- Do not commit credentials, cookies, tokens, local Studio settings, or generated build artifacts.

## Studio boundary

Routine code development belongs in GitHub/local tooling. Studio remains required for engine-only behavior, actual play feel, terrain/world composition, animations/assets, device emulation, performance/memory/network profiling, streaming, live timing, audio/lighting review, and publishing.

A Studio-only check is normally recorded as **BUILT — VERIFICATION PENDING** and grouped into a later coherent evidence pass. It does **not** stop ordinary source development. Earlier evidence is mandatory only for known runtime failures or narrow irreversible/security/data-risk steps whose downstream safety cannot be bounded without it.

If a later Studio/device pass exposes a reproducible failure, that concrete failure immediately preempts expansion and becomes the next FIX.

## Completion report

Report only the useful execution facts:

- current patch/capability;
- risk tier;
- files/behavior changed;
- validation run and exact result;
- authority/data/lifecycle boundaries touched;
- leverage/coverage outcome when applicable;
- status: BUILDING / BUILT — VERIFICATION PENDING / VERIFIED / etc.;
- Studio/device evidence still pending, if any;
- concrete blocker, if any;
- next highest-ROI task.

Keep the report short unless a migration/evidence packet genuinely needs detail.
