# Living Kingdoms — Begin Backlog Process

This file defines the exact launch behavior for the user command:

> **begin the backlog process**

When that phrase (or a clearly equivalent instruction) is given for Living Kingdoms, operate as the backlog coordinator and begin execution without asking the user to manually choose a ticket.

## Authority

Before touching source:

1. fetch current `main`;
2. inspect `backlog/living-kingdoms/active_claim.json` and `backlog/living-kingdoms/status.csv`;
3. run `python backlog/living-kingdoms/materialize_backlog.py --check` and reconcile any coordination-state failure before doing implementation work;
4. inspect current open PRs for overlap, staleness, and already-implemented work;
5. read `docs/roadmap/EXECUTION-DASHBOARD.md`;
6. read root `AGENTS.md`;
7. read `games/living-kingdoms/AGENTS.md`;
8. read `backlog/living-kingdoms/AGENT_COORDINATION.md`;
9. read `backlog/living-kingdoms/IMPLEMENTATION_PLAYBOOK.md`;
10. run `python backlog/living-kingdoms/materialize_backlog.py` when a readable generated queue is useful.

Accepted runtime evidence and the Execution Dashboard remain authoritative. The 1,000-ticket backlog is candidate inventory, not a competing roadmap.

## Resume-first rule

`active_claim.json` is the serialization lock for active implementation ownership. `status.csv` is the execution ledger. They must agree.

- If `active_claim.json` is `LOCKED`, resume/reconcile that exact ticket after confirming its status row, branch/PR, current `main`, and authority still agree.
- A valid lock forbids starting another `BUILDING` ticket, even if another specialist lane is otherwise eligible.
- If the lock or `BUILDING` claim is stale, contradictory, already merged, or invalidated by newer authority, reconcile the existing claim first. Do not overwrite it with a new ticket.
- If the lock is `UNLOCKED`, there must be no `BUILDING` row. Then select the smallest eligible backlog candidate that directly implements or de-risks the dashboard-selected capability.
- Never start a second `BUILDING` ticket just because another specialist lane exists.

The lock has no automatic expiry. Stale-looking ownership requires evidence-based reconciliation, not time-based stealing.

## Selection rule

Choose work in this order:

1. a concrete runtime, authority, lifecycle, security, data-safety, coordination-state, or automated-validation failure that makes downstream work unsafe/incorrect;
2. the dashboard `NOW` capability;
3. the smallest dependency-removing ticket that materially advances `NOW`;
4. only when current work is concretely blocked, a dashboard-permitted non-overlapping fallback candidate.

Backlog priority/ROI is a tie-breaker only after authority, dependencies, safety, and overlap are satisfied.

Before activation, verify:

- dependencies are satisfied or demonstrably unnecessary;
- current `main` does not already satisfy the acceptance criteria;
- no open PR owns the same implementation surface;
- the ticket extends an existing canonical owner instead of creating a competing subsystem;
- the listed risk tier and validation requirements are appropriate;
- the shared claim lock is `UNLOCKED` on current `main`.

## Atomic claim protocol

Before substantive source edits, prepare one coordination transaction that updates **both**:

- `backlog/living-kingdoms/status.csv` with:
  - `Status=BUILDING`
  - `Authorization=AUTHORIZED`
  - a concrete `Authority Reference`
  - one specialist `Owner`
  - timezone-aware ISO-8601 `Claimed At`
  - one working `Branch`
- `backlog/living-kingdoms/active_claim.json` with the same ticket ID, owner, timestamp, branch, and authority reference, and `state=LOCKED`.

Use branch convention:

`lk/LKB-####-short-description`

Run:

```bash
python backlog/living-kingdoms/materialize_backlog.py --check
```

Publish/merge the claim transaction to current `main` **before substantive implementation begins**. Start the implementation branch from a baseline containing that published claim.

If another agent changed the lock or `main` moved so the claim cannot publish cleanly, do not force the claim through. Fetch current `main`, inspect the winning state, and reassess.

## Execution loop

For the authorized ticket:

1. confirm the published shared lock still matches the ticket/owner/branch;
2. inspect existing source, tests, configuration, open PRs, and canonical owner;
3. implement only the smallest coherent scope;
4. preserve server authority, lifecycle ownership, stable IDs, data safety, and existing working behavior;
5. add focused regression coverage when behavior or a meaningful failure class changes;
6. run validation required by the ticket risk tier;
7. perform Studio/device/runtime verification when required by repo policy;
8. fix regressions caused by the change;
9. open/update a focused PR;
10. merge only when the applicable repository gates are satisfied or repo policy explicitly permits `BUILT — VERIFICATION PENDING`;
11. after merge, gather required post-merge validation/current-main evidence;
12. close out the ticket by updating `status.csv` with PR/commit/proof and truthful final state;
13. in the same closeout transaction, set `active_claim.json` to `UNLOCKED` and clear its claim fields;
14. run the coordination check and publish/merge the closeout transaction;
15. use `BUILT — VERIFICATION PENDING` when source work is complete but required engine evidence remains;
16. use `VERIFIED` only when required evidence exists;
17. fetch current `main`, re-read the dashboard, rematerialize/re-check the backlog, and select the next eligible ticket.

Do **not** treat an implementation merge alone as releasing ownership. The lock remains held until the closeout transaction lands.

Do **not** stop after one successful ticket merely to ask the user for another assignment. Continue the backlog process until a real stop condition is reached.

## Stop conditions

Stop autonomous implementation only when one of these is true:

- a concrete blocker makes further implementation unsafe or impossible;
- the Execution Dashboard has no authorized/appropriate source work remaining;
- proceeding requires an irreversible product decision that is not already resolved by repository authority;
- required credentials/assets/Studio-only actions cannot be performed by the active agent and no safe source work remains;
- the user explicitly tells the process to stop, pause, or change direction.

When blocked, record `BLOCKED — <concrete reason>` in the ledger and release the active lock in the same validated coordination transaction. Report the blocker plus the next safe candidate, if one exists.

## Specialist routing

Route the selected ticket by its `Agent Lane`. The lane determines ownership, not permission to create parallel WIP. One implementation owner owns the ticket. Supporting specialists may review bounded concerns without creating competing implementations.

Changing the implementation owner is a lock transfer: update the ledger and lock together, validate, publish the transfer, then let the new owner edit source.

## Completion reporting

Keep progress reports concise. After each merge/closeout report:

- ticket ID/title;
- specialist lane;
- risk tier;
- validation result;
- status (`BUILT — VERIFICATION PENDING` or `VERIFIED`);
- PR/commit;
- lock state (`UNLOCKED` after successful closeout);
- next selected ticket or concrete blocker.

## Exact launch interpretation

If the user says only:

> **begin the backlog process**

that is sufficient authorization to start this coordinator loop. Do not ask the user to pick a ticket, lane, branch, or priority unless repository authority cannot resolve a genuinely irreversible decision.
