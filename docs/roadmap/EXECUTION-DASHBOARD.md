# Atlas — Execution Dashboard v1.26

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-17  
**Main baseline audited:** `310ba09c6a79771739228ee1b749824883c822e2`  
**Purpose:** answer quickly what is true, what is NOW, what may proceed, and what comes NEXT.

## Precedence

1. Accepted runtime evidence and current Roblox platform behavior — truth about what actually works.
2. [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) — product identity and design conflict resolution.
3. [`PARALLEL-DEVELOPMENT-POLICY.md`](PARALLEL-DEVELOPMENT-POLICY.md) — which dependency-safe lanes may proceed; this is **eligibility**, not unlimited WIP.
4. [`AUTOMATED-FIRST-EXECUTION-POLICY.md`](AUTOMATED-FIRST-EXECUTION-POLICY.md) — automated execution cadence and verification authority.
5. This dashboard — current daily status and NOW/NEXT selection.
6. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — player-facing patch goals/product intent.
7. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — long-range destination inventory.
8. Patch-specific acceptance/backlog documents — active only when the dashboard selects that patch/capability.

For documentation-authority routing, use [`../README.md`](../README.md). Historical Studio/device/play gates are evidence instructions, not source-work scheduling authority. Experiential facts remain **UNMEASURED** until actually tested.

## Current truth — 2026-08-17

- Atlas/Living Kingdoms is a **Roblox/Rojo repository-first codebase**. `games/living-kingdoms/src/` remains gameplay-authoritative source; the operation and dedicated Main World use their canonical Rojo project mappings.
- **Patch 0.7 durable persistence + valuable-state hardening remains automated-acceptance complete for every non-deferred row.** It implemented **86 / 100** ranked tasks. The remaining 14 are explicit deferrals, not hidden incompletion:
  - #54–#57 — overflow storage without a real inventory-capacity requirement;
  - #64–#69 — duplicate durable authorities / currency without a gameplay consumer;
  - #84, #86–#88 — diagnostic/latency/randomized stress surfaces without a current consumer.
- Patch 0.7's machine-readable detailed proof remains `../production/PATCH-0.7-ACCEPTANCE-MATRIX.json`.
- Main World route-resilience ticket **LKB-0682 is VERIFIED**. PR #649 reconciled the still-unique northwest bypass from stale #620 onto current main, passed Full Atlas validation #2286, and merged as `c9d23a7b4c8b892dd3d7d16e86684fa69882f7c8`. Post-merge main push validation #2287 passed. Rooted road-failure evidence improved roads 7→9, edges 7→10, chokepoints 2→1, bridges 3→1; worst bridge failure improved from 6 districts / 4 roads lost to 0 districts / 1 road, and the prior worst non-root articulation failure disappeared. PR #620 is closed unmerged as superseded.
- **LKB-0033 is VERIFIED and the bounded-dependency maintenance mini-lane is CLOSED.** PR #656 exhaustively bounded the remaining startup/dependency waits, passed Full Atlas validation #2353, and squash-merged as `310ba09c6a79771739228ee1b749824883c822e2`. Post-merge main push validation #2354 passed.
- `ClientBootstrapDependencyWaitSourceAudit.test.luau` now enforces zero untimed `WaitForChild` calls under the canonical client source tree. `ServerBootstrapDependencyWaitSourceAudit.test.luau` reports no unbounded network dependency waits across canonical server/shared/Main World source. The fresh overlap audit found no surviving open LKB-0033 implementation; stale #646 and diagnostic #652 are closed unmerged.
- Do **not** manufacture another bounded-wait ticket merely to keep that mini-lane alive. A new reproducible dependency-stall defect may reopen the concern through normal coordination.
- Missing manual Studio/device evidence does not block dependency-safe source progression. A reproducible runtime, authority, persistence, data-loss, security, or deterministic-validation defect does.
- The development coverage system preserves `LK-001`–`LK-300` as a machine-readable concern ontology in `../../config/coverage/living-kingdoms-development.json`, with generated taxonomy/atlas/report views. It is **not** a second roadmap and does not authorize one module per concern.

## NOW

### 1. Audit older feature candidates and explicitly select one next player-facing capability

There is currently **no BUILDING implementation ticket** after LKB-0033 verification. Perform the coordination selector before starting new implementation work:

