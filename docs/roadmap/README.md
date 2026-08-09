# Atlas Roadmap Index

This directory intentionally uses a **two-layer roadmap** instead of making every planning document compete for daily authority.

## Read first

1. [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md) — **current daily execution authority.** Read this first for progress, current lane, completed capabilities, remaining tasks, task-selection rules, and the next highest-ROI action.
2. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — detailed patch scope and acceptance intent for MVP 0.1 → 0.2–0.9 → release candidate.
3. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — complete product requirement inventory and long-range destination.

Supporting policy/safety authority:

- [`MVP-BUILD-THROUGH-TESTING-POLICY.md`](MVP-BUILD-THROUGH-TESTING-POLICY.md) — built-vs-verified status and milestone testing cadence.
- [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md) — genuine active runtime-safety/stabilization requirements while applicable gates remain open.
- [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md) — runtime production rules and current rollout mechanics.
- [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md) — current-state/presentation rollout and rollback evidence.
- [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md) — ownership and evidence traceability.
- [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md) — prepared dependency context; not the primary daily task queue.
- [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — specialist visual/environment production sequence.

Read [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) for current product identity before relying on older charters.

## Authority order

```text
accepted runtime evidence / current Roblox platform behavior
→ Blueprint v2.7 + Production Core v2.7 for concrete runtime-safety blockers
→ EXECUTION-DASHBOARD.md for daily task selection and progress truth
→ MVP-BUILD-THROUGH-TESTING-POLICY.md for built-vs-verified cadence
→ PLAYABLE-MVP-PATCH-EXECUTION.md for detailed patch scope
→ Current Product Authority + MASTER-ROADMAP.md for complete product direction
→ specialist specifications / architecture / visual-production guidance
→ historical roadmaps
```

A pending manual/Studio test is still pending until evidence exists. It does **not** automatically convert completed source work back into unfinished work or freeze dependency-safe development. A concrete failed runtime result does preempt later work.

## Current checkpoint — 2026-08-09

- **MVP 0.1 source implementation:** BUILT — VERIFICATION PENDING.
- **MVP 0.1 known source gaps:** none currently identified as required for the planned first complete run.
- **Human/Studio lane:** consolidated exact-build MVP 0.1 STOP / PLAY / FIX pass across the complete run, replay, keyboard/controller/touch and representative performance.
- **Agent/source lane:** Patch 0.2 Combat Feel + Readability; inspect overlapping open PR #316 before starting duplicate melee-presentation work.
- **Estimated path to 1.0:** roughly 30% as a planning indicator only; evidence/status labels remain authoritative.

See [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md) for the maintained progress table and task list.

## Status vocabulary

Use:

```text
NOT STARTED
BUILDING
BUILT — VERIFICATION PENDING
VERIFIED
DEFERRED
BLOCKED — concrete reason required
HISTORICAL
```

Avoid ambiguous labels such as `mostly done`, `basically complete`, or generic `locked` without a concrete dependency reason.

## Agent rule

When asked to `continue`, `implement next roadmap task`, or equivalent:

1. fetch current `main`;
2. inspect open PRs for overlap;
3. check for a concrete runtime-safety blocker or newly discovered milestone failure;
4. if one exists, fix it first;
5. otherwise read `EXECUTION-DASHBOARD.md` and select the highest-ROI unfinished task in the current lane;
6. run automated/static validation;
7. merge successful dependency-safe increments under the repository workflow;
8. mark source-complete work `BUILT — VERIFICATION PENDING` until milestone evidence exists;
9. update roadmap status only when meaningful progress, blockers or next-task truth changes.

## Historical documents

Older roadmap versions remain useful as provenance and idea inventory, but they are not daily execution authority. Examples include:

- `BLUEPRINT-V2.3-EXECUTION.md`
- `PRODUCTION-CORE-V2.3.md`
- `CROSS-SYSTEM-TRACEABILITY-V2.3.md`
- `QUALITY-AUDIT-V2.3.md`
- `BLUEPRINT-V2.0-EXECUTION.md`
- `BLUEPRINT-V1.9-EXECUTION.md`
- `P6-P12-EXECUTION-ROADMAP.md`
- `UNIFIED-MASTER-ROADMAP.md`
- `RECOMMENDED-PASSES.md`
- `SEQUENCING-EXCEPTION-P6-P7.md`

> **One dashboard for execution, one master map for scope. Build forward; verify coherent milestones.**