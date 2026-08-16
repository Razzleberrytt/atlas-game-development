# Atlas — Execution Dashboard v1.22

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-15  
**Purpose:** answer quickly what is true, what is NOW, and what comes NEXT.

## Precedence

1. [`AUTOMATED-FIRST-EXECUTION-POLICY.md`](AUTOMATED-FIRST-EXECUTION-POLICY.md) — execution cadence and verification authority.
2. This dashboard — current daily status and NOW/NEXT selection.
3. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — player-facing patch goals/product intent.
4. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — long-range destination inventory.
5. Patch-specific acceptance/backlog documents — active only when that patch is selected.

Product-direction conflicts are resolved by [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md).

Historical Studio/device/play gates are evidence instructions, not source-work scheduling authority. Experiential facts remain **UNMEASURED** until actually tested.

## Current truth

- Atlas/Living Kingdoms has substantial playable source implementation across MVP 0.1 and Patches 0.2–0.7.
- **Patch 0.7 durable persistence + valuable-state hardening is automated-acceptance complete for every non-deferred row.**
- Patch 0.7 implemented **86 / 100** ranked tasks. **14 are intentionally DEFERRED**, not silently complete:
  - #54–#57 — overflow storage without a real inventory-capacity requirement;
  - #64–#69 — duplicate durable authorities / currency without a gameplay consumer;
  - #84, #86–#88 — diagnostic/latency/randomized stress surfaces without a current consumer.
- Patch 0.7's machine-readable acceptance matrix remains the canonical detailed proof: `../production/PATCH-0.7-ACCEPTANCE-MATRIX.json`.
- Missing manual Studio/device evidence does not block dependency-safe source progression. A reproducible runtime, authority, persistence, data-loss, security, or deterministic-validation defect does.
- `games/living-kingdoms/src/` remains the only gameplay-authoritative Living Kingdoms source tree. Studio imports are preservation/reconciliation input, never parallel runtime authority.

## NOW

**Patch 0.7 is closed for automated source execution. Select one next coherent patch before starting broad feature expansion.**

Until that selection is explicit, allowed work is limited to high-confidence maintenance that improves the existing baseline without inventing product scope: concrete defect repair, authority-drift repair, validation/tooling reliability, organizational simplification, and removal of stale/duplicated repository truth.

Required merge gate for gameplay-affecting or repository-wide changes:

```bash
python scripts/validate.py full
```

CI equivalent is the canonical automated result.

## NEXT

Choose exactly one next patch/queue from its current acceptance and ranked backlog, then make that selection explicit here before implementation begins.

Available planned queues include:

- Patch 0.8 — use `PATCH-0.8-ACCEPTANCE.md` + `PATCH-0.8-100-TASK-HARDENING-BACKLOG.md`;
- Patch 0.9 — use `PATCH-0.9-ACCEPTANCE.md` + `PATCH-0.9-100-TASK-HARDENING-BACKLOG.md` + `PATCH-0.9-CONTENT-PIPELINE.md`;
- RC 1.0 — use `RC-1.0-100-TASK-BACKLOG.md` only when release-candidate work is intentionally activated;
- a deferred Patch 0.7 row — only when a new design/gameplay requirement invalidates its recorded deferral reason.

Selection criteria: highest player-facing or reliability ROI, dependency readiness, no overlap with open work, and no creation of a second gameplay authority.

A concrete defect may preempt the selected queue. Missing manual testing alone may not.

## Patch 0.7 closed execution map

| Batch | Tasks | Focus | Status |
| --- | ---: | --- | --- |
| 1 | 1–10 | storage resolution policy | DONE |
| 2 | 11–20 | fail-closed storage + explicit outcomes | DONE |
| 3 | 21–30 | session ownership + lease robustness | DONE |
| 4 | 31–40 | valuable mutation idempotency | DONE |
| 5 | 41–50 | migration, quarantine, recovery | DONE |
| 6 | 51–60 | capacity, overflow, retention | DONE; 54–57 DEFERRED |
| 7 | 61–70 | durable progression/currency/unlocks | DONE; 64–69 DEFERRED |
| 8 | 71–80 | disconnect/rejoin/crash/shutdown correctness | DONE |
| 9 | 81–90 | automated chaos + diagnostics | DONE; 84, 86–88 DEFERRED |
| 10 | 91–100 | machine-readable acceptance | DONE |

Detailed batch narratives, individual fixes, and completed PR history belong in the Patch 0.7 backlog, acceptance matrix, production evidence, and Git history—not this daily dashboard.

## Manual evidence backlog

Manual Studio/device/play work is separate from NOW/NEXT. If run, record only what was actually measured. If it reveals a reproducible defect, promote that defect into the active source queue. If it is not run, leave the experiential fact **UNMEASURED** and continue dependency-safe source work.

## WIP rule

- one active implementation PR per coherent upgrade/patch increment;
- inspect open PRs before starting and do not duplicate work;
- merge only after the applicable automated validation is green;
- after a successful merge, explicitly activate the next coherent increment rather than leaving stale NEXT instructions behind.
