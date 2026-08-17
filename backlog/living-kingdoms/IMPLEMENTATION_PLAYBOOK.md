# Living Kingdoms — 1,000-Ticket Backlog Implementation Playbook

## Purpose

`LKB-0001` through `LKB-1000` are a structured candidate inventory for finding small, testable implementation slices across Living Kingdoms.

They do **not** replace:
- accepted runtime evidence/current Roblox behavior;
- `docs/roadmap/EXECUTION-DASHBOARD.md`;
- root `AGENTS.md`;
- `games/living-kingdoms/AGENTS.md`;
- patch/product authority.

If this playbook conflicts with those sources, follow the higher authority and update/backlog-mark the affected candidate rather than forcing it through.

## Before selecting a ticket

1. Fetch current `main`.
2. Read `backlog/living-kingdoms/active_claim.json` and `status.csv`.
3. Run `python backlog/living-kingdoms/materialize_backlog.py --check`.
4. If the lock is validly `LOCKED`, resume/reconcile that ticket instead of selecting new work.
5. Inspect open PRs for overlap/staleness.
6. Read dashboard NOW/NEXT/LATER and stop conditions.
7. Read `games/living-kingdoms/AGENTS.md`.
8. Run relevant coverage/efficiency tooling for broad cross-system work.
9. Materialize this backlog when a readable queue view is useful.
10. Only when the lock is `UNLOCKED`, select a candidate that directly serves the current authorized capability.

## Authorization

Every definition defaults to `CANDIDATE — DASHBOARD ACTIVATION REQUIRED`.

The coordinator must record `Authorization=AUTHORIZED` and an `Authority Reference` before source implementation.

Backlog priority and ROI are planning aids. They never override the dashboard.

## Ticket IDs

Use `LKB-####` so backlog tasks cannot be confused with `LK-001`–`LK-300` development-coverage concerns.

## Status

Use the repository execution vocabulary:
- NOT STARTED
- BUILDING
- BUILT — VERIFICATION PENDING
- VERIFIED
- DEFERRED
- BLOCKED — <concrete reason>
- HISTORICAL

## WIP and shared claim

Default: one `BUILDING` backlog ticket at a time.

`active_claim.json` is the single shared implementation mutex. A valid `BUILDING` row and the lock must mirror the same:

- ticket ID;
- owner;
- claimed timestamp;
- branch;
- authority reference.

A claim or release is **not** a one-file edit. Update `status.csv` and `active_claim.json` together, run the coordination check, and publish/merge that transaction to current `main`.

The implementation branch starts only after the claim is visible on `main`. Do not begin substantive source work from an unlocked/stale baseline and plan to “fix the ledger later.”

When the current implementation is externally blocked, record that concrete blocked state and release the shared lock in the same transaction before the dashboard/coordinator activates another non-overlapping candidate.

Do not spawn one agent per lane and let them chew through the spreadsheet independently.

## Claim conflict behavior

The shared lock is deliberately a single Git contention path. If another claim lands first:

- do not force-push;
- do not choose your version of `active_claim.json` during conflict resolution;
- do not create a second lock file;
- do not keep coding on an unowned branch.

Fetch current `main`, run the coordination check, and resume/reconcile the ticket that owns the published lock.

There is no automatic claim timeout. A stale-looking lock is evidence to investigate, not permission to steal ownership.

## Implementation rules

For each authorized ticket:

1. Confirm its atomic claim is already published on `main`.
2. Confirm the implementation branch matches the lock and starts from a baseline containing the claim.
3. Inspect the existing implementation first.
4. Identify canonical owner/extension seam.
5. Implement only the scoped requirement.
6. Preserve server authority.
7. Do not trust client-submitted damage, target, position, timestamp, cooldown, currency, inventory, progression, reward, or ownership.
8. Do not create a second authoritative state or presentation owner.
9. Prefer pure deterministic resolvers and validated config for repeatable decisions.
10. Preserve stable IDs/contracts and lifecycle cleanup.
11. Add focused regression coverage for meaningful behavior changes.
12. Run the ticket's minimum validation tier.
13. Record runtime/Studio evidence accurately.
14. Merge only after the applicable repository gate is satisfied.
15. Re-check current main/open PRs and any required post-merge evidence.
16. Close out the ticket in `status.csv` with PR/commit/proof and truthful status.
17. Set `active_claim.json` to `UNLOCKED` in that same closeout transaction.
18. Run the coordination check and publish/merge closeout.
19. Re-read the dashboard after closeout before claiming more work.

