# Roblox Studio Runtime Triage Checklist — Version 2.3 Historical

> **Superseded by [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md).**

This file is retained because Version 2.3 turned the original queue-exhaustion and escaped-Highlight symptoms into explicit regression scenarios. It no longer controls the active Studio procedure.

For current incident work use:

1. [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md)
2. [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md)
3. [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md)

The v2.7 procedure retains the useful v2.3 checks—cold start, producer/listener inventory, Highlight enumeration, reset/respawn leak checks, streaming rebinding, animation-listener stability, and soak evidence—but adds:

- R0–R5 rollout stages;
- producer/consumer cutover ledger;
- earliest-listener and ClientReady gates;
- semantic-key state publishing and unchanged-state suppression;
- centralized Highlight ownership;
- named B0–B6 baselines;
- rollback checkpoints;
- delayed-ready, late-join, and two-player closure tests;
- compatibility-removal criteria.

Do not mark a v2.7 ticket complete from this historical checklist. Accepted runtime evidence and the current rollout document control closure.
