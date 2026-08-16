# Atlas — Execution Dashboard v1.23

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-16  
**Main baseline audited:** `f372be01f53c769ff64afa0f5ed6c1b8f108c21a`  
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

## Current truth — 2026-08-16

- Atlas/Living Kingdoms is a **Roblox/Rojo repository-first codebase**. `games/living-kingdoms/src/` remains gameplay-authoritative source; the operation and dedicated Main World use their canonical Rojo project mappings.
- **Patch 0.7 durable persistence + valuable-state hardening remains automated-acceptance complete for every non-deferred row.** It implemented **86 / 100** ranked tasks. The remaining 14 are explicit deferrals, not hidden incompletion:
  - #54–#57 — overflow storage without a real inventory-capacity requirement;
  - #64–#69 — duplicate durable authorities / currency without a gameplay consumer;
  - #84, #86–#88 — diagnostic/latency/randomized stress surfaces without a current consumer.
- Patch 0.7's machine-readable detailed proof remains `../production/PATCH-0.7-ACCEPTANCE-MATRIX.json`.
- Since that closure, `main` has moved through concrete **maintenance/audit hardening** rather than an explicitly activated broad numbered patch.
- On 2026-08-16, merged work includes Main World rooted road-failure measurement (#619) and a sequence of bounded client network-wait repairs (#622, #624, #626, #628, #631). The current open continuation is #633 for `PersonalFlashlight` bounded network waits.
- Missing manual Studio/device evidence does not block dependency-safe source progression. A reproducible runtime, authority, persistence, data-loss, security, or deterministic-validation defect does.
- The development coverage system now preserves `LK-001`–`LK-300` as a machine-readable concern ontology in `../../config/coverage/living-kingdoms-development.json`, with generated taxonomy/atlas/report views. It is **not** a second roadmap and does not authorize one module per concern.

## NOW

### 1. Finish the concrete bounded-network-wait hardening lane

The current source-maintenance lane is the family of reproducible ordered-client-bootstrap risks caused by unbounded waits for network folders/remotes/events. #633 is the current open continuation as of this refresh.

Rules:

- fix only concrete bounded-wait defects found in canonical client/bootstrap paths;
- add source/regression coverage that prevents reintroduction of the same wait family;
- do not redesign networking authority while repairing startup reliability;
- merge only when the applicable automated gate is green;
- stop the lane when the audit has no remaining concrete members rather than inventing work to keep the lane alive.

### 2. Keep Main World resilience work evidence-driven

Rooted road-failure analysis is now a canonical measurable surface. The next geometric resilience change must prove reduced player-facing failure impact through the existing topology/readability/support checks.

Open PR #620 was based before the current bounded-wait merges and was previously observed non-mergeable against then-current `main`. Treat it as a **rebase + revalidation candidate**, not current accepted work. Do not merge or duplicate it without refreshing onto current main and rerunning the required evidence.

### 3. Keep repository/documentation truth coherent

The 300-area development taxonomy, Development Atlas, coverage report, documentation router, and coverage validator are the canonical cross-system gap/audit framework. When a coherent implementation materially changes coverage, update the machine registry and regenerate the views; do not create another independent status document.

## Open-PR interpretation

Open PR count is **not** the execution queue.

### Current maintenance candidate

- **#633** — bounded `PersonalFlashlight` network waits. Fits the current concrete reliability lane; merge only after its required validation is green.

### Rebase/revalidation candidate

- **#620** — Main World northwest route redundancy. Potentially valuable and metrics-backed, but not current until rebased against latest main and revalidated.

### Older feature candidates requiring deliberate reactivation

- **#566 / #578 / #579** — progression stack/sync work;
- **#577** — authoritative inventory/equipment activation;
- **#568 / #574** — procedural-instance work;
- **#570** — enemy navigation/combat framework;
- older open presentation/test/refactor PRs such as #535, #537, #547, #550, #559 and #560.

These PRs preserve potentially useful work, but age/open state does not grant authority. Before adopting one: compare it with current main, inspect superseding merges and ownership drift, resolve stack dependencies, rebase/reconcile, and pass the current validation gate. Close or supersede obsolete branches when their useful work has already landed elsewhere.

## NEXT

After the bounded-wait maintenance audit has no remaining concrete defects and current main is green:

1. resolve the Main World resilience candidate from current main if its measured ROI remains positive;
2. audit older open feature candidates for still-valid unique work versus superseded/overlapping work;
3. explicitly activate the next broad player-facing patch/capability here before broad expansion.

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