Implementation merge alone does not release the claim.

## Risk tiers

### R0
Docs/non-runtime metadata:
`python scripts/validate.py docs`

### R1
Presentation/pure resolver/config/tooling/low-consequence logic:
`python scripts/validate.py fast`
Use full validation when CI/risk scope requires it.

### R2
Gameplay authority/remotes/combat/mission/inventory/progression behavior:
`python scripts/validate.py full`

### R3
Persistence/value/migrations/security/rollback-critical changes:
`python scripts/validate.py full` plus focused targeted checks and any required evidence before unsafe/irreversible dependent steps.

## Studio boundary

Do not claim engine-only facts from source inspection.

Repository-complete work can advance to `BUILT — VERIFICATION PENDING`. That state may release the implementation lock after source completion/validation because missing ordinary Studio evidence is not itself a source-development lock; the pending evidence obligation remains in the ledger.

If an evidence pass reveals a reproducible runtime failure, that concrete failure preempts expansion.

## Acceptance

A ticket is source-complete only when:
- scoped implementation is complete;
- authority/lifecycle boundaries are preserved;
- applicable validation passes;
- focused regression coverage exists where useful;
- no unrelated regression is knowingly introduced;
- current open-PR overlap was resolved;
- PR/commit and proof are recorded;
- the closeout transaction is internally valid.

A ticket is `VERIFIED` only when any required runtime/Studio evidence also exists.

## Master coordinator prompt

```text
Operate as Living Kingdoms backlog coordinator.

First fetch current main. Read backlog/living-kingdoms/active_claim.json and status.csv, then run:
python backlog/living-kingdoms/materialize_backlog.py --check

If the shared claim is LOCKED, resume/reconcile that exact BUILDING ticket. Do not select another ticket until the existing claim is truthfully closed, blocked, transferred, or otherwise reconciled and the lock is released through a validated transaction.

Inspect current open PRs, read docs/roadmap/EXECUTION-DASHBOARD.md, root AGENTS.md, games/living-kingdoms/AGENTS.md, and backlog/living-kingdoms/AGENT_COORDINATION.md.

The 1,000-ticket backlog is candidate inventory only. It does not authorize work and does not replace the dashboard.

When the lock is UNLOCKED, identify the smallest LKB candidate that directly implements or de-risks the dashboard-selected current capability. Re-check its open-PR overlap guard and dependencies. Prefer the existing canonical owner/extension seam.

Authorize only one coherent implementation ticket at a time. Claim it by updating status.csv and active_claim.json together with matching ticket/owner/timestamp/branch/authority data. Run the coordination check and publish/merge the claim to main before substantive implementation begins.

Do not authorize broad Patch 0.8/0.9/conditional work merely because it appears in the backlog. Do not create one module per LK taxonomy concern. Preserve the repository's low-WIP rule.

After successful implementation merge, record BUILT — VERIFICATION PENDING or VERIFIED accurately, capture PR/commit/proof, unlock active_claim.json in the same closeout transaction, validate it, publish closeout to main, then re-read current main/dashboard before authorizing the next candidate.
```

## Master specialist prompt

```text
You are the specialist owner for one dashboard-authorized Living Kingdoms backlog ticket.

Read root AGENTS.md, games/living-kingdoms/AGENTS.md, backlog/living-kingdoms/AGENT_COORDINATION.md, the current Execution Dashboard, status.csv, and active_claim.json.

Do not start unless the LKB ticket is AUTHORIZED + BUILDING, the shared active claim matches its ticket/owner/timestamp/branch/authority exactly, that claim is published on the main baseline for your branch, and no active PR duplicates the scope.

Inspect the existing source/tests/config, extend the canonical owner, implement the smallest coherent scope, validate at the listed risk tier, preserve server authority, and add focused regression protection.

If source work is complete but Studio/device evidence remains, close out as BUILT — VERIFICATION PENDING. Never claim VERIFIED without the required evidence.

If requirements conflict, a dangerous migration is unclear, authority would fork, current source/open PRs invalidate the ticket assumption, or the shared lock no longer names your work, stop substantive edits and return the state to the coordinator rather than guessing or overriding ownership.
```
