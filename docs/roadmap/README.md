# Atlas Roadmap Index

**Master Roadmap v2.8 is the current milestone/product-path authority as of 2026-08-08.**  
**Blueprint v2.7 remains the active runtime execution authority until its rollout/evidence gates close.**

This split is intentional: v2.8 describes the complete destination; v2.7 controls what runtime work may actually happen now.

Read [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) before older product charters.

## Current roadmap stack

1. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — **v2.8 complete product path**. Covers product authority, runtime stabilization, Main World/environment, social/session infrastructure, persistence, progression, economy, content pipeline, vertical slice, quality, outside-player fun, analytics/E7, operations, compliance, localization, monetization, launch and post-launch expansion.
2. [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md) — **active runtime execution authority** for Tickets 331–360.
3. [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md) — daily runtime-production rules/current critical path.
4. [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md) — staged current-state/presentation migration, observability, rollback, soak and closure.
5. [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md) — mechanical/replication/presentation/lifecycle ownership and evidence gates.
6. [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md) — tasks agents may safely prepare while runtime evidence is blocked. Future v2.8 phases are not authorized unless this queue marks work READY.
7. [`QUALITY-AUDIT-V2.7.md`](QUALITY-AUDIT-V2.7.md) — static quality/refinement history for the active rollout.
8. [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — cross-cutting art/presentation sequence subordinate to gameplay/runtime gates and Studio review.

## Current runtime gate

Accepted evidence is **E2**, supported by the pinned-artifact R1/replay packet at
[`../production/evidence/2026-08-08-r1-playable-replay-loop.md`](../production/evidence/2026-08-08-r1-playable-replay-loop.md).

The 2026-08-08 Studio findings invalidated the older R1 artifact because an unrelated client-bootstrap stall prevented a trustworthy complete-client run. The replacement recorded artifact and fresh packet now satisfy R1.

The next runtime sequence is:

- rebase/revalidate PR #221's prepared single-listener consolidation against current `main`;
- capture its declared listener/presentation evidence while retaining the R1 rollback checkpoint;
- keep PR #222 blocked until consolidation is accepted;
- then execute R2 delayed-ready/current-state delivery evidence before R3 suppression.

## Current combined-world truth

The original damaged-import limitation is no longer current truth.

Current preservation/reconstruction status includes:

- 28/28 Studio-only sources preserved;
- 1,775/1,775 Workspace identity/hierarchy rows preserved;
- broad property-backed world/presentation recovery;
- stable world-content IDs and canonical ownership map;
- live Forward Operations Hub as a temporary preparation bridge;
- separate authored-overworld and modern-operation coordinate/lifecycle spaces;
- held source-managed WorldPath, DungeonPortal and quest-board reconstruction work.

Older migration/roadmap passages that cite only 122 recoverable Workspace rows remain historical provenance and must not be used as current reconstruction truth.

## v2.8 complete product phases

```text
A0    product authority reconciliation
R     active runtime rollout / incident closure
B     controlled build-ahead preparation
W     Main World + environment
S     party / social / matchmaking-session infrastructure
E     evidence promotion E2–E7
D     durable persistence / valuable state
M     long-term progression
ECON  economy / crafting / resource value
C     content production pipeline
V     first complete vertical slice
Q     quality / balance / device / performance / accessibility
F     outside-player fun + repeat-intent gate
T     production telemetry / E7
OPS   runtime configuration / staged rollout / rollback
SAFE  platform safety / security / compliance
LOC   localization readiness
MON   ethical monetization (locked behind F)
L     alpha → beta → soft launch → production launch
LIVE  post-launch operations and expansion
```

Most future phases remain `LOCKED`. Their presence is planning completeness, not implementation permission.

## Main World / environment policy

The Main World target loop is:

```text
Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return
```

Before broad environment generation, the build-ahead queue now requires a structured Main World/environment audit with KEEP/REFINE/REBUILD/REPLACE/REMOVE/MISSING disposition, navigation/landmark/traversal review, visual/environment/audio review, expansion-readiness review, streaming/performance review, and explicit Studio-only acceptance checks.

## Active production-control artifacts

- [`../production/V2.7-CUTOVER-LEDGER.md`](../production/V2.7-CUTOVER-LEDGER.md) — producer/consumer/presentation migration ledger.
- [`../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md`](../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md) — required structure for evidence-bearing Studio/runtime runs.
- [`../production/DEFINITION-OF-DONE.md`](../production/DEFINITION-OF-DONE.md) — repository completion standard.
- [`../production/RBXL-IMPORT-MIGRATION.md`](../production/RBXL-IMPORT-MIGRATION.md) — Studio-place reconciliation procedure.
- [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) — PR evidence/rollback checklist.

## Precedence

```text
accepted runtime evidence / current Roblox platform behavior
→ Blueprint v2.7 + Production Core v2.7 for active runtime execution
→ Current Product Authority + Master Roadmap v2.8
→ Active Place Rollout + Cross-System Traceability + production controls
→ accepted current specifications / architecture decisions
→ specialist visual/environment/Studio guidance
→ historical charters and roadmap checkpoints
```

A manual/runtime gate remains deferred—not passed—until reproducible evidence is recorded.

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

Roadmap/documentation adoption does not promote evidence level.

## Historical checkpoints

These remain useful provenance, not current execution authority:

- `BLUEPRINT-V2.3-EXECUTION.md`
- `PRODUCTION-CORE-V2.3.md`
- `CROSS-SYSTEM-TRACEABILITY-V2.3.md`
- `QUALITY-AUDIT-V2.3.md`
- `REFINEMENT-CHANGELOG-V2.3.md`
- `STUDIO-TRIAGE-CHECKLIST-V2.3.md`
- `BLUEPRINT-V2.0-EXECUTION.md`
- `BLUEPRINT-V1.9-EXECUTION.md`
- `P6-P12-EXECUTION-ROADMAP.md`
- `UNIFIED-MASTER-ROADMAP.md`
- `RECOMMENDED-PASSES.md`
- `SEQUENCING-EXCEPTION-P6-P7.md`
- `REPLAY-DECISION-STATUS.md`
- `LIVE-LOBBY-INTEGRATION-NOTE.md`

Historical P11/P12 requirements remain valuable inputs and are explicitly re-adopted where appropriate by Master Roadmap v2.8 rather than being treated as executable legacy tickets.

## Agent execution rule

1. Fetch current `main` and inspect related open PRs.
2. Read Current Product Authority + Master Roadmap v2.8 for destination/context.
3. For runtime work, obey v2.7 ticket/gate order.
4. For build-ahead work, use only READY tasks in `AGENT-BUILD-AHEAD-QUEUE.md`.
5. Do not implement a locked future phase merely because it now appears in the master roadmap.
6. Do not replace Studio/runtime evidence with source inference.

> Complete map, disciplined execution: know where the game is going, but build only the next dependency-safe slice.
