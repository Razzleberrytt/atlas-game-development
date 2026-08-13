# Atlas — Execution Dashboard v1.20

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-13  
**Purpose:** answer quickly what is true, what is NOW, and what comes NEXT.

Execution precedence:

1. `AUTOMATED-FIRST-EXECUTION-POLICY.md` — cadence and verification authority;
2. current patch ranked backlog — task authority;
3. `PLAYABLE-MVP-PATCH-EXECUTION.md` — patch goals/product intent;
4. `MASTER-ROADMAP.md` — long-range destination inventory.

Older manual Studio/device/play gates are historical evidence instructions, not scheduling authority.

## Current truth

- MVP 0.1 and Patches 0.2–0.6 have substantial source implementation already merged.
- Missing manual play/Studio/device evidence does **not** block source progression.
- Patch 0.6's non-manual micro-update queue is complete through rank 97; its remaining historical UI/manual rows do not occupy execution priority.
- **Patch 0.7 — Durable Persistence + Valuable State Hardening is the current source patch.**
- Patch 0.7 already has a strong baseline: one canonical live inventory owner, symmetric resident-record release, committed-update lease decisions, supported-schema migration/recovery invariants, and no-blank-overwrite protection after exhausted reads.
- Manual facts such as game feel, visual readability, real-device ergonomics, live memory/performance, or publishing behavior may remain **UNMEASURED** without stopping source work.

## NOW

**Execute Patch 0.7 Batch 1, tasks #1–#10, from `PATCH-0.7-100-TASK-ROI-BACKLOG.md`.**

Batch 1 hardens the production storage construction boundary so a live DataStore construction outage can never silently downgrade valuable persistence to volatile in-memory state.

Required merge gate:

```bash
python scripts/validate.py full
```

CI equivalent is accepted as the canonical automated result.

## NEXT

After Batch 1 is automated-green and merged:

1. mark #1–#10 DONE;
2. activate #11–#20;
3. implement explicit read/write result contracts and reconciliation;
4. continue in exact 10-task batches through all 100 Patch 0.7 tasks.

A concrete data-loss, duplication, authority, migration, or deterministic validation defect may preempt the queue. Missing manual testing may not.

## Patch 0.7 execution map

| Batch | Tasks | Focus |
|---|---:|---|
| 1 | 1–10 | production storage fail-closed construction |
| 2 | 11–20 | explicit read/write outcomes + reconciliation |
| 3 | 21–30 | session ownership + lease robustness |
| 4 | 31–40 | valuable mutation idempotency |
| 5 | 41–50 | migration, quarantine, recovery |
| 6 | 51–60 | capacity, overflow, retention |
| 7 | 61–70 | durable progression/currency/unlocks |
| 8 | 71–80 | disconnect/rejoin/crash/shutdown correctness |
| 9 | 81–90 | automated chaos + diagnostics |
| 10 | 91–100 | machine-readable Patch 0.7 acceptance |

## Manual evidence backlog

Manual Studio/device/play work is optional and separate from NOW/NEXT. If run, record only what was actually measured. If it reveals a reproducible defect, promote that defect into the ranked source queue. If it is not run, leave the experiential fact **UNMEASURED** and continue development.

## WIP rule

- one active implementation PR for the current 10-task batch;
- do not duplicate open work;
- merge only after automated validation is green;
- immediately activate the next 10 tasks after a successful merge.