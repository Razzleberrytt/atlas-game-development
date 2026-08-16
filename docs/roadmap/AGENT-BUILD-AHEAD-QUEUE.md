# Atlas — Prepared Dependency Index

**Status:** CURRENT REFERENCE — NOT A TASK QUEUE  
**Refreshed:** 2026-08-16  
**Purpose:** preserve build-ahead/dependency guidance without competing with the execution dashboard.

The former Agent Build-Ahead Queue accumulated dated branch numbers, evidence snapshots, named-agent coordination, and “READY” task assignments while the project was navigating earlier v2.7 gates. That execution model is no longer current.

## Current rule

**Do not take work from this file by sequence or old status.**

For actual work:

1. fetch current `main`;
2. inspect open PRs for freshness/overlap/superseding work;
3. read [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md);
4. follow its NOW/NEXT selection;
5. use this file only to understand what forms of dependency-safe preparation are structurally acceptable.

Parallel work eligibility is governed by [`PARALLEL-DEVELOPMENT-POLICY.md`](PARALLEL-DEVELOPMENT-POLICY.md). WIP remains constrained by root `AGENTS.md`.

## Dependency-safe preparation forms

When the dashboard selects preparation/tooling or when a selected task requires a future-facing seam, acceptable forms include:

- pure contracts/types/resolvers;
- configuration/data definitions;
- dormant validated adapters/interfaces;
- held authored-world reconstruction;
- source/security/ownership audits;
- validators/tooling/diagnostics;
- migration manifests/reconciliation evidence;
- test fixtures;
- capability/extension/effect-route registries;
- development-coverage metadata;
- content definitions that are not incorrectly booted early.

Preparation must remain reversible, testable, and subordinate to canonical ownership.

## Build-ahead laws

1. Never create a second gameplay authority for combat, health, enemies, missions, rewards, inventory, progression, persistence, economy, networking, or presentation truth.
2. Recovered Studio gameplay services remain preservation/migration input unless explicitly reconciled into canonical owners.
3. Separate dormant preparation from runtime activation when risk/evidence differs.
4. Source CI does not prove Studio/device behavior.
5. Missing ordinary manual evidence alone is not a source lock.
6. A known reproducible runtime, authority, persistence, security, or data-safety defect preempts dependent preparation.
7. Every source change uses the current risk-tier validation gate.
8. Old open PRs are candidates, not reservations. Rebase/reconcile/revalidate before adoption.
9. No task is reserved to a named agent/tool/model.
10. The `LK-001`–`LK-300` taxonomy is coverage accounting; a gap does not automatically authorize build-ahead work.

## When a future seam should exist early

Early preparation is justified when at least one is true:

- the current task requires the contract to avoid future authority duplication;
- a repeated family needs a stable data/registry seam before scaling;
- a migration needs reversible compatibility scaffolding;
- a validator/evidence tool is required to prove the next coherent step;
- a known dependency can be safely removed without activating unverified gameplay;
- the preparation measurably reduces extension cost for imminent selected work.

Do not build speculative architecture solely because a later roadmap idea exists.

## Routing broad preparation

For broad cross-system preparation/audits:

```text
classify LK concern(s)
→ Development Atlas engine(s)
→ inspect capability/extension/effect-route registries
→ identify real owner/dependency
→ implement minimal preparation
→ validate
→ update coverage only if materially changed
```

## Historical note

Old BA-number task tables, E-level checkpoint narration, named PR “READY” rows, and 2026-08-09 sequential-agent assignments were intentionally removed from this current reference. Their provenance remains in Git history. Specialist v2.7 documents retain the technical/evidence details that still matter for that runtime boundary.

> **Preparation removes a real dependency. It does not manufacture future work, reserve branches, or outrank the dashboard.**
