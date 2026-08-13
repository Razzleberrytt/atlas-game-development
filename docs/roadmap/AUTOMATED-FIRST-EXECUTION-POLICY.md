# Atlas — Automated-First Execution Policy

**Status:** CURRENT EXECUTION AND VERIFICATION AUTHORITY  
**Adopted:** 2026-08-13  
**Scope:** task sequencing, merge gates, patch progression, and the role of manual Roblox Studio/device/play checks.  
**Supersedes for scheduling:** any older STOP/PLAY/FIX, Studio gate, device gate, playtest gate, acceptance handoff, or patch transition that requires manual evidence before ordinary source work can continue.

## Required development gate

The required gate for routine implementation is **automated repository validation**.

```text
highest-ROI ranked task
→ implement
→ canonical automated validation
→ fix deterministic failures
→ merge when green
→ activate the next ranked task/batch
```

Manual Studio/device/play checks are optional evidence. They do not block source work, do not occupy NOW/NEXT by default, and do not prevent a patch from advancing through its automated task plan.

## Manual checks are never a permission gate

Do not mark work blocked, gated, waiting, stopped, or ineligible solely because manual testing has not happened.

Manual evidence becomes an immediate task only when:

1. the user explicitly asks for that evidence; or
2. an actual runtime observation has already exposed a reproducible defect.

In the second case, the defect is the blocker. Missing additional testing is not.

## Truthful status language

Use:

- **BUILDING** — implementation is active.
- **BUILT — AUTOMATED GREEN** — applicable automated checks pass.
- **AUTOMATED ACCEPTANCE COMPLETE** — the patch's machine-readable acceptance matrix is green.
- **UNMEASURED** — an experiential/runtime fact has not been manually measured; informational only.
- **VERIFIED — MANUAL EVIDENCE** — optional manual evidence actually passed for the stated fact.
- **BLOCKED — <concrete reason>** — a named technical condition prevents safe/correct continuation.

Do not use `BUILT — VERIFICATION PENDING` as a scheduling gate. Existing historical occurrences do not stop work.

## What automated validation must cover

Use the canonical repository gate (`python scripts/validate.py full` / CI equivalent) and its component checks as applicable:

- roadmap/authority integrity;
- repository/layout validation;
- formatting/linting;
- unit/regression fixtures;
- deterministic seeded simulations;
- Rojo builds;
- source ownership and trust-boundary audits;
- schema/reference/content validators;
- persistence/migration/recovery invariants;
- machine-readable patch acceptance rows.

Known deterministic failures are fixed before merge unless they are proven unrelated on the same base.

## What manual evidence may still measure

Automation should not invent claims about subjective feel, visual/audio readability, real-device ergonomics, representative live memory/performance, or publishing behavior. Those facts may remain **UNMEASURED** indefinitely without stopping routine source progress.

If optional manual evidence later reveals a reproducible issue, convert that issue into the highest-ROI repair task and continue after the repair is automated-green.

## Patch progression

Patch boundaries organize work; they do not require a human handoff.

For Patch 0.7, `PATCH-0.7-100-TASK-ROI-BACKLOG.md` is the active task authority. Execute exactly 10 ranked tasks at a time, merge after the automated gate is green, mark the batch DONE, then activate the next 10.

## Agent rule for “continue”

1. fetch current `main`;
2. inspect open PRs;
3. read the active ranked backlog;
4. identify concrete technical blockers, if any;
5. otherwise implement the current 10-task batch;
6. run canonical automated validation;
7. merge green work;
8. update the backlog;
9. immediately make the next 10 the active batch.

No Studio handoff or manual-testing request is inserted automatically.
