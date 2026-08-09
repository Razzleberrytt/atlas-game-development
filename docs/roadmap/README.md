# Atlas Roadmap Index

**Playable MVP + Patch Execution v2.9 is the current player-facing sequencing authority.**  
**Build-Through + Milestone Verification Policy is the current execution-cadence and roadmap-status authority.**  
**Master Roadmap v2.8 remains the complete product-path and requirements inventory.**  
**Blueprint v2.7 remains the active runtime stabilization/safety authority until its applicable gates close.**

The split is intentional:

- v2.7 protects real runtime, authority, data, lifecycle, and rollback safety;
- v2.9 identifies the most important playable milestone and recommended patch order;
- the Build-Through policy determines how agents may keep implementing and how work is labeled before verification;
- v2.8 preserves the complete destination so later requirements are not forgotten.

Read [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) before older product charters.

## Current roadmap stack

1. [`MVP-BUILD-THROUGH-TESTING-POLICY.md`](MVP-BUILD-THROUGH-TESTING-POLICY.md) — **current execution-cadence and roadmap-status authority.** Retires general roadmap locks, separates built work from verified work, and uses coherent milestone playtests instead of repeated artificial stop gates.
2. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — **current player-facing sequencing authority.** Establishes Gate 0, MVP 0.1, upgrade patches 0.2–0.9, release-candidate hardening, and the preferred order for visible playable progress.
3. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — **v2.8 complete product path and requirements inventory.** Its phases remain useful for destination and dependency context; older `[L]` scheduling labels are interpreted through the Build-Through policy rather than as blanket implementation bans.
4. [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md) — **active runtime stabilization/safety authority** for Tickets 331–360 while those gates remain open.
5. [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md) — daily runtime-production rules/current critical path.
6. [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md) — staged current-state/presentation migration, observability, rollback, soak and closure.
7. [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md) — mechanical/replication/presentation/lifecycle ownership and evidence gates.
8. [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md) — useful prepared work and dependency context; READY status is a prioritization aid, not a permission boundary.
9. [`QUALITY-AUDIT-V2.7.md`](QUALITY-AUDIT-V2.7.md) — static quality/refinement history for the active rollout.
10. [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — cross-cutting art/presentation sequence subordinate to gameplay/runtime safety, playable priorities, and Studio review.

## Roadmap status language

Actively maintained roadmap work should use these meanings:

```text
NOT STARTED
BUILDING
BUILT — VERIFICATION PENDING
VERIFIED
DEFERRED
BLOCKED — concrete reason required
HISTORICAL
```

The important distinction is **BUILT — VERIFICATION PENDING** versus **VERIFIED**.

An implementation can exist, pass automated/static checks, and remain available for continued development before its final Studio/device/human evidence is complete. Agents should label that truthfully instead of pretending the work is either untouched or fully accepted.

General `[L]` / `LOCKED` phase labels in older roadmap text are retired as execution barriers. Unless a concrete safety/dependency reason is named, read them as **DEFERRED**.

## Controlling development rhythm

The default rhythm is:

```text
identify the current playable milestone
→ implement the highest-ROI useful increment
→ run automated/static checks
→ mark BUILT — VERIFICATION PENDING when appropriate
→ keep implementing through the coherent layer
→ run a milestone Studio/playtest pass
→ fix integration/gameplay defects
→ replay until verified
→ continue building
```

The recommended player-facing progression remains:

```text
stabilize the unsafe/broken runtime boundaries that genuinely matter
→ MVP 0.1: first complete run
→ 0.2 combat feel
→ 0.3 loot + build replayability
→ 0.4 RPG progression
→ 0.5 Main World + environment expansion
→ 0.6 procedural/systemic replayability
→ 0.7 durable persistence hardening
→ 0.8 co-op/social/session expansion
→ 0.9 content expansion + production pipeline
→ release-candidate hardening
→ 1.0
→ measured live upgrade patches
```

This order is a prioritization map, not a blanket prohibition on useful later-phase implementation. Later work may be built early when it directly helps the current milestone, removes a real dependency, creates a needed canonical interface, or is an isolated high-value improvement.

## Milestone verification rule

At a coherent player-facing milestone:

1. stop broad expansion long enough to evaluate the integrated result;
2. play the representative loop in Studio with the applicable evidence checklist;
3. fix regressions, lifecycle failures, unreadable gameplay, broken transitions, reward/progression faults, or severe performance defects;
4. replay the loop to prove it can repeat, including multiplayer/device variants when the milestone requires them;
5. mark the milestone **VERIFIED** only when its required evidence passes.

Static and automated tests remain mandatory, but they do not substitute for Studio/runtime evidence where the claim itself depends on engine behavior or gameplay feel.

A tiny ticket, intermediate version, or ordinary implementation increment does **not** automatically require a human playtest before development may continue.

## Playable milestone priority

When a long-range roadmap phase contains more work than is necessary for the current playable milestone, prefer the smallest coherent subset with the highest return.

Examples:

- MVP 0.1 needs a compact preparation/return surface, not the final giant Main World;
- MVP 0.1 may use minimal safe persistence, while deeper valuable-state hardening can follow as the loop grows;
- basic co-op support may be required early, while broad party/matchmaking/social infrastructure can remain deferred until it produces near-term value;
- loot and progression should first be deep enough to evaluate replayability, not broad enough to satisfy an item-count target;
- content breadth should expand when the underlying combat/reward/progression/replayability systems can actually benefit from it.

## MVP 0.1 — First Complete Run

The highest-priority player-facing milestone is:

```text
spawn / arrive
→ prepare
→ choose a weapon/build
→ enter one expedition
→ explore
→ fight
→ receive loot/reward decisions
→ defeat an elite
→ defeat one boss / terminal encounter
→ return
→ equip or apply an upgrade
→ voluntarily start another run
```

Target first-run duration is roughly **5–10 minutes**, subject to play evidence.

The primary product signal is not feature count. It is whether a tester can complete the loop without developer intervention and wants to start another run.

## Master Roadmap v2.8 phase inventory

The complete long-range scope remains:

```text
A0    product authority reconciliation
R     active runtime rollout / incident closure
B     build-ahead preparation
W     Main World + environment
S     party / social / matchmaking-session infrastructure
E     evidence promotion E2–E7
D     durable persistence / valuable state
M     long-term progression
ECON  economy / crafting / resource value
C     content production pipeline
V     first complete vertical slice
Q     quality / balance / device / performance / accessibility
F     outside-player fun + repeat-intent evaluation
T     production telemetry / E7
OPS   runtime configuration / staged rollout / rollback
SAFE  platform safety / security / compliance
LOC   localization readiness
MON   ethical monetization — deferred until fun/repeat-intent evidence makes it worth evaluating
L     alpha → beta → soft launch → production launch
LIVE  post-launch operations and expansion
```

These requirements are mapped into the playable development path; they are not deleted. Their old phase ordering should guide prioritization and dependency reasoning, while the Build-Through policy controls whether implementation may proceed.

## Main World / environment policy

The Main World target loop remains:

```text
Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return
```

BA-010 and subsequent Main World specifications determine KEEP/REFINE/REBUILD/REPLACE/REMOVE/MISSING disposition, navigation/landmark/traversal policy, visual/environment/audio direction, expansion readiness, streaming/performance requirements, and Studio-only acceptance checks.

MVP 0.1 should use the smallest coherent world surface required for the complete run. Broader environment work becomes increasingly valuable once the core loop is playable, but it may be implemented earlier when it directly improves or enables that loop.

## What can still genuinely block work

The removal of general roadmap locks does not remove real safety boundaries.

A task may be **BLOCKED** when a concrete reason exists, such as:

- it would violate server authority or an important security boundary;
- it risks irreversible player-data corruption or an unsafe migration;
- a required canonical owner/interface is broken or undefined;
- it would destroy a known-good rollback point;
- later work would necessarily build on a known incorrect runtime assumption;
- required engine/runtime evidence cannot reasonably be deferred because downstream work depends on the result being correct.

These are engineering blockers. Merely belonging to a later roadmap phase is not one.

## Active production-control artifacts

- [`../production/V2.7-CUTOVER-LEDGER.md`](../production/V2.7-CUTOVER-LEDGER.md) — producer/consumer/presentation migration ledger.
- [`../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md`](../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md) — structure for evidence-bearing Studio/runtime runs.
- [`../production/DEFINITION-OF-DONE.md`](../production/DEFINITION-OF-DONE.md) — repository completion standard.
- [`../production/RBXL-IMPORT-MIGRATION.md`](../production/RBXL-IMPORT-MIGRATION.md) — Studio-place reconciliation procedure.
- [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) — PR evidence/rollback checklist.

## Precedence

```text
accepted runtime evidence / current Roblox platform behavior
→ Blueprint v2.7 + Production Core v2.7 for genuine active runtime safety requirements
→ Build-Through + Milestone Verification Policy for execution cadence and status meaning
→ Playable MVP + Patch Execution v2.9 for recommended player-facing sequence
→ Current Product Authority + Master Roadmap v2.8 for product direction and complete scope
→ Active Place Rollout + Cross-System Traceability + production controls
→ accepted current specifications / architecture decisions
→ specialist visual/environment/Studio guidance
→ historical charters and roadmap checkpoints
```

A manual/runtime gate remains pending—not passed—until reproducible evidence is recorded. Pending verification does not automatically prohibit further dependency-safe implementation.

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

Historical P11/P12 requirements remain valuable inputs and can be re-adopted into current work rather than treated as executable legacy tickets.

## Agent execution rule

When asked to continue the roadmap:

1. fetch current `main` and inspect overlapping open work;
2. read Current Product Authority, the Build-Through policy, and `PLAYABLE-MVP-PATCH-EXECUTION.md`;
3. preserve genuine Blueprint v2.7 safety, server-authority, data-safety, canonical-ownership, and rollback requirements;
4. identify the current playable milestone and its highest-value missing capability;
5. choose the highest-ROI dependency-safe task that advances the milestone or removes a real dependency;
6. later-phase implementation is allowed when it directly helps, but avoid broad speculative expansion with no near-term payoff;
7. run applicable automated/static validation after each implementation increment;
8. mark completed implementation **BUILT — VERIFICATION PENDING** when Studio/device/human evidence remains;
9. continue implementing unless a concrete **BLOCKED** condition exists;
10. at a coherent milestone boundary, run the consolidated playtest/debug/replay pass and mark **VERIFIED** only after evidence passes;
11. report the current milestone, implementation status, verification status, concrete blockers if any, and the next highest-ROI task.

> **Complete map, forward motion:** know the destination, keep building, and verify coherent milestones instead of fighting the roadmap.