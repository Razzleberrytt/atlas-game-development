# Atlas Roadmap Index

**Blueprint v2.7 is the active production authority as of 2026-08-07.** It supersedes v2.3 for execution order, active-place rollout, observability, presentation ownership, and promotion gates.

The adoption of v2.7 is a documentation/authority change. It does **not** claim that the active Roblox Studio place is repaired or that the project has advanced beyond its currently accepted evidence level.

## Active roadmap

1. [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md) — controlling execution authority. Defines precedence, evidence rules, active Studio incidents, runtime-state contract, presentation ownership, rollout stages, Tickets 331–360, stop conditions, and the promotion gate.
2. [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md) — daily-use reference. Read this before implementation work to understand the current authority, runtime laws, active queue, and stop conditions.
3. [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md) — detailed R0–R5 migration procedure, cutover ledger, semantic publisher rules, counters, named baselines, rollback discipline, and incident closure packet.
4. [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md) — mechanical, replication, presentation, streaming/lifecycle, and evidence ownership for critical player-facing state.
5. [`QUALITY-AUDIT-V2.7.md`](QUALITY-AUDIT-V2.7.md) — what v2.7 changes, what its reference package proves statically, and what remains explicitly unproven in the active place.
6. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — current milestone-level roadmap. It summarizes the v2.7 rollout gate and what becomes eligible only after runtime acceptance.
7. [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — cross-cutting art/presentation production sequence. It controls asset sequencing only and remains subordinate to the active v2.7 dependency queue and runtime stop conditions.

## Current active gate

The active-place incident evidence still contains two stop-condition symptoms:

1. `ReplicatedStorage.HordeNetwork.State` invocation-queue exhaustion/discard warnings;
2. escaped broad blue/yellow `Highlight` presentation.

The screenshot proves the symptoms, not the exact cause. v2.7 therefore requires instrumentation, staged migration, and closure evidence rather than declaring either issue fixed in documentation.

The active dependency queue is **Tickets 331–360**:

```text
331–335  baseline + producer/consumer/Highlight inventory
336–345  earliest listener, ClientReady gate, semantic producer cutover
346–350  centralized route/landmark/Highlight ownership
351–360  reset/respawn/late-join/multiplayer/animation/soak closure
```

Ticket 360 removes compatibility **only** for ledger rows with accepted replacement evidence and a retained rollback checkpoint.

## Precedence

```text
accepted runtime evidence / current Roblox platform behavior
→ BLUEPRINT-V2.7-EXECUTION.md + PRODUCTION-CORE-V2.7.md
→ ACTIVE-PLACE-ROLLOUT-V2.7.md + CROSS-SYSTEM-TRACEABILITY-V2.7.md
→ current specialist bibles and accepted specifications
→ ../architecture/technical-blueprint.md
→ historical roadmap checkpoints
```

A task moves to complete only after its applicable Definition of Done, automated validation, required Studio/runtime evidence, documentation, and status update are satisfied. A manual/runtime gate remains deferred—not passed—until the evidence is recorded.

## Evidence scale

```text
E0 design only
E1 source assembled/static acceptance
E2 Studio starts and systems initialize
E3 single-player integrated behavior demonstrated
E4 multiplayer/adversarial behavior demonstrated
E5 device/performance/reliability demonstrated
E6 outside-player fun demonstrated
E7 live telemetry demonstrated
```

Roadmap adoption does not promote evidence level.

## Historical checkpoints

These files are retained for provenance and completed-work context. They no longer control execution:

- [`BLUEPRINT-V2.3-EXECUTION.md`](BLUEPRINT-V2.3-EXECUTION.md) — previous active authority, Tickets 211–240.
- [`PRODUCTION-CORE-V2.3.md`](PRODUCTION-CORE-V2.3.md) — previous daily authority.
- [`CROSS-SYSTEM-TRACEABILITY-V2.3.md`](CROSS-SYSTEM-TRACEABILITY-V2.3.md) — previous ownership matrix.
- [`QUALITY-AUDIT-V2.3.md`](QUALITY-AUDIT-V2.3.md) — previous refinement audit.
- [`REFINEMENT-CHANGELOG-V2.3.md`](REFINEMENT-CHANGELOG-V2.3.md) — v2.3 change history.
- [`STUDIO-TRIAGE-CHECKLIST-V2.3.md`](STUDIO-TRIAGE-CHECKLIST-V2.3.md) — previous incident checklist; useful as history, superseded by the v2.7 rollout procedure.
- [`BLUEPRINT-V2.0-EXECUTION.md`](BLUEPRINT-V2.0-EXECUTION.md) — earlier authority; durable-value work remains useful context but is gated behind current runtime acceptance.
- [`BLUEPRINT-V1.9-EXECUTION.md`](BLUEPRINT-V1.9-EXECUTION.md) — earlier ticket-numbered predecessor.
- [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) — historical PR-sized milestone breakdown.
- [`UNIFIED-MASTER-ROADMAP.md`](UNIFIED-MASTER-ROADMAP.md) — earlier consolidated roadmap.
- [`RECOMMENDED-PASSES.md`](RECOMMENDED-PASSES.md) — descriptive historical cross-reference; it does not override v2.7 ticket order.
- [`SEQUENCING-EXCEPTION-P6-P7.md`](SEQUENCING-EXCEPTION-P6-P7.md) — closed sequencing exception.
- [`REPLAY-DECISION-STATUS.md`](REPLAY-DECISION-STATUS.md) and [`LIVE-LOBBY-INTEGRATION-NOTE.md`](LIVE-LOBBY-INTEGRATION-NOTE.md) — point-in-time status notes.

Source comments that cite an older blueprint/ticket remain valid provenance for completed work; they are not current execution orders.

## Supporting specialist documents

Specifications in [`../specifications/`](../specifications/) define behavior inside a task where they do not conflict with v2.7 authority, lifecycle, security, or presentation ownership.

Current specialist bibles under [`../bible/`](../bible/) remain useful for visual and Studio integration detail. Their older version number does not make them higher authority than v2.7; use them as specialist requirements where v2.7 has not superseded the rule.

Frequently referenced supporting docs:

- [`../architecture/technical-blueprint.md`](../architecture/technical-blueprint.md)
- [`../specifications/rpg-integration-plan.md`](../specifications/rpg-integration-plan.md)
- [`../specifications/mvp-specialist-classes.md`](../specifications/mvp-specialist-classes.md)
- [`../specifications/authored-objective-chain.md`](../specifications/authored-objective-chain.md)
- [`../specifications/visual-asset-production.md`](../specifications/visual-asset-production.md)
- [`../production/RBXL-IMPORT-MIGRATION.md`](../production/RBXL-IMPORT-MIGRATION.md)
- [`../production/SMOKE-TEST.md`](../production/SMOKE-TEST.md)

## Agent execution rule

Agents should implement the **lowest-numbered incomplete v2.7 ticket that can honestly be completed in the available environment**. Do not skip a runtime evidence gate by replacing it with a source-only test. Do not add broader gameplay scope while a v2.7 stop condition remains open.

> Instrument first. Migrate one owner at a time. Remove compatibility only when the evidence says the bridge is empty.
