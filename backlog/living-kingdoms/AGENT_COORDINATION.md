# Living Kingdoms — Backlog Agent Coordination

## Prime directive

The backlog is subordinate to the current Execution Dashboard. A coordinator may route work; it may not invent a new roadmap by promoting arbitrary backlog rows.

Read `docs/roadmap/EXECUTION-DASHBOARD.md`, root `AGENTS.md`, and `games/living-kingdoms/AGENTS.md` before using this inventory.

## Specialist lanes

| Lane | Typical ownership |
|---|---|
| Coordinator | Current-authority interpretation, overlap checks, activation, blocker routing, next-task selection |
| Runtime & Networking | Bootstrap, remotes, bounded waits, lifecycle/network resilience, observability |
| Persistence & Security | Trust boundaries, durable value, leases, migrations, rollback/data safety |
| Combat | Movement-facing combat, firearms, melee, operative life/revive |
| Enemies & Encounters | Enemy state, navigation, elites, bosses, horde/encounter pacing |
| Expeditions & Procedural | Mission lifecycle, expedition run flow, procedural rooms/seeds |
| Loot & Progression | Loot, equipment, inventory, run builds, durable progression |
| World & Main World | Main World routes/hub/environment/world composition |
| Co-op & Sessions | Party, squad, matchmaking, teleport, reconnect |
| UX & Input | Camera/input, HUD, menus, mobile/controller/accessibility |
| Presentation | Combat/enemy/weapon audio, VFX, animation, silhouettes, readability |
| QA & Performance | Validation, source audits, performance budgets, Studio evidence |
| Content & Live Ops | Discovery, content pipelines, later-phase NPC/quest/vendor/crafting work |
| Release & Live Ops | Release safety, analytics, publishing, rollback, live operations |

These are **routing lanes**, not permission to run fourteen implementation branches concurrently.

## Low-WIP rule

Living Kingdoms keeps one active implementation lane for the current dashboard-selected capability.

The backlog materializer enforces at most one `BUILDING` ticket.

If the active work is externally blocked:
1. record `BLOCKED — <concrete reason>`;
2. confirm the dashboard/authority permits another non-overlapping capability;
3. authorize and claim that next ticket;
4. do not edit the blocked owner's branch.

## Activation protocol

A candidate is eligible only when:
1. the current dashboard/accepted runtime evidence makes the capability appropriate;
2. current `main` and open PRs have been inspected for overlap;
3. any `Depends On` rows are satisfied or proven unnecessary;
4. the ticket routes into an existing canonical owner instead of creating a parallel subsystem;
5. the risk tier and required validation are understood.

Then add/update a row in `status.csv`:

```csv
LKB-0002,BUILDING,AUTHORIZED,docs/roadmap/EXECUTION-DASHBOARD.md NOW: <capability>,runtime-network-agent,2026-08-16T21:30:00-04:00,lk/LKB-0002-short-name,,,Initial claim
```

Publish the claim before substantive source edits.

## Coordinator loop

1. Fetch current `main`.
2. Inspect open PRs; distinguish current/rebased work from stale candidates.
3. Read dashboard NOW/NEXT/LATER.
4. Materialize the backlog.
5. Search candidate inventory for the smallest ticket(s) that implement or de-risk the selected capability.
6. Prefer an existing owner/extension seam.
7. Authorize **one** coherent ticket or a deliberately coupled micro-batch.
8. Route it to the appropriate specialist.
9. Track BUILDING → BUILT — VERIFICATION PENDING / VERIFIED.
10. If a real blocker appears, record it and route the next authorized non-overlapping task.
11. Reassess after every merge; do not pre-assign 100 future tickets as executable.

## Specialist loop

1. Confirm the ticket is `AUTHORIZED`.
2. Confirm no active PR/ticket duplicates the scope.
3. Claim it as `BUILDING`.
4. Inspect source/tests/config before editing.
5. Implement the smallest coherent increment.
6. Preserve server authority and existing canonical owners.
7. Validate at the ticket's risk tier.
8. Record Studio-only evidence as pending rather than pretending it was verified.
9. Record PR/commit and proof.
10. Stop claiming new work until the coordinator/dashboard authorizes the next ticket.

## Cross-agent handoffs

A ticket has one implementation owner. Supporting specialists may review or supply bounded input, but must not create competing implementations.

When a ticket touches multiple lanes, choose the lane owning the highest-risk authoritative boundary. Example: a new equipment UI backed by durable inventory still routes through the inventory/progression owner; presentation does not gain item authority.

## Existing PR guard

Each candidate has an open-PR overlap note. Before activation, re-check current open PRs. In particular, this snapshot was built while active/candidate PRs existed around:
- bounded network waits;
- Main World route resilience;
- enemy navigation;
- procedural instances;
- equipment/inventory;
- durable progression;
- input/source-audit migration;
- environment composition.

Do not assume those PRs are mergeable/current merely because they exist.

## Coverage ontology

The `LK-001`–`LK-300` taxonomy is not a task queue. For broad work:
- run `python scripts/development_coverage.py report`;
- identify relevant concerns;
- map them to canonical engines/owners;
- extend those owners;
- update coverage only when evidence truly changes.

## Verification vocabulary

Use `BUILT — VERIFICATION PENDING` whenever repository source is complete but Studio/device evidence remains.

Use `VERIFIED` only after required evidence exists.
