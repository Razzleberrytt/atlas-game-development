# Atlas — Automated-First Execution Policy

**Status:** CURRENT EXECUTION-CADENCE AUTHORITY  
**Adopted:** 2026-08-13  
**Refreshed:** 2026-08-16  
**Scope:** implementation cadence, automated merge gates, and the role of manual Roblox Studio/device/play evidence.  
**Task selection authority:** [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md).

## Core rule

Routine source development proceeds through **automated repository validation first**. Missing ordinary Studio/device/play evidence does not create a blanket source freeze.

```text
dashboard-selected task
→ fetch fresh main + inspect open PR overlap
→ implement smallest coherent increment
→ run risk-appropriate automated validation
→ fix deterministic failures
→ merge only when required gate is green
→ update execution/coverage truth if materially changed
→ continue
```

This policy controls cadence. It does **not** choose the current feature/patch; the dashboard does.

## Manual evidence is evidence, not ordinary permission

Manual Studio/device/play checks remain valuable for facts automation cannot establish, including:

- game feel and responsiveness;
- visual/audio readability;
- real-device controls/safe areas;
- terrain/world composition;
- streaming/live timing;
- multiplayer timing;
- representative memory/performance;
- publishing/asset behavior.

Do not mark ordinary source work blocked merely because one of those checks has not yet run.

Earlier runtime evidence becomes mandatory when:

1. a reproducible runtime failure has already invalidated an assumption; or
2. continuing would cross an irreversible/high-consequence persistence, security, migration, or platform boundary that cannot be safely bounded by source/tests alone.

In those cases the **concrete defect or risk** is the blocker, not the abstract absence of testing.

## Status language

Execution status remains the repository-wide vocabulary:

- **NOT STARTED**
- **BUILDING**
- **BUILT — VERIFICATION PENDING**
- **VERIFIED**
- **DEFERRED**
- **BLOCKED — <concrete reason>**
- **HISTORICAL**

A source increment may be **BUILT — VERIFICATION PENDING** after its required automated checks pass while player/engine evidence is still unmeasured. This is not a scheduling lock.

When a patch has an explicit machine-readable automated acceptance artifact, the dashboard may additionally describe that patch as **automated-acceptance complete**. That phrase never means subjective/runtime evidence was measured if it was not.

Development-coverage states (`partial`, `substantial`, etc.) are a separate ontology and never substitute for execution status.

## Required automated validation

Use the canonical repository entry point and risk tiers from root `AGENTS.md`:

```bash
python scripts/validate.py docs
python scripts/validate.py fast
python scripts/validate.py full
```

Depending on scope, this covers:

- documentation/authority integrity;
- development-coverage registry/generated-view integrity;
- repository/layout validation;
- formatting/linting;
- Lune/unit/regression fixtures;
- deterministic simulations;
- Rojo builds;
- source ownership/trust-boundary audits;
- content/schema/reference validation;
- persistence/migration/recovery invariants;
- Main World topology/readability/artifact checks;
- machine-readable patch acceptance where still applicable.

Known branch-caused deterministic failures are fixed before merge. Do not weaken tests or validation to force green.

## Patch progression

Patch boundaries organize product scope; they do not independently choose the current work.

- The dashboard activates the current lane/patch/capability.
- A patch may advance on automated source work while manual evidence remains pending when doing so is dependency-safe.
- A reproducible runtime failure preempts dependent expansion.
- Historical batch mechanics do not remain active after the dashboard closes that patch.

**Patch 0.7 note:** its former 10-task automated batching process is closed historical execution detail. The dashboard records its current acceptance truth; this policy no longer tells agents to execute Patch 0.7 batches.

## Broad audit / exhaustive-improvement requests

Use the development coverage system to classify breadth without replacing the dashboard:

```bash
python scripts/development_coverage.py report
```

Then route candidate work through `LK concern → canonical engine → real owner → dependency/PR check → implementation → validation → evidence/coverage update`.

Coverage health is not automatic priority. Current defects, player value, dependencies, and dashboard selection remain controlling.

## Agent rule for “continue”

1. fetch current `main`;
2. inspect open PRs for overlap, freshness, stack dependencies, and superseding work;
3. read the execution dashboard;
4. fix a concrete blocking regression first when one exists;
5. otherwise implement the dashboard-selected coherent increment;
6. run the required automated gate;
7. merge only when green under repository WIP/merge rules;
8. record pending manual evidence truthfully without inserting an artificial stop;
9. update dashboard/coverage only when their truth materially changed;
10. continue until the dashboard queue is exhausted or a real named blocker prevents safe progress.

> **Automation gates source merges. Evidence gates claims. The dashboard chooses the work.**
