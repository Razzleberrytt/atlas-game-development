# Living Kingdoms — Begin Backlog Process

This file defines the exact launch behavior for the user command:

> **begin the backlog process**

When that phrase (or a clearly equivalent instruction) is given for Living Kingdoms, operate as the backlog coordinator and begin execution without asking the user to manually choose a ticket.

## Authority

Before touching source:

1. fetch current `main`;
2. inspect current open PRs for overlap, staleness, and already-implemented work;
3. read `docs/roadmap/EXECUTION-DASHBOARD.md`;
4. read root `AGENTS.md`;
5. read `games/living-kingdoms/AGENTS.md`;
6. read `backlog/living-kingdoms/AGENT_COORDINATION.md`;
7. read `backlog/living-kingdoms/IMPLEMENTATION_PLAYBOOK.md`;
8. run `python backlog/living-kingdoms/materialize_backlog.py`.

Accepted runtime evidence and the Execution Dashboard remain authoritative. The 1,000-ticket backlog is candidate inventory, not a competing roadmap.

## Resume-first rule

Inspect `backlog/living-kingdoms/status.csv` first.

- If exactly one ticket is `BUILDING`, resume that ticket after confirming its branch/PR still matches current `main` and authority.
- If a `BUILDING` claim is stale, contradictory, already merged, or invalidated by newer authority, reconcile the ledger before choosing new work.
- If no ticket is `BUILDING`, select the smallest eligible backlog candidate that directly implements or de-risks the dashboard-selected capability.
- Never start a second `BUILDING` ticket just because another specialist lane exists.

## Selection rule

Choose work in this order:

1. a concrete runtime, authority, lifecycle, security, data-safety, or automated-validation failure that makes downstream work unsafe/incorrect;
2. the dashboard `NOW` capability;
3. the smallest dependency-removing ticket that materially advances `NOW`;
4. only when current work is concretely blocked, a dashboard-permitted non-overlapping fallback candidate.

Backlog priority/ROI is a tie-breaker only after authority, dependencies, safety, and overlap are satisfied.

Before activation, verify:

- dependencies are satisfied or demonstrably unnecessary;
- current `main` does not already satisfy the acceptance criteria;
- no open PR owns the same implementation surface;
- the ticket extends an existing canonical owner instead of creating a competing subsystem;
- the listed risk tier and validation requirements are appropriate.

## Claim protocol

Before substantive source edits, update `backlog/living-kingdoms/status.csv` with:

- `Status=BUILDING`
- `Authorization=AUTHORIZED`
- a concrete `Authority Reference`
- one specialist `Owner`
- ISO-8601 `Claimed At`
- one working `Branch`

Use branch convention:

`lk/LKB-####-short-description`

Publish the claim before implementation.

## Execution loop

For the authorized ticket:

1. inspect existing source, tests, configuration, open PRs, and canonical owner;
2. implement only the smallest coherent scope;
3. preserve server authority, lifecycle ownership, stable IDs, data safety, and existing working behavior;
4. add focused regression coverage when behavior or a meaningful failure class changes;
5. run validation required by the ticket risk tier;
6. perform Studio/device/runtime verification when required by repo policy;
7. fix regressions caused by the change;
8. open/update a focused PR;
9. merge only when the applicable repository gates are satisfied or repo policy explicitly permits `BUILT — VERIFICATION PENDING`;
10. update `status.csv` with PR/commit and proof;
11. use `BUILT — VERIFICATION PENDING` when source work is complete but required engine evidence remains;
12. use `VERIFIED` only when required evidence exists;
13. fetch current `main`, re-read the dashboard, rematerialize the backlog, and select the next eligible ticket.

Do **not** stop after one successful ticket merely to ask the user for another assignment. Continue the backlog process until a real stop condition is reached.

## Stop conditions

Stop autonomous implementation only when one of these is true:

- a concrete blocker makes further implementation unsafe or impossible;
- the Execution Dashboard has no authorized/appropriate source work remaining;
- proceeding requires an irreversible product decision that is not already resolved by repository authority;
- required credentials/assets/Studio-only actions cannot be performed by the active agent and no safe source work remains;
- the user explicitly tells the process to stop, pause, or change direction.

When blocked, record `BLOCKED — <concrete reason>` in the ledger and report the blocker plus the next safe candidate, if one exists.

## Specialist routing

Route the selected ticket by its `Agent Lane`. The lane determines ownership, not permission to create parallel WIP. One implementation owner owns the ticket. Supporting specialists may review bounded concerns without creating competing implementations.

## Completion reporting

Keep progress reports concise. After each merge report:

- ticket ID/title;
- specialist lane;
- risk tier;
- validation result;
- status (`BUILT — VERIFICATION PENDING` or `VERIFIED`);
- PR/commit;
- next selected ticket or concrete blocker.

## Exact launch interpretation

If the user says only:

> **begin the backlog process**

that is sufficient authorization to start this coordinator loop. Do not ask the user to pick a ticket, lane, branch, or priority unless repository authority cannot resolve a genuinely irreversible decision.
