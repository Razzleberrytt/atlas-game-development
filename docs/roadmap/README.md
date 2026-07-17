# Living Kingdoms Roadmap Index

Use the roadmap documents in this order:

1. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — completed milestone history, preserved foundation work, and high-level P0–P12 sequence.
2. [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) — current status and the canonical PR-sized process for completing every remaining MVP gameplay task.
3. [`SEQUENCING-EXCEPTION-P6-P7.md`](SEQUENCING-EXCEPTION-P6-P7.md) — temporary narrow exception allowing completed `P7-0101` declarations and `P7-0102` class selection/assignment while P6 Studio evidence is deferred; all consequential class-effect runtime remains blocked.
4. [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — cross-cutting production-art sequence for replacing placeholder weapons, operatives, enemies, world objects, effects, audio, and optional cosmetic skins without changing gameplay authority.

When the documents differ in detail for unfinished P6–P12 gameplay work, the execution roadmap controls task IDs, dependencies, acceptance gates, execution order, and current status except for the explicitly bounded temporary exception above. The visual-production track controls presentation-asset sequencing only and may not override gameplay dependencies or authority boundaries. The master roadmap continues to control completed history and the overall milestone order.

Specifications define the behavior inside a roadmap task. The active specifications are linked from the applicable roadmap, including:

- [`../specifications/ammunition-scarcity-and-supply.md`](../specifications/ammunition-scarcity-and-supply.md) for the remaining P6 evidence and tuning process;
- [`../specifications/mvp-specialist-classes.md`](../specifications/mvp-specialist-classes.md) for the P7 class contracts, selection boundary, and blocked action runtime;
- [`../specifications/visual-asset-production.md`](../specifications/visual-asset-production.md) for visual direction, placeholder replacement, model/rig/skin authority boundaries, asset sourcing, performance budgets, and review gates.

A task moves to complete only after its applicable Definition of Done, automated validation, required Studio evidence, documentation, and status update are all satisfied. A deferred manual gate remains deferred—not passed—until its evidence is recorded.