1. inspect current `main` and the full open-PR inventory;
2. compare each older candidate with current main for unique surviving work, superseding merges, ownership drift, dependency stacks, and conflicts;
3. rank viable candidates by player-facing/reliability ROI, dependency readiness, current-main compatibility, overlap risk, and measurable exit criteria;
4. explicitly activate exactly **one** capability here;
5. map that capability to the smallest coherent Living Kingdoms backlog ticket, claim it as the sole BUILDING row, and reconcile useful old work onto a fresh current-main branch rather than blindly merging stale branches.

Patch 0.8 remains an available planned queue, not the default. Do not activate it merely because Patch 0.7 and the bounded-wait mini-lane are closed.

### 2. Keep repository/documentation truth coherent

The 300-area development taxonomy, Development Atlas, coverage report, documentation router, and coverage validator are the canonical cross-system gap/audit framework. When a coherent implementation materially changes coverage, update the machine registry and regenerate the views; do not create another independent status document.

## Open-PR interpretation

Open PR count is **not** the execution queue. Age/open state does not grant authority.

### Older feature candidates requiring fresh deliberate audit

- **#566 / #578 / #579** — progression stack/sync work;
- **#577** — authoritative inventory/equipment activation;
- **#568 / #574** — procedural-instance work;
- **#570** — enemy navigation/combat framework;
- older presentation/test/refactor PRs such as #535, #537, #547, #550, #559 and #560.

For every candidate: compare it with current main, inspect superseding merges and ownership drift, resolve stack dependencies, identify the still-unique player-facing outcome, and reject or close obsolete work. A viable candidate still requires explicit dashboard activation before implementation begins.

### Closed/superseded bounded-wait sources

- **#646** — RPG menu network waits; closed unmerged after its useful work was reconciled through later LKB-0033 checkpoints.
- **#652** — diagnostic client network-child audit; closed unmerged by design after exposing the next concrete wait family.
- **#656** — exhaustive LKB-0033 closeout; merged and VERIFIED after #2353/#2354.

### Superseded Main World candidate

- **#620** — northwest route redundancy. Closed unmerged after current-main PR #649 implemented and verified the still-valid geometry under LKB-0682.

## NEXT

After the candidate audit selects one capability:

1. update this dashboard to name that capability as the sole active implementation lane;
2. claim exactly one smallest matching backlog ticket in `backlog/living-kingdoms/status.csv`;
3. create/reconcile a fresh current-main implementation branch;
4. implement only the still-unique scoped outcome;
5. pass the applicable full validation gate, merge, require post-merge evidence, and mark VERIFIED only after the current-main audit is clean;
6. repeat this selector only after the active ticket leaves BUILDING.

Patch 0.8 remains an available planned queue via `PATCH-0.8-ACCEPTANCE.md` + `PATCH-0.8-100-TASK-HARDENING-BACKLOG.md`, but **it is not automatically selected merely because Patch 0.7 closed**. Patch 0.9 and RC 1.0 remain later planned queues unless explicitly activated.

Selection criteria: player-facing/reliability ROI, dependency readiness, fresh current-main compatibility, no overlap with open work, no duplicate authority, and measurable exit criteria.

## Development coverage lens

For broad audits, refactors, or “exhaustively improve the game” requests:

```bash
python scripts/development_coverage.py report
python scripts/development_coverage.py atlas
```

Then route work through:

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

Coverage gaps are candidates, not automatic priority. Player value, dependency removal, current defects, and the dashboard remain the execution tie-breakers.

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

Detailed batch narratives belong in the Patch 0.7 backlog, acceptance matrix, production evidence, and Git history—not this daily dashboard.

## Manual evidence backlog

Manual Studio/device/play work is separate from NOW/NEXT. If run, record only what was actually measured. If it reveals a reproducible defect, promote that defect into the active source queue. If it is not run, leave the experiential fact **UNMEASURED** and continue dependency-safe source work.

## WIP rule

- one active implementation PR for the current capability/lane;
- at most one additional non-overlapping feature PR only when the first is externally blocked;
- parallel-development policy means other lanes are **eligible**, not that all eligible lanes should have simultaneous PRs;
- inspect open PRs for freshness and overlap before starting;
- merge only after the applicable automated validation is green;
- after a successful merge, update NOW/NEXT when execution truth materially changes rather than leaving stale instructions behind.
