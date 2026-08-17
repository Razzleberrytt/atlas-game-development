# Atlas — Execution Dashboard v1.29

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-17  
**Main baseline audited:** `c5ac7ea4aff74c05c51ed673ff4731d21604f971`  
**Purpose:** answer quickly what is true, what is NOW, what may proceed, and what comes NEXT.

## Precedence

1. Accepted runtime evidence and current Roblox platform behavior — truth about what actually works.
2. [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) — product identity and design conflict resolution.
3. [`PARALLEL-DEVELOPMENT-POLICY.md`](PARALLEL-DEVELOPMENT-POLICY.md) — dependency-safe eligibility, not unlimited WIP.
4. [`AUTOMATED-FIRST-EXECUTION-POLICY.md`](AUTOMATED-FIRST-EXECUTION-POLICY.md) — automated execution cadence and verification authority.
5. This dashboard — current daily status and NOW/NEXT selection.
6. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — player-facing patch goals/product intent.
7. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — long-range destination inventory.
8. Patch-specific acceptance/backlog documents — active only when this dashboard selects that patch/capability.

## Current truth — 2026-08-17

- Living Kingdoms remains a Roblox/Rojo repository-first codebase; `games/living-kingdoms/src/` is gameplay-authoritative source.
- Patch 0.7 durable persistence/valuable-state hardening remains automated-acceptance complete for all non-deferred work (86 / 100 implemented; 14 explicit deferrals).
- **LKB-0682 is VERIFIED** — Main World northwest route resilience, PR #649, merge `c9d23a7b4c8b892dd3d7d16e86684fa69882f7c8`, green #2286/#2287 evidence.
- **LKB-0033 is VERIFIED and its bounded-dependency maintenance lane is CLOSED** — exhaustive source hardening via #656 and coordination closeout via #657; current recursive wait audits remain part of repository validation.
- **LKB-0567 is VERIFIED and its claim is RELEASED.** PR #660 passed Full Atlas #2384 on exact head `02345b94742cfa0011efa0f00e30edf6e590c25c`, merged as `834b0c41be786aeddb4e17cde05fe9b0ca38cf16`, and main push #2385 passed. Closeout PR #661 passed Full Atlas #2386, merged as `c5ac7ea4aff74c05c51ed673ff4731d21604f971`, and post-closeout main push #2387 passed.
- Stale #577 is closed unmerged; its useful durable-equipment→combat outcome is superseded by the safer LKB-0567 implementation.
- Fresh selector audit after LKB-0567 compared the remaining serious old feature sources. #566/#579 remain a larger persistence-sensitive progression stack; #537/#568/#574 remain a larger procedural-instance stack; #570 remains a smaller independent enemy-navigation reliability/performance candidate.
- Current `EnemyDirectorService.moveStalkerToward` lets every pursuing walker whose repath timer expires independently call `PathfindingService:CreatePath`. `EnemyConfig.Navigation` has no per-evaluation path-computation cap, and current main has no `EnemyNavigationScheduler` owner/helper.
- Therefore **LKB-0321 is the sole BUILDING ticket**. Canonical mapping: workstream 13 **Enemy Navigation & Targeting** × dimension 21 **Performance budget** = LKB-0321.
- Missing manual Studio/device evidence does not block dependency-safe source progression. Runtime facts that require Studio remain UNMEASURED until actually observed.

## NOW

### 1. Bound and fairly allocate enemy pathfinding work — LKB-0321

Use stale PR #570 only as source evidence. Reconcile **only** the still-valid per-evaluation navigation budget/fairness capability onto fresh current main.

Required outcome:

