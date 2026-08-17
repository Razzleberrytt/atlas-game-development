# Living Kingdoms — Backlog Agent Coordination

## Prime directive

The backlog is subordinate to the current Execution Dashboard. A coordinator may route work; it may not invent a new roadmap by promoting arbitrary backlog rows.

Read `docs/roadmap/EXECUTION-DASHBOARD.md`, root `AGENTS.md`, and `games/living-kingdoms/AGENTS.md` before using this inventory.

## Coordination state

Living Kingdoms uses two coordinated state files:

- `status.csv` — sparse audit ledger for authorization, ownership, execution status, branch, blockers, and proof;
- `active_claim.json` — the **single shared implementation mutex** for the one ticket currently allowed to be `BUILDING`.

The two files must agree. `python backlog/living-kingdoms/materialize_backlog.py --check` fails when they diverge, and the repository validation profiles run that check automatically.

`active_claim.json` is deliberately one shared file. Every ownership acquisition or release touches the same path, so concurrent agents cannot safely publish competing claims from the same baseline without a Git conflict/stale-SHA failure. Never resolve that conflict by force-pushing, choosing one side blindly, or editing around the lock.

The lock has no automatic TTL. A seemingly stale claim must be reconciled against current `main`, open PRs, accepted evidence, and the dashboard before it is released or transferred.

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

The backlog validator enforces at most one `BUILDING` ticket, and that ticket must exactly match the shared active claim.

If the active work is externally blocked:
1. record `BLOCKED — <concrete reason>`;
2. release `active_claim.json` to `UNLOCKED` in the same coordination transaction;
3. confirm the dashboard/authority permits another non-overlapping capability;
4. authorize and claim that next ticket through a new lock transaction;
5. do not edit the blocked owner's branch.

## Activation protocol

A candidate is eligible only when:
1. the current dashboard/accepted runtime evidence makes the capability appropriate;
2. current `main` and open PRs have been inspected for overlap;
3. any `Depends On` rows are satisfied or proven unnecessary;
4. the ticket routes into an existing canonical owner instead of creating a parallel subsystem;
5. the risk tier and required validation are understood;
6. `active_claim.json` is `UNLOCKED` after any stale-state reconciliation.

Then prepare one **atomic coordination transaction** that changes both `status.csv` and `active_claim.json`.

`status.csv` claim example:

```csv
LKB-0002,BUILDING,AUTHORIZED,docs/roadmap/EXECUTION-DASHBOARD.md NOW: <capability>,runtime-network-agent,2026-08-16T21:30:00-04:00,lk/LKB-0002-short-name,,,Initial claim
```

Matching `active_claim.json` shape:

```json
{
  "schema_version": 1,
  "state": "LOCKED",
  "ticket_id": "LKB-0002",
  "owner": "runtime-network-agent",
  "claimed_at": "2026-08-16T21:30:00-04:00",
  "branch": "lk/LKB-0002-short-name",
  "authority_reference": "docs/roadmap/EXECUTION-DASHBOARD.md NOW: <capability>"
}
```

Run:

```bash
python backlog/living-kingdoms/materialize_backlog.py --check
```

Publish/merge that coordination transaction to current `main` **before substantive source edits begin**. The implementation branch must start from a baseline containing the published claim. If `main` moved, the lock changed, or the claim transaction conflicts, abort the claim, fetch current `main`, and reassess instead of overriding the other owner.

## Release protocol

Merging implementation source does **not** automatically release ownership.

After the implementation merge:
1. collect the required validation/post-merge evidence;
2. re-check current `main`, open PR overlap, and dashboard truth;
3. update the ticket to `BUILT — VERIFICATION PENDING`, `VERIFIED`, or `BLOCKED — <reason>` as truth requires;
4. set `active_claim.json` to `UNLOCKED` with null claim fields in the same coordination transaction;
5. run the backlog coordination check;
6. publish/merge the release transaction to `main`;
7. only then may the coordinator claim another ticket.

Unlocked shape:

```json
{
  "schema_version": 1,
  "state": "UNLOCKED",
  "ticket_id": null,
  "owner": null,
  "claimed_at": null,
  "branch": null,
  "authority_reference": null
}
```

Do not unlock merely because an implementation PR was opened, CI is pending, or another lane looks attractive.

## Coordinator loop

1. Fetch current `main`.
2. Inspect `active_claim.json` and `status.csv`; run the coordination check.
3. Inspect open PRs; distinguish current/rebased work from stale candidates.
4. Read dashboard NOW/NEXT/LATER.
5. Materialize the backlog when a readable queue view is useful.
6. If the lock is validly `LOCKED`, resume/reconcile that ticket instead of selecting another.
7. If unlocked, search candidate inventory for the smallest ticket(s) that implement or de-risk the selected capability.
8. Prefer an existing owner/extension seam.
9. Authorize **one** coherent ticket through the atomic claim transaction.
10. Route it to the appropriate specialist.
11. Track BUILDING → BUILT — VERIFICATION PENDING / VERIFIED.
12. Release the shared claim only through the release protocol.
13. If a real blocker appears, record it, release the blocked claim, and route the next authorized non-overlapping task if authority permits.
14. Reassess after every merge; do not pre-assign 100 future tickets as executable.

## Specialist loop

1. Confirm the ticket is `AUTHORIZED` and `BUILDING`.
2. Confirm `active_claim.json` names the same ticket, owner, timestamp, branch, and authority reference.
3. Confirm the claim is already published on the `main` baseline used for the implementation branch.
4. Confirm no active PR/ticket duplicates the scope.
5. Inspect source/tests/config before editing.
6. Implement the smallest coherent increment.
7. Preserve server authority and existing canonical owners.
8. Validate at the ticket's risk tier.
9. Record Studio-only evidence as pending rather than pretending it was verified.
10. Record PR/commit and proof during the closeout transaction.
11. Do not claim new work; only the coordinator may release/transfer the shared claim.

## Cross-agent handoffs

A ticket has one implementation owner. Supporting specialists may review or supply bounded input, but must not create competing implementations.

When a ticket touches multiple lanes, choose the lane owning the highest-risk authoritative boundary. Example: a new equipment UI backed by durable inventory still routes through the inventory/progression owner; presentation does not gain item authority.

A handoff that changes implementation owner is a claim transfer: update the ledger and lock together, validate, and publish the transfer before the new owner edits source.

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
