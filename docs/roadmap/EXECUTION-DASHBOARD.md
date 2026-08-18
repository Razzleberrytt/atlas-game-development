# Atlas — Execution Dashboard v1.32

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-17  
**Decision baseline audited:** `5072f1f989df67e2b522d18c2d795f23657d3782`  
**Purpose:** answer quickly what is true, what is NOW, what may proceed, and what comes NEXT.

## Precedence

1. Accepted runtime evidence and current Roblox platform behavior — truth about what actually works.
2. [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) — product identity and design conflict resolution.
3. [`STATIC-PLAYABLE-EVIDENCE-GATE.md`](STATIC-PLAYABLE-EVIDENCE-GATE.md) — currently activated product-evidence gate.
4. [`PARALLEL-DEVELOPMENT-POLICY.md`](PARALLEL-DEVELOPMENT-POLICY.md) — dependency-safe eligibility, not unlimited WIP.
5. [`AUTOMATED-FIRST-EXECUTION-POLICY.md`](AUTOMATED-FIRST-EXECUTION-POLICY.md) — normal automated execution cadence and verification authority.
6. This dashboard — current daily status and NOW/NEXT selection.
7. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — player-facing patch goals/product intent.
8. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — long-range destination inventory.
9. Patch-specific acceptance/backlog documents — active only when this dashboard selects that patch/capability.

The static playable gate is an **explicit product-evidence gate**, not ordinary pending Studio verification. While it is NOW, normal source-through cadence does not authorize unrelated expansion merely because the LKB mutex is unlocked.

## Current truth — 2026-08-17

- Living Kingdoms remains a Roblox/Rojo repository-first codebase; `games/living-kingdoms/src/` is gameplay-authoritative source.
- The current product authority says to build the smallest coherent playable result, preserve canonical owners, and measure what source cannot prove.
- The patch path defines **MVP 0.1 as the first complete repeatable run** and procedural/systemic replayability as a later layer.
- Existing source already contains substantial camera, combat, enemy, mission, loot, progression, persistence, Main World, and presentation systems. The next move is **not** to rebuild those systems into a separate prototype.
- LKB-0682, LKB-0033, LKB-0567, and LKB-0321 remain VERIFIED from their recorded validation/merge evidence.
- LKB-0481 procedural spatial resolution was activated on baseline `5072f1f989df67e2b522d18c2d795f23657d3782` and accumulated meaningful unmerged candidate work in PR #666.
- PR #666 currently contains 19 commits / 9 changed files and preserves useful deterministic cardinal planner/validator/generator work, but it is not merged and its latest Atlas validation on head `6acbe11fd2e95c664d85e941c28f7570d5262413` failed.
- The fixed current-main spatial path is sufficient to ask the higher-value product question: whether one complete run is readable, satisfying, and worth replaying.
- Therefore LKB-0481 is **DEFERRED, not discarded**. Its branch/PR remains provenance/candidate implementation for later re-audit.
- The shared LKB implementation mutex is **UNLOCKED** while the product evidence gate runs. That unlocked state does not authorize unrelated candidate work.

## NOW

### 1. Static playable evidence gate — first complete repeatable run

Run the existing canonical game loop on a fixed/deterministic layout and collect evidence against [`STATIC-PLAYABLE-EVIDENCE-GATE.md`](STATIC-PLAYABLE-EVIDENCE-GATE.md).

This gate deliberately measures the parts source inspection cannot prove:

- boot/reset/replay lifecycle in the actual engine;
- movement/combat responsiveness and readability;
- whether a player understands threats and meaningful damage/death;
- whether launch, route, objective, result, return, and replay flow are understandable without developer coaching;
- whether current loot/reward/build outcomes are legible and meaningful;
- whether first-time testers show an unprompted desire for another attempt.

### Test rule

Use current canonical owners. Do **not** build a second camera, combat, enemy, mission, loot, inventory, persistence, expedition, or world path to manufacture the slice.

Use the smallest current fixed route/configuration that exercises the loop. If the run fails, classify the exact measured failure before editing code.

### Product gates

1. **Boot/reset:** repeated start → result/failure → return/reset → restart does not accumulate broken state.
2. **Combat:** controls, threats, hits, damage, failure, and recovery are understandable enough to play without narration.
3. **Complete fixed expedition:** a first-time tester can launch, progress, reach a legitimate result/failure, return, and see how to replay.
4. **Reward/replay:** the player understands the outcome/reward and has a clear reason/action to try again.

Directional repeat signal: **at least 50% of first-time external testers who reach a legitimate result choose another attempt without prompting**. For small cohorts, record raw counts and treat the threshold as a product-decision signal, not statistical proof.

### Allowed work during NOW

- evidence setup/documentation needed to run the gate;
- a focused source fix for a reproducible gate failure;
- narrow build/runtime repair required to make the gate runnable;
- independent security, data-integrity, or concrete safety fixes that preempt product work.

### Explicitly not automatic NOW/NEXT

- procedural spatial expansion;
- multi-run procedural-instance ownership;
- additional dungeon themes/regions;
- large Main World expansion;
- generic hardening without a measured defect;
- broad class/crafting/economy/content expansion;
- guild/housing/trading/PvP/raid breadth;
- monetization.

### Exit gate

**PASS:** the fixed run is coherent enough to resume normal source ranking. Procedural work becomes eligible again but is not automatically selected.

**FAIL:** choose the single highest-leverage measured failure, map it to the existing canonical owner, authorize the smallest focused FIX, and rerun the affected gate.

**UNKNOWN:** improve evidence setup only. Do not turn uncertainty into feature work.

## LKB-0481 disposition

LKB-0481 is deferred because the next information bottleneck is player/runtime evidence, not route-layout variety.

Preserve:

- branch `lk/LKB-0481-procedural-spatial-resolution`;
- PR #666 history/diff;
- the deterministic planner/validator/generator ideas that remain current-compatible.

Do not merge the branch solely because work was invested. Do not delete or reimplement the work. After the static gate passes, re-audit it against then-current `main` and the measured player-value queue.

## NEXT

After the static gate produces evidence:

1. if a concrete failure exists, activate the smallest canonical-owner FIX and only that FIX;
2. validate/merge the fix at its truthful risk tier;
3. rerun the affected evidence gate;
4. when the fixed run passes, re-run the selector across combat/readability, loot/build replayability, co-op/session value, Main World wrapper needs, procedural replayability, and other current candidates;
5. select the smallest highest-player-value dependency-safe capability rather than automatically advancing a patch number.

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

## Manual evidence rule

Ordinary pending Studio/device evidence remains non-blocking by default elsewhere in the roadmap.

**Exception:** this dashboard has explicitly activated the static playable evidence gate as current product work. Until it passes/fails with usable evidence, agents must not bypass it by selecting unrelated source expansion.

A reproducible defect discovered during the gate immediately becomes eligible source work. Once the gate exits, normal automated-first cadence resumes.

## WIP rule

- no unrelated LKB source ticket while the static evidence gate is the unresolved NOW item;
- one active implementation PR when a measured gate failure authorizes a FIX;
- at most one additional non-overlapping feature PR only when the first is externally blocked and the dashboard explicitly permits it;
- open PR count is not the execution queue;
- inspect freshness/overlap before starting;
- merge only after applicable automated validation is green;
- update NOW/NEXT whenever execution truth materially changes.

## Coordinator decision rule

> **Prove one understandable, satisfying, repeatable run before multiplying it.**

The repo should scale a game that players have shown is worth replaying, not use procedural breadth to postpone discovering whether the underlying loop works.