- add an explicit small positive `EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation` budget with fail-fast authored-config validation;
- extract/use a deterministic pure scheduler that receives eligible enemy IDs, a fairness cursor, and the maximum grants, then returns a bounded round-robin grant set and next cursor;
- build one evaluation-scoped path grant budget before the director iterates living enemies;
- only granted pursuing enemies may call `PathfindingService:CreatePath` / `ComputeAsync` during that evaluation;
- enemies not granted expensive path work must still receive bounded direct `Humanoid:MoveTo` pursuit intent rather than freezing;
- reset scheduler fairness state on service stop/replay lifecycle;
- preserve the existing single heartbeat/evaluation owner, combat authority, targeting resolver, spawn pressure, special enemies, boss behavior, durable systems, and presentation owners;
- add focused deterministic scheduler tests and a source/integration audit proving the configured budget gates all path computation.

Scope exclusions for this ticket:

- do **not** import #570's stuck-progress/recovery state machine; that is a separate failure-fallback concern if later evidence justifies it;
- do not change ordinary archetype definitions, jump capability, pursuit cadence, target selection, attack behavior, spawn cadence, boss/special-enemy logic, or unrelated comments/refactors;
- do not weaken current config validation to match stale #570;
- do not add per-enemy connections, timers, or parallel navigation owners.

Exit gate:

1. implementation starts from the published LKB-0321 claim baseline and contains only the smallest coherent navigation-budget diff;
2. deterministic fixture proves grant count never exceeds the configured cap and round-robin fairness advances across evaluations;
3. source/integration audit proves `CreatePath` is gated by the evaluation grant and ungranted enemies keep direct movement fallback;
4. Full Atlas validation is green on the exact final PR head;
5. merge and require green main push validation;
6. fresh current-main/#570 overlap audit determines whether #570 has remaining unique work in other dimensions rather than closing it prematurely;
7. verify LKB-0321 and release the shared claim through a validated coordination transaction.

### 2. Keep repository/documentation truth coherent

When this capability materially changes development coverage or creates a reusable performance seam, update only the canonical coverage/efficiency registries and regenerate their views. Do not create another status system.

## Candidate interpretation

### Active source evidence

- **#570 — enemy navigation scheduling/stuck recovery.** LKB-0321 adopts only its deterministic fair path-budget idea. Stuck recovery and any other surviving unique work remain candidate material, not implicit scope.

### Deferred capability stacks

- **#566 / #579** — durable progression/stats; larger persistence-sensitive stack, with #579 stacked on #566.
- **#537 / #568 / #574** — seeded/procedural instance stack; broader runtime/world-generation capability.

Older presentation/test/refactor branches such as #535, #547, #550, #559 and #560 are provenance only unless a future selected capability directly needs still-unique work from them.

## NEXT

After LKB-0321 is VERIFIED and the shared claim is released:

1. refresh current main and all open feature PRs;
2. re-audit #570 for any surviving unique failure-fallback work separately from the completed performance-budget dimension;
3. re-rank progression, procedural-instance, enemy-navigation follow-up, and any newly discovered concrete defects;
4. activate exactly one smallest matching backlog ticket through a new atomic coordination transaction;
5. continue the same implement → validate → merge → post-merge verify → closeout → select loop.

Patch 0.8 remains an available planned queue but is not automatically selected. Patch 0.9 and RC 1.0 remain later planned queues unless explicitly activated.

## Development coverage lens

For broad audits/refactors, route through:

```text
LK concern(s)
→ canonical engine(s)
→ real existing owner
→ dependency/PR overlap
→ smallest coherent implementation
→ risk-tier validation
→ measurement/evidence
→ coverage update if materially changed
→ merge
```

Coverage gaps are candidates, not automatic priority.

## Manual evidence backlog

Manual Studio/device/play work is separate from NOW/NEXT. Record only what was actually measured. Reproducible defects discovered there may become source-work candidates; unrun facts remain UNMEASURED.

## WIP rule

- one active implementation PR for the current capability/lane;
- at most one additional non-overlapping feature PR only when the first is externally blocked;
- open PR count is not the execution queue;
- inspect freshness/overlap before starting;
- merge only after applicable automated validation is green;
- update NOW/NEXT whenever execution truth materially changes.
