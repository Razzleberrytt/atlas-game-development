# Atlas — Execution Dashboard v1.27

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-17  
**Main baseline audited:** `888b3106ee98059c712f1d7cd27b673ce4d8afb5`  
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
- **LKB-0033 is VERIFIED and the bounded-dependency maintenance mini-lane is CLOSED.** PR #656 passed Full Atlas validation #2353 and merged as `310ba09c6a79771739228ee1b749824883c822e2`; closeout PR #657 released the shared backlog mutex and advanced the selector. The resulting main baseline `888b3106ee98059c712f1d7cd27b673ce4d8afb5` passed Atlas push validation #2358.
- `ClientBootstrapDependencyWaitSourceAudit.test.luau` enforces zero untimed `WaitForChild` calls under the canonical client source tree. `ServerBootstrapDependencyWaitSourceAudit.test.luau` reports no unbounded network dependency waits across canonical server/shared/Main World source.
- A fresh older-feature audit compared the progression stack (#566/#578/#579), equipment activation (#577), procedural-instance work (#568/#574), enemy navigation (#570), and older presentation/test/refactor candidates against current main.
- **Equipment-to-combat activation is the selected next player-facing capability.** It best matches the current product loop's bank/equip/build-choice promise, preserves existing combat and inventory owners, has a compact still-unique six-file candidate surface, and does not require reopening the durable-account schema or multi-run architecture first.
- Stale PR #577 is **source evidence only**. Its branch is 183 commits behind the audited main baseline. The fresh implementation must reconcile only still-unique behavior onto current source, preserving all newer persistence/network hardening.
- Missing manual Studio/device evidence does not block dependency-safe source progression. A reproducible runtime, authority, persistence, data-loss, security, or deterministic-validation defect does.
- The development coverage system preserves `LK-001`–`LK-300` as a machine-readable concern ontology in `../../config/coverage/living-kingdoms-development.json`; it is not a second roadmap.

## NOW

### 1. Authoritative equipment-to-combat activation — LKB-0567

**Status: BUILDING.** `LKB-0567` is the sole active backlog ticket and maps the Equipment, Affixes & Comparison workstream's cross-system integration dimension onto the current product loop.

Reconcile the still-unique useful work from stale PR #577 onto a fresh current-main branch.

Required outcome:

- derive the equipped combat weapon only from server-owned inventory state plus authored equipment definitions;
- reuse the existing authoritative `OperativeCombatRuntimeService.equipFoundWeapon` seam rather than editing combat authority;
- support authoritative/idempotent slot unequip through the existing inventory owner;
- accept only bounded client intent such as owned instance identity or known slot identity; never trust submitted damage, rarity, power, affixes, weapon stats, or ownership;
- preserve the existing `EquippedEquipmentModifierResolver` → `RelicModifierService` modifier path;
- reconcile focused pure/integration/source-audit coverage;
- preserve every newer Patch 0.7 persistence, lease, replay, rollback, and bounded-network change on current main;
- pass Full Atlas validation before merge.

Risk tier: **R2** for the scoped integration. If reconciliation requires modifying persistence schema/value-migration semantics, stop and reclassify before doing so rather than silently expanding into R3.

### 2. Keep repository/documentation truth coherent

When this coherent capability materially changes development coverage or a durable reusable extension seam, update the canonical coverage/efficiency registries and regenerate their views. Do not create a parallel status document.

## Selector audit — why LKB-0567 won

Open PR count is **not** the execution queue. Age/open state does not grant authority.

- **#577 equipment activation:** strongest immediate core-loop fit; two central modules remain absent from main; compact six-file source surface; branch history is stale but the intended authority boundary remains compatible with current product direction. **Selected for fresh reconciliation.**
- **#566 / #578 / #579 progression:** high player value, but the stack is older, larger, persistence-sensitive, and dependent on reconciling schema/value ownership after extensive Patch 0.7 hardening. Keep as a later deliberate selector candidate.
- **#568 / #574 procedural instances:** high replayability value, but the candidate chain is old/non-mergeable and touches run-scoped instance architecture that should be reconciled only after a fresh current-runtime dependency audit. Keep as a later deliberate selector candidate.
- **#570 enemy navigation:** useful combat/reliability work with a bounded surface, but it improves an existing pressure system rather than closing the more immediate loot → equip → combat decision loop. Keep as a later deliberate selector candidate.
- **#535, #537, #547, #550, #559, #560 and similar older presentation/test/refactor PRs:** retain only as source/provenance until a current dashboard capability specifically needs their unique work.

### Closed/superseded sources

- **#646 / #652** — bounded-wait evidence sources; closed unmerged after later LKB-0033 reconciliation.
- **#656** — exhaustive LKB-0033 source closeout; merged and VERIFIED.
- **#620** — northwest route redundancy; superseded by verified PR #649.

## NEXT

After LKB-0567 leaves BUILDING:

1. require the applicable PR validation and post-merge main validation;
2. record `BUILT — VERIFICATION PENDING` if Studio/player-facing evidence remains, or `VERIFIED` only if the required evidence is actually present;
3. release `active_claim.json` in the same closeout transaction;
4. re-run the older-candidate/current-main selector instead of auto-starting a second ticket;
5. rank progression, procedural-instance, enemy-navigation, and any newly discovered concrete defect by player value, dependency readiness, overlap, and current-main compatibility.

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
