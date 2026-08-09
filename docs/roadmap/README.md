# Atlas Roadmap Index

**Playable MVP + Patch Execution v2.9 is the current implementation-sequencing authority as of 2026-08-08.**  
**Master Roadmap v2.8 remains the complete product-path and requirements inventory.**  
**Blueprint v2.7 remains the active runtime stabilization/rollout authority until its applicable gates close.**

This three-layer split is intentional:

- v2.7 protects the active runtime and decides what is technically safe to activate now;
- v2.9 decides which **playable player-facing slice** should be built next once work is dependency-safe;
- v2.8 preserves the complete destination so later requirements are not forgotten.

Read [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) before older product charters.

## Current roadmap stack

1. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — **current implementation-sequencing authority.** Establishes Gate 0, MVP 0.1, upgrade patches 0.2–0.9, the STOP / PLAY / FIX gate, release-candidate hardening, and post-1.0 patch discipline.
2. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — **v2.8 complete product path and requirements inventory.** Its phases remain valid, but later broad phases may not leapfrog the current playable patch.
3. [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md) — **active runtime stabilization/rollout authority** for Tickets 331–360 while those gates remain open.
4. [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md) — daily runtime-production rules/current critical path.
5. [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md) — staged current-state/presentation migration, observability, rollback, soak and closure.
6. [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md) — mechanical/replication/presentation/lifecycle ownership and evidence gates.
7. [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md) — dependency-safe preparation while runtime evidence is blocked. READY work should preferentially enable the **current playable patch**.
8. [`QUALITY-AUDIT-V2.7.md`](QUALITY-AUDIT-V2.7.md) — static quality/refinement history for the active rollout.
9. [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) — cross-cutting art/presentation sequence subordinate to gameplay/runtime gates, current playable-patch priority, and Studio review.

## Controlling development rhythm

```text
stabilize
→ MVP 0.1: first complete run
→ STOP / PLAY / FIX
→ 0.2 combat feel
→ STOP / PLAY / FIX
→ 0.3 loot + build replayability
→ STOP / PLAY / FIX
→ 0.4 RPG progression
→ STOP / PLAY / FIX
→ 0.5 Main World + environment expansion
→ STOP / PLAY / FIX
→ 0.6 procedural/systemic replayability
→ STOP / PLAY / FIX
→ 0.7 durable persistence hardening
→ STOP / PLAY / FIX
→ 0.8 co-op/social/session expansion
→ STOP / PLAY / FIX
→ 0.9 content expansion + production pipeline
→ release-candidate hardening
→ 1.0
→ measured live upgrade patches
```

At the end of every player-facing milestone, Atlas must still be playable end to end. A known blocker in the current loop prevents the next patch from becoming runtime-eligible.

## Playable patch precedence

When a long-range roadmap phase contains more work than is necessary for the current playable milestone, build the smallest coherent subset needed to satisfy the current patch exit gate.

Examples:

- MVP 0.1 needs a compact preparation/return surface, not the final giant Main World;
- MVP 0.1 may use minimal safe persistence, while full valuable-state hardening belongs primarily to Patch 0.7;
- basic co-op support may be required early, while broad party/matchmaking/social infrastructure belongs primarily to Patch 0.8;
- loot and progression should first be deep enough to evaluate replayability, not broad enough to satisfy an item-count target;
- content breadth belongs after the underlying combat/reward/progression/replayability systems have survived repeated playtests.

## MVP 0.1 — First Complete Run

The highest-priority player-facing milestone after the active stabilization gate is:

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

## STOP / PLAY / FIX gate

Every patch closes with:

1. **STOP** expansion when a known blocker breaks the current end-to-end loop.
2. **PLAY** the representative loop in Studio with the applicable evidence checklist.
3. **FIX** regressions, lifecycle failures, unreadable gameplay, broken transitions, reward/progression faults, or severe performance defects.
4. **REPLAY** the loop to prove it can repeat, including multiplayer/device variants when the current patch requires them.
5. **THEN EXPAND** into the next patch.

Static tests remain mandatory but do not substitute for Studio/runtime evidence.

## Master Roadmap v2.8 phase inventory

The complete long-range scope remains:

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

These requirements are **mapped into** the playable patch order; they are not deleted. The v2.9 sequencing document controls when broad implementation happens.

## Main World / environment policy

The Main World target loop remains:

```text
Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return
```

BA-010 and subsequent Main World specifications determine KEEP/REFINE/REBUILD/REPLACE/REMOVE/MISSING disposition, navigation/landmark/traversal policy, visual/environment/audio direction, expansion readiness, streaming/performance requirements, and Studio-only acceptance checks.

MVP 0.1 should use only the smallest coherent world surface required for the complete run. Broader environment production becomes a first-class focus in Patch 0.5 after the core loop is playable.

## Active production-control artifacts

- [`../production/V2.7-CUTOVER-LEDGER.md`](../production/V2.7-CUTOVER-LEDGER.md) — producer/consumer/presentation migration ledger.
- [`../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md`](../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md) — required structure for evidence-bearing Studio/runtime runs.
- [`../production/DEFINITION-OF-DONE.md`](../production/DEFINITION-OF-DONE.md) — repository completion standard.
- [`../production/RBXL-IMPORT-MIGRATION.md`](../production/RBXL-IMPORT-MIGRATION.md) — Studio-place reconciliation procedure.
- [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) — PR evidence/rollback checklist.

## Precedence

```text
accepted runtime evidence / current Roblox platform behavior
→ Blueprint v2.7 + Production Core v2.7 while active stabilization/rollout gates remain open
→ Playable MVP + Patch Execution v2.9 for implementation sequencing
→ Current Product Authority + Master Roadmap v2.8 for product direction and complete scope
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

Historical P11/P12 requirements remain valuable inputs and are re-adopted into the appropriate playable patch rather than treated as executable legacy tickets.

## Agent execution rule

When asked to continue the roadmap:

1. Fetch current `main` and inspect related open PRs.
2. Read Current Product Authority and `PLAYABLE-MVP-PATCH-EXECUTION.md`.
3. Check Blueprint v2.7 for any active stabilization dependency that blocks the current playable milestone.
4. If blocked, perform the next dependency-safe blocker or safe preparation that most directly enables the current playable milestone.
5. If unblocked, work only on the highest-ROI unfinished requirement for the **current playable patch**.
6. Do not begin later-patch breadth while a known current-patch blocker remains.
7. Preserve the previous playable baseline with regression coverage and required Studio evidence.
8. Report the current patch, evidence, blocker status, and next highest-ROI task.

> **Complete map, playable execution:** know the whole destination, but ship and prove one coherent layer at a time.