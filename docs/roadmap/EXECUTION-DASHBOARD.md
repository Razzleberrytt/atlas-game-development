# Atlas — Execution Dashboard v1.21

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-13  
**Purpose:** answer quickly what is true, what is NOW, and what comes NEXT.

Execution precedence:

1. `AUTOMATED-FIRST-EXECUTION-POLICY.md` — cadence and verification authority;
2. `PATCH-0.7-100-TASK-ROI-BACKLOG.md` — current Patch 0.7 task authority;
3. `PLAYABLE-MVP-PATCH-EXECUTION.md` — patch goals/product intent;
4. `MASTER-ROADMAP.md` — long-range destination inventory.

Older manual Studio/device/play gates are historical evidence instructions, not scheduling authority.

## Current truth

- MVP 0.1 and Patches 0.2–0.6 have substantial source implementation already merged.
- Missing manual play/Studio/device evidence does **not** block source progression.
- Patch 0.6's non-manual micro-update queue is complete through rank 97; its remaining historical UI/manual rows do not occupy execution priority.
- **Patch 0.7 — Durable Persistence + Valuable State Hardening is the current source patch.**
- Patch 0.7 entered the 100-task ranked program with an existing baseline: one canonical live inventory owner, symmetric resident-record release, committed-update lease decisions, supported-schema migration/recovery invariants, and no-blank-overwrite protection after exhausted reads.
- **Batches 1–2 (#1–#20) are DONE.** Batch 1: canonical storage resolution now distinguishes `StudioVolatile`, `LiveDurable`, and `LiveUnavailable`, with deterministic coverage for isolation, exact durable-store binding, unavailable-store rejection, and malformed inputs.
- Manual facts such as game feel, visual readability, real-device ergonomics, live memory/performance, or publishing behavior may remain **UNMEASURED** without stopping source work.

- **Batch 2 (#11–#20) is DONE:** the live adapter now selects its store through that policy with no duplicate resolution logic, a live store that cannot be opened fails closed instead of falling soft to volatile, and storage outcomes are explicit — `Found`/`Missing`/`Failed` reads and `Committed`/`Failed` writes carrying committed value identity. Persistence branches on read status before normalizing, so an outage returns `LoadFailed` rather than borrowing `SaveFailed`.

- **Batch 3 (#21–#30) is DONE:** lease records are structurally validated, an unparseable rival lease is honoured rather than silently overwritten, records carry an owner generation that survives a recycled JobId, and shutdown release now aggregates its outcome with bounded retry so a lease that survives shutdown is observable instead of invisible.

- **Batch 4 (#31–#40) is DONE:** schema 4 records per-grant content identity, so a repeated grant id reads as `RewardAlreadyApplied` only when the content matches and as `RewardGrantConflict` when it does not. Equip is proven idempotent under exact replay, dismantle replay survives release/rejoin, neither mutation erases the other's replay protection, and durable ledgers are bounded where the bound can still be reported.
- **A live defect was found and fixed alongside Batch 4:** `OperativeProgressionResolver` iterated the durable grant ledger for values, but the ledger is a set keyed by grant id, so every non-empty ledger was rejected as malformed and operative rank/unlocks were dead for exactly the players who had earned something. Both owners' fixtures were green because the resolver's fed it a shape persistence never writes.

- **Batch 5 (#41–#50) is DONE:** migrations are authored as single-version steps and planned rather than assumed, the steps taken are reported, an unparseable record is copied to a derived quarantine key and never rewritten, load failures are classified transient vs corrupt, and the migration write-back refuses to clobber a record that changed since the read.

- **Batch 6 (#51–#53, #58–#60) is DONE:** durable records carry a byte budget under the DataStore ceiling, estimated deterministically and pessimistically, and an oversized write is refused before submission rather than failing silently at the platform limit forever after. **#54–#57 are DEFERRED, not done** — an overflow bucket presupposes a durable inventory capacity the game does not have.

## NOW

**Execute Patch 0.7 Batch 7, tasks #61–#70, from `PATCH-0.7-100-TASK-ROI-BACKLOG.md`.**

Batch 7 expands valuable durable state safely.

Required merge gate:

```bash
python scripts/validate.py full
```

CI equivalent is accepted as the canonical automated result.

## NEXT

After Batch 2 is automated-green and merged:

1. mark #61–#70 DONE;
2. activate #71–#80;
3. harden disconnect/rejoin/crash/shutdown correctness;
4. continue in exact 10-task batches through all 100 Patch 0.7 tasks.

A concrete data-loss, duplication, authority, migration, or deterministic validation defect may preempt the queue. Missing manual testing may not.

## Patch 0.7 execution map

| Batch | Tasks | Focus | Status |
|---|---:|---|---|
| 1 | 1–10 | storage resolution policy | DONE |
| 2 | 11–20 | integrate fail-closed storage + explicit outcomes | DONE |
| 3 | 21–30 | session ownership + lease robustness | DONE |
| 4 | 31–40 | valuable mutation idempotency | DONE |
| 5 | 41–50 | migration, quarantine, recovery | DONE |
| 6 | 51–60 | capacity, overflow, retention | DONE (54–57 deferred) |
| 7 | 61–70 | durable progression/currency/unlocks | ACTIVE |
| 8 | 71–80 | disconnect/rejoin/crash/shutdown correctness | queued |
| 9 | 81–90 | automated chaos + diagnostics | queued |
| 10 | 91–100 | machine-readable Patch 0.7 acceptance | queued |

## Manual evidence backlog

Manual Studio/device/play work is optional and separate from NOW/NEXT. If run, record only what was actually measured. If it reveals a reproducible defect, promote that defect into the ranked source queue. If it is not run, leave the experiential fact **UNMEASURED** and continue development.

## WIP rule

- one active implementation PR for the current 10-task batch;
- do not duplicate open work;
- merge only after automated validation is green;
- immediately activate the next 10 tasks after a successful merge.