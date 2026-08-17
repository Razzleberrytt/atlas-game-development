# Living Kingdoms — 1,000-Ticket Candidate Backlog

This directory is a **planning and execution-support inventory**, not a second roadmap.

## Authority rule

Before any backlog ticket is activated, read:

1. `docs/roadmap/EXECUTION-DASHBOARD.md`
2. root `AGENTS.md`
3. `games/living-kingdoms/AGENTS.md`

Accepted runtime evidence/current Roblox behavior and the Execution Dashboard outrank this backlog. The dashboard's NOW/NEXT/LATER selection and WIP rules remain authoritative.

The `LKB-0001`–`LKB-1000` IDs are deliberately separate from the repository's `LK-001`–`LK-300` development-coverage ontology. The 300-area taxonomy measures coverage; this backlog stores candidate work.

## Files

- `master_backlog.csv.xz.b64.part01`–`part04` — immutable compressed/base64 definitions for exactly 1,000 candidate tickets.
- `status.csv` — sparse mutable ledger for authorization, ownership, status, branch, blocker, and proof.
- `materialize_backlog.py` — concatenates/validates the four seed parts and generates a readable `master_backlog.csv`.
- `AGENT_COORDINATION.md` — specialist lane and low-WIP claim protocol.
- `IMPLEMENTATION_PLAYBOOK.md` — ticket implementation/validation contract.

Generate the readable view:

```bash
python backlog/living-kingdoms/materialize_backlog.py
```

`master_backlog.csv` is generated and intentionally ignored by Git.

The spreadsheet companion contains richer planning fields such as scope, acceptance criteria, ROI, canonical-owner hints, and evidence notes. The repository seed intentionally preserves the compact execution-routing identity needed by agents while the mutable ledger remains reviewable in Git.

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
- one working `Branch`
- an ISO-8601 `Claimed At` timestamp

The materializer rejects more than one `BUILDING` backlog ticket at a time.

If current implementation is externally blocked, record the concrete `BLOCKED — <reason>` state before activating a non-overlapping fallback ticket, consistent with repository policy.

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

A branch has one implementation owner.

## Done / Verified

Repository-source completion may be `BUILT — VERIFICATION PENDING` when Studio/device evidence remains.

Do not claim `VERIFIED` without the evidence required by the ticket and repo policy.
