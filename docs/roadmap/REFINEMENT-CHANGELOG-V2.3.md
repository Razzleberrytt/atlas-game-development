# Version 2.3 Refinement Changelog — Historical Handoff

Version 2.3 is no longer active execution authority. Its refinement work is preserved as project history and is superseded operationally by Version 2.7.

## What v2.3 established

- one document-precedence model;
- explicit mechanical, replication, presentation, authoring, operational, and historical authority classes;
- cross-system ownership and cleanup responsibilities;
- listener-before-ready startup direction;
- snapshot/delta presentation semantics;
- centralized Highlight ownership direction;
- streaming-safe presentation rules;
- animation-marker, viewmodel, and camera lifecycle rules;
- Full / Reduced / Minimum Readable presentation tiers;
- incident closure as evidence rather than assumption.

## What v2.7 adds

Version 2.7 turns those principles into an active rollout system:

- Tickets 331–360;
- R0–R5 staged migration;
- producer/consumer cutover ledger;
- semantic-key publishing and unchanged-state suppression;
- explicit ClientReady gating;
- one shared Highlight registry;
- named runtime baselines;
- reset/respawn/late-join/two-player soak gates;
- rollback checkpoints;
- compatibility-removal criteria;
- closure packets for the network and Highlight incidents.

## Current authority

Use [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md), [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md), and [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md).

The original v2.3 changelog remains available through Git history. This wrapper exists so direct links cannot be mistaken for current instructions.
