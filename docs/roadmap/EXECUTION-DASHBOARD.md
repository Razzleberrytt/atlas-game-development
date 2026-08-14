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

- **Batch 7 (#61–#63, #70) is DONE:** every per-player service was surveyed for a durable path and the result recorded in `../production/PATCH-0.7-DURABLE-VALUE-DOMAINS.md`. Everything durable is account-scoped; everything in memory is run- or session-scoped by design. Progression snapshots now carry an identity derived from the ledger they were projected from, so a stale projection is detectable. **#64–#69 are DEFERRED, not done** — they would create a second authority over derived facts, or a currency no gameplay reads.

- **Batch 8 (#71–#80) is DONE:** a deterministic fault matrix interrupts reward writes, dismantle writes, and migrations mid-flight, crashes a server before and after the durable commit, hops one player across five servers, and shuts down both cleanly and during a partial storage outage — asserting each time that durable truth wins over stale process memory. `InventoryLiveService.destroy` now returns the shutdown summary, so a partial outage is distinguishable from a clean close.

- **Batch 9 (#81–#83, #85, #89, #90) is DONE:** deterministic one-shot fault injection for reads, commits, and transform retries; a reason-classification audit that reads the reasons out of the sources rather than a hand-kept list; a pure record invariant checker for duplicate items, missing ledgers, invalid equips and ownership drift; and a `persistence-hardening` validation profile. **#84, #86–#88 are DEFERRED, not done.**

- **Batch 10 (#91–#100) is DONE:** `docs/production/PATCH-0.7-ACCEPTANCE-MATRIX.json` carries 40 rows — 34 satisfied and bound to 16 automated fixtures, 6 deferred with recorded reasons. `scripts/validate_patch_07_acceptance.py` runs inside `validate.py` and checks the binding in both directions, so a row cannot claim a fixture that does not exist or that nothing runs, and the profile cannot run a fixture no row claims.

## Patch 0.7 status

**AUTOMATED ACCEPTANCE COMPLETE for the 34 satisfied rows. Not complete as 100/100.**

86 of the 100 ranked tasks are implemented and covered. **14 are deferred, not done**, each with its reason recorded in the backlog and the matrix: a durable overflow bucket (#54–#57) for a capacity limit the game does not have, separate durable progression/unlock/currency records (#64–#69) that would be a second authority over derived facts or a currency no gameplay reads, and latency injection, diagnostic counters, and randomised stress (#84, #86–#88) that would add surfaces nothing consumes.

Calling that 100/100 would misreport what was built. The durable-state work Patch 0.7 set out to harden is done and machine-checked; the deferred rows are recorded as open design decisions rather than closed ones.

## Patch 0.8 — Co-op / Social / Session

Ranked task authority: `PATCH-0.8-100-TASK-ROI-BACKLOG.md`. Rows #51–#100 are deliberately not pre-written: Patch 0.7 showed that enumerating fifty rows in advance produces speculative work, so they will be ranked from what Batches 1–5 actually expose.

Patch 0.8's exit question — *is playing with other people easier, clearer and more fun?* — is experiential and cannot be automated. The backlog ranks the authority, lifecycle, and session-correctness half, where real defects live. Feel and readability stay **UNMEASURED**.

- **Batch 1 (#1–#10) is DONE:** two live defects fixed in the launch sequence. `launchInFlight` is a latch with no `pcall` anywhere in the sequence, so any error between setting it and the end left it set for the life of the server — the lobby could never launch again. And mission/horde pressure were armed *before* the expedition started, so a rejected launch left both running with no run to belong to, with no disarm on either owner. Lobby lifecycle is now covered end to end, including the case where a member leaving a launch-pending party could have stranded the lobby.

## NOW

**Execute Patch 0.8 Batch 2, tasks #11–#20, from `PATCH-0.8-100-TASK-ROI-BACKLOG.md`.**

Batch 2 covers session membership and reconnect.

Manual play/Studio evidence for experiential facts remains **UNMEASURED** and does not hold source progression.

Required merge gate:

```bash
python scripts/validate.py full
```

CI equivalent is accepted as the canonical automated result.

## NEXT

After Batch 2 is automated-green and merged:

1. mark #81–#90 DONE;
2. activate #91–#100;
3. bind the machine-readable acceptance matrix;
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
| 7 | 61–70 | durable progression/currency/unlocks | DONE (64–69 deferred) |
| 8 | 71–80 | disconnect/rejoin/crash/shutdown correctness | DONE |
| 9 | 81–90 | automated chaos + diagnostics | DONE (84, 86–88 deferred) |
| 10 | 91–100 | machine-readable Patch 0.7 acceptance | DONE |

## Manual evidence backlog

Manual Studio/device/play work is optional and separate from NOW/NEXT. If run, record only what was actually measured. If it reveals a reproducible defect, promote that defect into the ranked source queue. If it is not run, leave the experiential fact **UNMEASURED** and continue development.

## WIP rule

- one active implementation PR for the current 10-task batch;
- do not duplicate open work;
- merge only after automated validation is green;
- immediately activate the next 10 tasks after a successful merge.