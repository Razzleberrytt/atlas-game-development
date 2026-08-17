# Atlas — Execution Dashboard v1.28

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-17  
**Main baseline audited:** `834b0c41be786aeddb4e17cde05fe9b0ca38cf16`  
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
- Main World route-resilience ticket **LKB-0682 is VERIFIED**. PR #649 reconciled the still-unique northwest bypass from stale #620 onto current main, passed Full Atlas validation #2286, and merged as `c9d23a7b4c8b892dd3d7d16e86684fa69882f7c8`. Post-merge main push validation #2287 passed.
- **LKB-0033 is VERIFIED and the bounded-dependency maintenance mini-lane is CLOSED.** PR #656 passed Full Atlas validation #2353 and merged as `310ba09c6a79771739228ee1b749824883c822e2`; closeout PR #657 released the shared backlog mutex. The resulting main baseline `888b3106ee98059c712f1d7cd27b673ce4d8afb5` passed Atlas push validation #2358.
- **LKB-0567 is VERIFIED.** PR #660 reconciled authoritative durable equipment → combat activation onto hardened current source, passed Full Atlas validation #2384 on exact head `02345b94742cfa0011efa0f00e30edf6e590c25c`, and squash-merged as `834b0c41be786aeddb4e17cde05fe9b0ca38cf16`. Post-merge main push validation #2385 passed.
- LKB-0567 resolves combat weapon identity only from server-owned equipped inventory plus authored equipment definitions and reuses `OperativeCombatRuntimeService.equipFoundWeapon`. Durable unequip is a first-class guarded persistence mutation behind owner/lease validation. The stale #577 private `_records` reach-through and open-ended heartbeat activation design were **not** adopted; activation is bounded and lifecycle-aware instead.
- Fresh current-main audit found stale PR #577 fully superseded by the safer LKB-0567 implementation; #577 is closed unmerged.
- `ClientBootstrapDependencyWaitSourceAudit.test.luau` continues to enforce zero untimed `WaitForChild` calls under the canonical client source tree. `ServerBootstrapDependencyWaitSourceAudit.test.luau` continues to report no unbounded network dependency waits across canonical server/shared/Main World source.
- The shared Living Kingdoms claim is released by this closeout transaction. **No backlog ticket is BUILDING after this transaction lands.** The repository returns to selector mode; eligibility is not authorization to start several old feature branches.
- Missing manual Studio/device evidence does not block dependency-safe source progression. A reproducible runtime, authority, persistence, data-loss, security, or deterministic-validation defect does.
- The development coverage system preserves `LK-001`–`LK-300` as a machine-readable concern ontology in `../../config/coverage/living-kingdoms-development.json`; it is not a second roadmap.

## NOW

### 1. Fresh current-main capability selector — no BUILDING ticket

After this LKB-0567 release transaction merges and its main push validation is green, refresh current `main` and the full open-PR inventory before claiming another ticket.

Selector rules:

- compare every serious candidate with current main rather than trusting PR age or old mergeability;
- inspect superseding merges, ownership drift, stack dependencies, and current validation expectations;
- rank by player-facing/reliability ROI, dependency readiness, current-main compatibility, overlap risk, and measurable exit criteria;
- choose the **smallest coherent backlog ticket** that directly expresses the selected capability;
- publish `active_claim.json` LOCKED + one BUILDING `status.csv` row + this dashboard's new NOW in one atomic coordination transaction before gameplay source edits;
- reconcile useful old work onto fresh current main rather than merging stale branches wholesale;
- if no candidate can be safely and explicitly activated from current evidence, stop at that authority boundary rather than manufacturing work.

### 2. Candidate pool to refresh

These are candidates only, **not active work**:

- **#566 / #579 — durable character progression/stats.** High player value but a larger persistence-sensitive stack; #579 depends on #566. Re-audit against all Patch 0.7 hardening before activation.
- **#537 / #568 / #574 — seeded/procedural instance stack.** High replayability value but a larger old stack touching run-scoped instance architecture; reconcile only after a fresh runtime/dependency audit.
- **#570 — enemy navigation scheduling/stuck recovery.** Smaller reliability-oriented combat lane; re-check whether its unique work still survives current main and whether it now outranks the larger feature stacks.
- Newly discovered concrete runtime/security/data-loss defects outrank speculative expansion when they are reproducible and current.

Older presentation/test/refactor branches such as #535, #547, #550, #559 and #560 remain provenance only unless a selected capability directly needs still-unique work from them.

### 3. Keep repository/documentation truth coherent

When a coherent capability materially changes development coverage or a durable reusable extension seam, update the canonical coverage/efficiency registries and regenerate their views. Do not create a parallel status document.

## Closed/superseded source branches

- **#577** — authoritative equipment activation source candidate; superseded by verified LKB-0567 PR #660 and closed unmerged.
- **#646 / #652** — bounded-wait evidence sources; closed unmerged after later LKB-0033 reconciliation.
- **#656** — exhaustive LKB-0033 source closeout; merged and VERIFIED.
- **#620** — northwest route redundancy; superseded by verified LKB-0682 PR #649.

## NEXT

Once the selector names a winner:

1. map the capability to the exact backlog ID from the canonical workstream/dimension matrix;
2. perform the atomic claim transaction and validate it before source work;
3. implement only the smallest coherent requirement from fresh current main;
4. preserve current owners and reject stale implementation shortcuts;
5. pass the applicable Full Atlas gate on the final PR head;
6. merge, require green main push validation, and directly re-audit current main/open PR overlap;
7. close superseded source PRs and release the claim in a validated closeout transaction;
8. return here and select again.

Patch 0.8 remains an available planned queue via `PATCH-0.8-ACCEPTANCE.md` + `PATCH-0.8-100-TASK-HARDENING-BACKLOG.md`, but **it is not automatically selected**. Patch 0.9 and RC 1.0 remain later planned queues unless explicitly activated.

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

Coverage gaps are candidates, not automatic priority. Player value, dependency removal, current defects, and this dashboard remain the execution tie-breakers.

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

## Manual evidence backlog

Manual Studio/device/play work is separate from NOW/NEXT. Record only what was actually measured. If it reveals a reproducible defect, promote that defect into the active source queue. If it is not run, leave the experiential fact **UNMEASURED** and continue dependency-safe source work.

## WIP rule

- one active implementation PR for the current capability/lane;
- at most one additional non-overlapping feature PR only when the first is externally blocked;
- parallel-development policy means other lanes are **eligible**, not that all eligible lanes should have simultaneous PRs;
- inspect open PRs for freshness and overlap before starting;
- merge only after the applicable automated validation is green;
- after a successful merge, update NOW/NEXT when execution truth materially changes rather than leaving stale instructions behind.
