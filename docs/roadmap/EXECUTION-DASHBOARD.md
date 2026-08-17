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
- Main World route-resilience ticket **LKB-0682 is VERIFIED**. PR #649 reconciled the still-unique northwest bypass from stale #620 onto current main, passed Full Atlas validation #2286, and merged as `c9d23a7b4c8b892dd3d7d16e86684fa69882f7c8`. Post-merge main push validation #2287 passed. Rooted road-failure evidence improved roads 7→9, edges 7→10, chokepoints 2→1, bridges 3→1; worst bridge failure improved from 6 districts / 4 roads lost to 0 districts / 1 road, and the prior worst non-root articulation failure disappeared. PR #620 is closed unmerged as superseded.
- **LKB-0033 is VERIFIED and the bounded-dependency maintenance mini-lane is CLOSED.** PR #656 exhaustively bounded startup/dependency waits, passed Full Atlas validation #2353, and squash-merged as `310ba09c6a79771739228ee1b749824883c822e2`. Post-merge main validation #2354 passed. Coordination closeout PR #657 passed Full Atlas #2357, merged as `888b3106ee98059c712f1d7cd27b673ce4d8afb5`, and post-merge main validation #2358 passed.
- `ClientBootstrapDependencyWaitSourceAudit.test.luau` enforces zero untimed `WaitForChild` calls under the canonical client source tree. `ServerBootstrapDependencyWaitSourceAudit.test.luau` reports no unbounded network dependency waits across canonical server/shared/Main World source. Do not manufacture another bounded-wait ticket without a new concrete defect.
- The dashboard-mandated older-feature audit was refreshed against current main. **#577 retains a small, independent, still-missing player-facing authority bridge:** current main does not contain `EquipmentCombatAdapter.luau` or `EquippedWeaponResolver.luau`. The other named candidates are either larger dependency stacks (#566/#579 progression; #537/#568/#574 procedural), enemy-navigation reliability (#570), presentation-only (#535), test/maintenance-only (#547/#559/#560), or environment-refactor work (#550).
- Therefore **LKB-0567 is the sole BUILDING ticket**: cross-system integration for Equipment, Affixes & Comparison, specifically durable server-owned equipment identity → existing authoritative combat weapon activation.
- Missing manual Studio/device evidence does not block dependency-safe source progression. A reproducible runtime, authority, persistence, data-loss, security, or deterministic-validation defect does.
- The development coverage system preserves `LK-001`–`LK-300` as a machine-readable concern ontology in `../../config/coverage/living-kingdoms-development.json`, with generated taxonomy/atlas/report views. It is **not** a second roadmap and does not authorize one module per concern.

## NOW

### 1. Reconcile authoritative durable equipment → combat activation — LKB-0567

Use open PR #577 only as source evidence. Reconcile its still-valid player-facing outcome onto a fresh branch from the published LKB-0567 claim baseline.

Required outcome:

- resolve combat weapon identity only from the server-owned durable inventory record plus authored equipment definitions;
- route accepted durable weapon equips through the existing authoritative combat owner/API rather than creating a second combat state path;
- support authoritative weapon-slot unequip/fallback through a **public current persistence mutation seam**, not by reaching into another service's private resident cache;
- expose only minimal client intent at the inventory network boundary (owned instance ID for equip, known slot ID for unequip); never accept client-authored weapon IDs, damage, RPM, magazine size, rarity, power, affixes, or definitions;
- preserve current Patch 0.7 lease, guarded-write, capacity, rollback, and resident-record rules;
- preserve LKB-0033 bounded-failure guarantees: no indefinite dependency wait or open-ended retry loop may be introduced;
- add focused pure/resolver, persistence, authority/source-audit, and integration evidence for the canonical handoff;
- do not redesign combat, inventory persistence, equipment generation, affix semantics, progression, UI, or unrelated remotes.

Exit gate:

1. the implementation diff is reconciled from current main and contains only the smallest coherent LKB-0567 integration;
2. Full Atlas validation is green on the final PR head;
3. merge to main and require green main push validation;
4. directly audit current main and #577 for surviving unique scope/overlap;
5. close #577 unmerged as superseded if its useful outcome has landed;
6. mark LKB-0567 VERIFIED and release `active_claim.json` only through the coordination release transaction.

### 2. Keep repository/documentation truth coherent

The 300-area development taxonomy, Development Atlas, coverage report, documentation router, and coverage validator are the canonical cross-system gap/audit framework. When a coherent implementation materially changes coverage, update the machine registry and regenerate the views; do not create another independent status document.

## Candidate audit — 2026-08-17 selector result

Open PR count is **not** the execution queue. Age/open state does not grant authority.

### Selected source candidate

- **#577 — authoritative inventory equipment and weapon stat activation.** Selected because its server-owned equipment → combat bridge is still absent from current main, it is independently implementable, it produces an immediate player-facing loadout/combat outcome, and it has a measurable authority/security exit gate. Reconcile; do not merge stale branch wholesale.

### Deferred larger feature stacks

- **#566 / #579** — durable character progression/stats. #579 is stacked on #566; this is a broader persistence/progression capability and is not the current lane.
- **#537 / #568 / #574** — seeded/procedural instance work. Useful but forms a larger procedural stack with current-main reconciliation and Studio facts still relevant.
- **#570** — enemy-navigation scheduling/stuck recovery. Reliability value remains, but it is not the selected player-facing equipment bridge.

### Not selected as player-facing implementation lanes

- **#535** — enemy archetype presentation only; does not change gameplay authority.
- **#547** — test layout organization only.
- **#550** — environment composition math refactor/evidence tooling.
- **#559 / #560** — source-audit path maintenance only.
- **#578** — coordination sync from main into the old progression branch, not an independent feature.

### Closed/superseded sources

- **#646** — RPG menu network waits; useful work reconciled through later LKB-0033 checkpoints.
- **#652** — diagnostic client network-child audit; closed unmerged by design.
- **#656** — exhaustive LKB-0033 implementation; merged and verified.
- **#620** — northwest route redundancy; superseded by verified LKB-0682 PR #649.

## NEXT

After LKB-0567 leaves BUILDING and the shared claim is released:

1. refresh current main and the full open-PR inventory again;
2. re-rank the remaining viable capabilities using player-facing/reliability ROI, dependency readiness, current-main compatibility, overlap risk, and measurable exit criteria;
3. explicitly activate exactly one smallest matching backlog ticket through a new atomic claim transaction;
4. reconcile useful old work onto fresh main rather than blindly merging stale branches;
5. repeat until a concrete blocker or authority boundary prevents safe progression.

Patch 0.8 remains an available planned queue via `PATCH-0.8-ACCEPTANCE.md` + `PATCH-0.8-100-TASK-HARDENING-BACKLOG.md`, but **it is not automatically selected** merely because prior lanes closed. Patch 0.9 and RC 1.0 remain later planned queues unless explicitly activated.

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
