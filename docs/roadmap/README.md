# Atlas Roadmap Index

**Blueprint v2.3 is the active production authority.** It replaced the v2.0 roadmap on 2026-08-07.

## Active roadmap

1. [`BLUEPRINT-V2.3-EXECUTION.md`](BLUEPRINT-V2.3-EXECUTION.md) — the controlling document. Release
   intent, authority order and conflict rule, evidence scale, the active Studio release blockers,
   cross-system runtime ownership, the dependency-ordered ticket 211–240 queue, and every quality
   gate. When any other document in this repository disagrees about what to build next, this file
   and captured runtime evidence win.
2. [`PRODUCTION-CORE-V2.3.md`](PRODUCTION-CORE-V2.3.md) — the daily-use reference: product laws,
   creative direction, provisional gameplay numbers, server-authority split, presentation
   ownership, the immediate 13-step critical path, stop conditions, and the daily review checklist.
3. [`STUDIO-TRIAGE-CHECKLIST-V2.3.md`](STUDIO-TRIAGE-CHECKLIST-V2.3.md) — run this before any broad
   refactor while the active place shows networking or presentation instability. Covers cold start,
   `HordeNetwork.State`, highlights, restart/respawn, streaming, animation, and the exit gate.
4. [`CROSS-SYSTEM-TRACEABILITY-V2.3.md`](CROSS-SYSTEM-TRACEABILITY-V2.3.md) — for each player
   promise: mechanical owner, presentation owner, visual dependency, and evidence gate. A row is
   not accepted because one column works.
5. [`QUALITY-AUDIT-V2.3.md`](QUALITY-AUDIT-V2.3.md) — structural checks, refinements over v2.2, and
   the runtime unknowns v2.3 deliberately does not guess.
6. [`REFINEMENT-CHANGELOG-V2.3.md`](REFINEMENT-CHANGELOG-V2.3.md) — what v2.3 changed, and what it
   explicitly did not change.
7. [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — cross-cutting production-art
   sequence for replacing placeholder weapons, operatives, enemies, world objects, effects, audio,
   and optional cosmetic skins without changing gameplay authority. Still current; it controls
   presentation-asset sequencing only, and is subordinate to ticket ordering.

Supporting specialist bibles live in [`../bible/`](../bible/):
[studio integration and presentation](../bible/studio-integration-presentation-bible-v2.3.md) for
runtime presentation architecture, and
[visual, environment, and animation](../bible/visual-environment-animation-bible-v2.3.md) for art
and animation production.

## Precedence

```text
accepted runtime evidence / current platform behavior
→ BLUEPRINT-V2.3-EXECUTION.md + PRODUCTION-CORE-V2.3.md
→ specialist bibles (Studio integration, visual/animation)
→ ../architecture/technical-blueprint.md
→ ../specifications/
→ historical checkpoints below
```

A task moves to complete only after its applicable Definition of Done, automated validation,
required Studio evidence, documentation, and status update are all satisfied. A deferred manual
gate remains deferred — not passed — until its evidence is recorded.

## Historical checkpoints

These documents are retained as context, not as orders. Per the v2.3 authority rule, historical
checkpoints are valuable because they show intended dependency order and original contracts; they
are **not** a requirement to preserve obsolete implementation shapes, and their closing directives
no longer control execution. Source-file comments referencing "Blueprint v2.0 queue item N" remain
accurate provenance for completed work.

- [`BLUEPRINT-V2.0-EXECUTION.md`](BLUEPRINT-V2.0-EXECUTION.md) — the previous authority. Its queue
  items 1–3 (owner-only inventory snapshots, item comparison and equip-to-combat handoff, dismantle
  and salvage transaction safety) are complete repo-side; items 4–10 are not cancelled but are
  gated behind v2.3 ticket 240.
- [`BLUEPRINT-V1.9-EXECUTION.md`](BLUEPRINT-V1.9-EXECUTION.md) — ticket-numbered predecessor still
  referenced by completed work (Tickets 142, 143).
- [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — the P0–P12 milestone history and completed milestone
  record.
- [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) — the previous PR-sized task
  breakdown and acceptance gates for P6–P12.
- [`UNIFIED-MASTER-ROADMAP.md`](UNIFIED-MASTER-ROADMAP.md) — earlier consolidated roadmap.
- [`RECOMMENDED-PASSES.md`](RECOMMENDED-PASSES.md) — descriptive cross-reference of recommended,
  suggested, and deferred production passes. Controls no task IDs, ordering, or acceptance gates.
- [`SEQUENCING-EXCEPTION-P6-P7.md`](SEQUENCING-EXCEPTION-P6-P7.md) — closed historical exception.
- [`REPLAY-DECISION-STATUS.md`](REPLAY-DECISION-STATUS.md),
  [`LIVE-LOBBY-INTEGRATION-NOTE.md`](LIVE-LOBBY-INTEGRATION-NOTE.md) — point-in-time status notes.

## Specifications

Specifications in [`../specifications/`](../specifications/) define the behavior inside a task and
remain in force where they do not conflict with v2.3 ownership, cleanup, or presentation rules.
The most frequently needed:

- [`../specifications/rpg-integration-plan.md`](../specifications/rpg-integration-plan.md) — the
  operation-bound RPG layer, completed Field Upgrade and elite work, modifier ownership, and the
  boundary reserving permanent progression for the authoritative result/persistence sequence.
- [`../specifications/mvp-specialist-classes.md`](../specifications/mvp-specialist-classes.md) —
  class contracts, selection boundary, and next-action runtime.
- [`../specifications/authored-objective-chain.md`](../specifications/authored-objective-chain.md)
  — the authored objective chain, its landmarks, order, class opportunities, escalation, and
  relocation pressure.
- [`../specifications/visual-asset-production.md`](../specifications/visual-asset-production.md) —
  visual direction, placeholder replacement, model/rig/skin authority boundaries, asset sourcing,
  performance budgets, and review gates.
- [`../specifications/ammunition-scarcity-and-supply.md`](../specifications/ammunition-scarcity-and-supply.md)
  — the completed prototype scarcity boundary and its deferred measurement limitation.
