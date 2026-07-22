# Living Kingdoms Roadmap Index

Use the roadmap documents in this order:

1. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — the per-milestone status table, completed milestone history, preserved foundation work, and the full P0–P12 sequence with task-level breakdowns for every milestone.
2. [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) — the canonical PR-sized process, full acceptance gates, and controlling status for every remaining P6–P12 gameplay task. The master roadmap mirrors these tasks for one-document readability; when they drift, this file wins for unfinished work.
3. [`SEQUENCING-EXCEPTION-P6-P7.md`](SEQUENCING-EXCEPTION-P6-P7.md) — closed historical exception that allowed `P7-0101` declarations and `P7-0102` class selection/assignment before P6 prototype sign-off.
4. [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — cross-cutting production-art sequence for replacing placeholder weapons, operatives, enemies, world objects, effects, audio, and optional cosmetic skins without changing gameplay authority.
5. [`../specifications/rpg-integration-plan.md`](../specifications/rpg-integration-plan.md) — the active cross-cutting RPG sequence. It controls `RPG-0101`–`RPG-0113`, records merged work through `RPG-0106`, and defines the relic, reward, presentation, result, and validation work that follows.
6. [`RECOMMENDED-PASSES.md`](RECOMMENDED-PASSES.md) — descriptive cross-reference collecting every production pass (art, audio, effects, tuning, audit, accessibility) the canon recommends, suggests, or defers; it controls no task IDs, ordering, or acceptance gates.

When the documents differ in detail for unfinished P6–P12 gameplay work, the execution roadmap controls task IDs, dependencies, acceptance gates, execution order, and current status. The visual-production track controls presentation-asset sequencing only. The RPG plan controls only its `RPG-*` cross-cutting sequence and may not mark a P6–P12 milestone gate complete or introduce a later milestone owner early. The master roadmap continues to control completed history and the overall milestone order.

Specifications define the behavior inside a roadmap task. The active specifications are linked from the applicable roadmap, including:

- [`../specifications/ammunition-scarcity-and-supply.md`](../specifications/ammunition-scarcity-and-supply.md) for the completed prototype scarcity boundary and deferred P12 measurement limitation;
- [`../specifications/mvp-specialist-classes.md`](../specifications/mvp-specialist-classes.md) for the P7 class contracts, selection boundary, and next action runtime;
- [`../specifications/authored-objective-chain.md`](../specifications/authored-objective-chain.md) for the P8 authored objective chain — the two required objectives, the optional engineer repair, their landmarks, order, class opportunities, escalation, and relocation pressure that `P8-0101`–`P8-0108` implement;
- [`../specifications/rpg-integration-plan.md`](../specifications/rpg-integration-plan.md) for the active operation-bound RPG layer, including completed Field Upgrade and elite work, the next relic/reward framework, modifier ownership, phased tasks, and the boundary reserving permanent progression for the later authoritative result/persistence sequence;
- [`../specifications/visual-asset-production.md`](../specifications/visual-asset-production.md) for visual direction, placeholder replacement, model/rig/skin authority boundaries, asset sourcing, performance budgets, and review gates.

The RPG integration sequence is active through its own explicit task order. This parallel sequence does not bypass outstanding HROI/RPG Studio evidence or dependencies on future objective, boss, result, and persistence owners. P6 prototype sign-off has independently unblocked normal P7 sequencing.

A task moves to complete only after its applicable Definition of Done, automated validation, required Studio evidence, documentation, and status update are all satisfied. A deferred manual gate remains deferred—not passed—until its evidence is recorded.
