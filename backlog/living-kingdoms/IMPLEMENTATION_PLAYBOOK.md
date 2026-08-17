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
2. Inspect open PRs for overlap/staleness.
3. Read dashboard NOW/NEXT/LATER and stop conditions.
4. Read `games/living-kingdoms/AGENTS.md`.
5. Run relevant coverage/efficiency tooling for broad cross-system work.
6. Materialize this backlog.
7. Select only a candidate that directly serves the current authorized capability.

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

## WIP

Default: one `BUILDING` backlog ticket at a time.

When the current implementation is externally blocked, record that concrete blocked state before the dashboard/coordinator activates another non-overlapping candidate.

Do not spawn one agent per lane and let them chew through the spreadsheet independently.

## Implementation rules

For each authorized ticket:

1. Claim it in `status.csv`.
2. Inspect the existing implementation first.
3. Identify canonical owner/extension seam.
4. Implement only the scoped requirement.
5. Preserve server authority.
6. Do not trust client-submitted damage, target, position, timestamp, cooldown, currency, inventory, progression, reward, or ownership.
7. Do not create a second authoritative state or presentation owner.
8. Prefer pure deterministic resolvers and validated config for repeatable decisions.
9. Preserve stable IDs/contracts and lifecycle cleanup.
10. Add focused regression coverage for meaningful behavior changes.
11. Run the ticket's minimum validation tier.
12. Record runtime/Studio evidence accurately.
13. Record PR/commit/proof in `status.csv`.
14. Re-read the dashboard after merge before claiming more work.

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

Repository-complete work can advance to `BUILT — VERIFICATION PENDING`. Group Studio/device evidence when repo policy allows it.

If an evidence pass reveals a reproducible runtime failure, that concrete failure preempts expansion.

## Acceptance

A ticket is source-complete only when:
- scoped implementation is complete;
- authority/lifecycle boundaries are preserved;
- applicable validation passes;
- focused regression coverage exists where useful;
- no unrelated regression is knowingly introduced;
- current open-PR overlap was resolved;
- PR/commit and proof are recorded.

A ticket is `VERIFIED` only when any required runtime/Studio evidence also exists.

## Master coordinator prompt

```text
Operate as Living Kingdoms backlog coordinator.

First fetch current main, inspect current open PRs, read docs/roadmap/EXECUTION-DASHBOARD.md, root AGENTS.md, games/living-kingdoms/AGENTS.md, and backlog/living-kingdoms/AGENT_COORDINATION.md.

The 1,000-ticket backlog is candidate inventory only. It does not authorize work and does not replace the dashboard.

Run:
python backlog/living-kingdoms/materialize_backlog.py

Identify the smallest LKB candidate that directly implements or de-risks the dashboard-selected current capability. Re-check its open-PR overlap guard and dependencies. Prefer the existing canonical owner/extension seam.

Authorize only one coherent implementation ticket at a time by updating backlog/living-kingdoms/status.csv with Authorization=AUTHORIZED and a concrete Authority Reference. Route it to the matching specialist.

Do not authorize broad Patch 0.8/0.9/conditional work merely because it appears in the backlog. Do not create one module per LK taxonomy concern. Preserve the repository's low-WIP rule.

After the specialist merges successful work, record BUILT — VERIFICATION PENDING or VERIFIED accurately, then re-read current main/dashboard before authorizing the next candidate.
```

## Master specialist prompt

```text
You are the specialist owner for one dashboard-authorized Living Kingdoms backlog ticket.

Read root AGENTS.md, games/living-kingdoms/AGENTS.md, backlog/living-kingdoms/AGENT_COORDINATION.md, and the current Execution Dashboard.

Do not start unless the LKB ticket is AUTHORIZED with an Authority Reference and is not duplicated by an active PR.

Claim the ticket as BUILDING, inspect the existing source/tests/config, extend the canonical owner, implement the smallest coherent scope, validate at the listed risk tier, preserve server authority, and add focused regression protection.

If source work is complete but Studio/device evidence remains, record BUILT — VERIFICATION PENDING. Never claim VERIFIED without the required evidence.

If requirements conflict, a dangerous migration is unclear, authority would fork, or current source/open PRs invalidate the ticket assumption, record BLOCKED — <concrete reason> or return it to the coordinator rather than guessing.
```
