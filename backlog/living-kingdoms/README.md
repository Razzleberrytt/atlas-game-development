# Living Kingdoms — 1,000-Ticket Candidate Backlog

This directory is a **planning and execution-support inventory**, not a second roadmap.

## One-command launch

The repository-level launch contract is `BEGIN_BACKLOG_PROCESS.md`.

When the user says **“begin the backlog process”**, treat that as sufficient authorization to start/resume the coordinator loop defined there. Do not ask the user to manually select a ticket, lane, branch, or priority when repository authority can resolve the choice.

The launch is **resume-first**: inspect and validate the shared active claim first. If one valid ticket is already `BUILDING`, reconcile/resume it; otherwise select the smallest eligible dashboard-aligned candidate, atomically claim it, route it to the correct specialist, implement/validate/merge it, close out and release the claim, then continue until a real stop condition is reached.

## Authority rule

Before any backlog ticket is activated, read:

1. `docs/roadmap/EXECUTION-DASHBOARD.md`
2. root `AGENTS.md`
3. `games/living-kingdoms/AGENTS.md`

Accepted runtime evidence/current Roblox behavior and the Execution Dashboard outrank this backlog. The dashboard's NOW/NEXT/LATER selection and WIP rules remain authoritative.

The `LKB-0001`–`LKB-1000` IDs are deliberately separate from the repository's `LK-001`–`LK-300` development-coverage ontology. The 300-area taxonomy measures coverage; this backlog stores candidate work.

## Files

- `workstreams.json` — 40 auditable game workstreams with lane, phase, risk, priority, canonical-owner hints, tags, and PR-overlap guards.
- `dimensions.json` — 25 auditable implementation/QA dimensions with scoped title/instruction/acceptance templates and dependencies.
- `status.csv` — sparse mutable ledger for authorization, ownership, status, branch, blocker, and proof.
- `active_claim.json` — single shared implementation mutex. It must mirror the one `BUILDING` ticket or be `UNLOCKED` when no ticket is building.
- `materialize_backlog.py` — deterministically generates exactly `40 × 25 = 1,000` readable tickets in `master_backlog.csv`, overlays live status, and validates the ledger/lock protocol.
- `AGENT_COORDINATION.md` — specialist lane, atomic claim/release, handoff, and low-WIP protocol.
- `IMPLEMENTATION_PLAYBOOK.md` — ticket implementation/validation contract.
- `/BEGIN_BACKLOG_PROCESS.md` — exact user-command launch/resume protocol.

Validate coordination state without creating generated output:

```bash
python backlog/living-kingdoms/materialize_backlog.py --check
```

Generate the readable view:

```bash
python backlog/living-kingdoms/materialize_backlog.py
```

`master_backlog.csv` is generated and intentionally ignored by Git. Ticket definitions are reviewable in the two JSON source files instead of being stored as an opaque generated blob.

The coordination check is also part of `python scripts/validate.py docs`, and therefore of the broader validation profiles/CI that call the docs checks.

## Critical difference from the website backlog

Living Kingdoms already has a strong current execution authority and intentionally low implementation WIP.

**Do not start several specialist agents on several candidate tickets at once.**

Specialists exist as ownership lanes, but the coordinator activates work sequentially from the dashboard-selected capability. By default every backlog item is:

- `Status = NOT STARTED`
- `Authorization = CANDIDATE`

A ticket cannot become `BUILDING` until it has:

- `Authorization = AUTHORIZED`
- a concrete `Authority Reference` to the current dashboard/accepted execution decision
- one `Owner`
- one working branch matching `lk/LKB-####-short-description`
- a timezone-aware ISO-8601 `Claimed At` timestamp
- a matching `LOCKED` record in `active_claim.json`

The validator rejects more than one `BUILDING` ticket, a lock/ledger mismatch, malformed claim metadata, invalid branch naming, missing proof for completed states, and invalid blocker state.

## Why the shared lock exists

`status.csv` is excellent as an audit ledger, but separate ticket rows alone do not serialize concurrent agents. `active_claim.json` gives every claim and release one common Git path.

A claim transaction must update `status.csv` and `active_claim.json` together and publish/merge to current `main` **before substantive source work begins**. A second agent working from the same unlocked baseline will collide on that shared file or fail a stale-SHA update once the first claim lands. The correct response is to fetch current `main` and respect the winning claim—not force through a second one.

The lock has no time-based expiry. Stale-looking claims are reconciled from current evidence, PR state, and dashboard authority.

## Claim lifecycle

Normal lifecycle:

```text
UNLOCKED
→ coordinator selects one authorized ticket
→ status.csv = BUILDING + active_claim.json = LOCKED
→ publish claim to main
→ specialist implementation branch/PR
→ merge implementation after required gate
→ post-merge evidence/audit
→ status.csv = BUILT — VERIFICATION PENDING / VERIFIED / BLOCKED
  + active_claim.json = UNLOCKED
→ publish closeout to main
→ next ticket may be claimed
```

An implementation merge alone does not free WIP. The shared lock remains authoritative until the validated closeout transaction lands.

If current implementation is externally blocked, record the concrete `BLOCKED — <reason>` state and unlock in the same transaction before activating a dashboard-permitted non-overlapping fallback ticket.

## Open-PR overlap

The backlog definitions include an `Open PR Overlap Guard` field. Before activation, inspect current open PRs and current `main`. Old candidate PRs are not automatically current work; reconcile them only when they still match current authority and architecture.

## Status vocabulary

Use repository vocabulary:

- `NOT STARTED`
- `BUILDING`
- `BUILT — VERIFICATION PENDING`
- `VERIFIED`
- `DEFERRED`
- `BLOCKED — <concrete reason>`
- `HISTORICAL`

The structured status ledger also records authorization separately so candidate inventory cannot silently become execution authority.

## Branch convention

Use:

`lk/LKB-####-short-description`

A branch has one implementation owner. Ownership transfer requires an atomic ledger + lock transfer published before the new owner edits source.

## Done / Verified

Repository-source completion may be `BUILT — VERIFICATION PENDING` when Studio/device evidence remains.

Do not claim `VERIFIED` without the evidence required by the ticket and repo policy. Closeout must record PR/commit/proof and release the lock only after the applicable evidence is evaluated.
