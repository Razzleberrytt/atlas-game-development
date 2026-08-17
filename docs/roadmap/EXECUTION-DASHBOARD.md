# Atlas — Execution Dashboard v1.30

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-17  
**Main baseline audited:** `ddf3a13f0fac07a4538e371a8adaf143f56c8ede`  
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
- **LKB-0567 is VERIFIED and its claim is RELEASED.** PR #660 passed Full Atlas #2384, merged as `834b0c41be786aeddb4e17cde05fe9b0ca38cf16`, and main push #2385 passed. Durable equipment now drives combat through server-owned inventory/config authority without reopening persistence ownership.
- **LKB-0321 is VERIFIED.** PR #663 passed Full Atlas #2398 on exact final head `0a27c248c0118e006dfe252fda534e716f4d3aa0`, squash-merged as `ddf3a13f0fac07a4538e371a8adaf143f56c8ede`, and post-merge main push #2399 passed.
- LKB-0321 now bounds expensive walker path computation with authored `EnemyConfig.Navigation.MaximumPathComputationsPerEvaluation`, one deterministic lexical round-robin `EnemyNavigationScheduler`, and direct `Humanoid:MoveTo` fallback for pursuers that do not receive an expensive path grant.
- Exhaustive LKB-0321 review corrected two scheduler defects before merge: a despawned fairness cursor now resumes at its first lexical successor instead of repeatedly favoring low IDs, and the 1-based wrap formula now grants the actual intended first entity instead of the last entity.
- Fresh #570 overlap audit shows its path-budget/fairness work is superseded by LKB-0321. #570 still preserves distinct stuck-detection/recovery and jump-policy ideas; those are separate failure-fallback candidate material, not implicit authorization.
- Current main still has no `CharacterProgression` / durable `TotalXP` owner from the old #566 stack and no `ProceduralInstanceGenerator` / `InstanceLayoutValidator` owner from the old #568 stack. Both therefore remain genuinely distinct candidates rather than already-landed duplicates.
- Missing manual Studio/device evidence does not block dependency-safe source progression. Runtime facts that require Studio remain UNMEASURED until actually observed.

## NOW

### 1. Fresh current-main capability selector — no BUILDING ticket

LKB-0321 is complete. The shared backlog claim is released by this closeout transaction; do **not** start implementation work until the selector publishes a new atomic claim.

Refresh and compare the smallest coherent surviving candidate capabilities against current main:

- #570 surviving enemy-navigation stuck-detection/recovery only — reliability/failure-fallback scope, separate from the completed performance budget;
- #566 / #579 durable character progression — high player-loop value but persistence/schema-sensitive and therefore higher blast radius;
- #537 / #568 / #574 procedural-instance stack — high replayability value but broader runtime/world-generation scope;
- any new concrete reproducible defect discovered on current main.

Selection rule: rank by player value, dependency readiness, smallest coherent diff, ownership clarity, current-main compatibility, and validation risk. Old PR age/open state does not grant execution authority.

### 2. Keep repository/documentation truth coherent

When a selected capability materially changes development coverage or creates a reusable seam, update only the canonical coverage/efficiency registries and regenerate their views. Do not create another status system.

## Candidate interpretation

### #570 — surviving source evidence only

LKB-0321 supersedes #570's navigation budget, scheduler-fairness, and budget-gating purpose. The only meaningful distinct material still surviving is bounded stuck/progress recovery plus related jump-policy changes. Re-audit those against current behavior before any claim; do not reopen path-budget work under a new ticket.

### #566 / #579 — durable progression

Potentially strong player-loop value: durable level/XP progression and authoritative expedition rewards. However the old stack modifies the existing durable account record and was authored before substantial Patch 0.7 persistence hardening. A fresh implementation must first prove the current account schema/lease/migration seams it would extend, and must not copy stale persistence internals.

### #537 / #568 / #574 — procedural instances

Potentially strong replayability value: seeded room assembly/layout/validation and later instance runtime integration. The old stack is broader than the navigation ticket and must be decomposed from current main rather than force-merged. Prefer a pure deterministic generation/validation slice before runtime authority expansion if this capability wins the selector.

Older presentation/test/refactor branches such as #535, #547, #550, #559 and #560 are provenance only unless a future selected capability directly needs still-unique work from them.

## NEXT

1. validate and merge this LKB-0321 coordination closeout;
2. require green post-closeout main push validation;
3. refresh current main plus the surviving candidate branches/PRs;
4. choose exactly one smallest high-value capability and map it to the canonical LKB workstream × dimension ID;
5. publish `status.csv`, `active_claim.json`, and this dashboard atomically for the new claim;
6. implement only that claimed capability from fresh main;
7. repeat implement → validate → merge → post-merge verify → closeout → select.

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
