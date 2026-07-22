# Living Kingdoms — P6–P12 Execution Roadmap

## Purpose and authority

This document is the executable continuation of `MASTER-ROADMAP.md` for the remaining MVP milestones. The master roadmap remains the milestone-level history; this file owns the ordered PR-sized tasks, dependencies, acceptance gates, and honest current status for P6 through P12.

No task is complete merely because code exists. The repository Definition of Done still applies: focused scope, server authority, automated checks where feasible, written manual verification, accurate roadmap status, and one coherent pull request.

Status markers follow the master-roadmap legend: `[ ]` not started, `[~]` in progress or deferred mid-task, `[x]` complete, `[!]` blocked on an unmet gate.

## Standard process for every task

Every task below follows the same completion process unless its acceptance criteria explicitly narrow it.

1. **Confirm prerequisites.** Verify every dependency is merged and the preceding milestone gate is satisfied.
2. **Lock scope.** State the one testable result, exclusions, trust boundary, and any manual-only requirement before implementation.
3. **Inspect existing owners.** Reuse current services, contracts, remotes, configuration, and lifecycle boundaries; do not create a parallel authority path.
4. **Define contracts first.** Add or revise stable IDs, strict types, configuration, rejection reasons, and copied snapshot shapes before runtime mutation.
5. **Implement pure decisions.** Put deterministic validation, eligibility, transitions, scaling, and reward calculations in side-effect-free resolvers where practical.
6. **Integrate one runtime owner.** Consequential state stays server-owned, revisioned or generation-checked where applicable, bounded, and explicitly cleaned up.
7. **Add presentation last.** Clients may request player-directed actions and present immediate feedback, but may not establish legal targets, resources, health, class effects, objectives, enemies, results, XP, or unlocks.
8. **Prove abuse resistance.** Add fixtures and source/runtime audits for malformed payloads, replay, stale state, cross-player control, rate abuse, disconnects, and teardown.
9. **Run the full gate.** StyLua, Selene, every Living Kingdoms Lune fixture, and Rojo build must pass. Required Studio checks must be recorded honestly.
10. **Close the loop.** Update specifications, roadmap status, limitations, validation evidence, and the next unblocked task before merge.

## Cross-milestone dependency chain

`P6 evidence and tuning sign-off` → `P7 classes` → `P8 authored objectives` → `P9 special enemy and boss` → `P10 complete match/result loop` → `P11 persistence and unlocks` → `P12 balance, performance, accessibility, and release-candidate validation`.

Planning for the next milestone may be completed while a manual validation gate is pending, but later gameplay implementation does not begin until the preceding milestone exits.

---

## P6 — Ammunition scarcity and supply collection

### Milestone objective

Replace prototype ammunition with finite server-owned resources, authored risky supply opportunities, readable personal feedback, and enough evidence to distinguish useful tension from unavoidable starvation.

### Tasks

- [x] **P6-0101 — Define ammunition scarcity contracts and configuration.**
  - Stable supply, collection, ammunition, and rejection vocabulary.
  - Initial magazine, reserve, reserve-cap, and authored-cache values live in shared configuration.
  - Pure declarations and fixtures only; no runtime collection.
- [x] **P6-0102 — Replace temporary production ammunition with finite configured state.**
  - Production automatic combat initializes from the canonical finite values.
  - Fire, reload, revive preservation, restriction, and respawn paths cannot refill or forge ammunition.
- [x] **P6-0103 — Author risky ammunition-cache locations.**
  - Cache identity, weapon compatibility, grant size, and world position are deterministic and configuration-driven.
  - Locations create route decisions without hidden random supply.
- [x] **P6-0104 — Implement server-owned cache collection.**
  - The server derives cache identity, distance, life eligibility, capacity, duplicate history, grant, and commit.
  - One cache may be collected once per operative; squadmates retain independent access.
- [x] **P6-0105 — Add authoritative ammunition HUD feedback.**
  - Personal loaded/reserve state and collection grants are clearly presented without giving the client ammunition authority.
- [x] **P6-0106 — Add per-operative cache depletion feedback.**
  - A consumed cache becomes locally depleted and stops offering a useless prompt only for that operative.
  - Server-owned per-player collection history remains authoritative.
- [x] **P6-0107 — Add sampled scarcity telemetry and a Studio validation probe.**
  - Accepted shots derive from conserved server truth: starting ammunition plus committed grants minus current ammunition.
  - Snapshots report grants, cache use, minimum ammunition, true dry transitions, remaining opportunities, active roster, and observed participants.
  - Sampling is explicit, read-only, Studio-only, and scheduler-free.
- [x] **P6-0108 — Run the controlled 1/2/4-operative evidence matrix.**
  - Reset sampling before each comparable run.
  - Capture snapshots at operation start, first objective completion, mid-operation escalation, holdout start, and terminal success/failure.
  - Record operative count, duration, accepted shots, exact grants, consumed/remaining caches, minimum ammunition, true dry transitions, deaths, and outcome.
  - Use the same route and objective order where possible; record deviations rather than hiding them.
  - **Prototype sign-off:** the project owner completed the requested local multiplayer tests and reported that they ran fine. Raw telemetry rows were not retained, so the result is qualitative and that limitation remains assigned to P12 rather than being silently reconstructed.
- [x] **P6-0109 — Tune scarcity from evidence and sign off P6.**
  - Change only configuration values supported by the P6-0108 evidence.
  - Prefer the smallest adjustment among starting reserve, cache grants, cache placement, or reserve cap.
  - Re-run the affected 1/2/4 scenarios after tuning.
  - Reject a tune that produces repeated unavoidable dry states despite near-complete cache collection, or that leaves most ammunition and caches unused with no meaningful route decision.
  - Lock the final P6 values, limitations, and Studio evidence in the specification and smoke-test record.
  - No tuning change was justified by the accepted qualitative pass; the existing configuration remains locked for the prototype and is subject to P12's measured balance pass.

### P6 execution order

`P6-0101` → `P6-0102` → `P6-0103` → `P6-0104` → `P6-0105` → `P6-0106` → `P6-0107` → `P6-0108` → `P6-0109`.

### P6 exit criteria

One to four operatives use finite server-owned ammunition and independently consume authored risky caches with clear personal feedback. Comparable Studio evidence shows that careful play creates pressure and recovery decisions without predetermined starvation. P6 values are tuned from measurements rather than intuition.

### Current P6 status

P6 is **complete for the current prototype**. The project owner accepted the local 1/2/4-player behavior after reporting that the requested tests ran fine, and no scarcity tune was made without retained measurements. Raw routed telemetry and repeated balance classification remain an explicit P12 validation limitation, not invented evidence.

---

## P7 — Three interdependent MVP classes

### Milestone objective

Make combat specialist, medic, and engineer responsibilities frequent, legible, limited, and mutually valuable without making any missing class an automatic loss. Class selection and every consequential class action remain server-owned.

Canonical specification: `docs/specifications/mvp-specialist-classes.md`.

### Tasks

- [x] **P7-PLAN-001 — Specify and decompose the three starting classes.**
  - Lock role philosophy, duplicate-class policy, solo policy, selection timing, class-lock timing, shared action lifecycle, trust boundaries, resource ownership, interaction expectations, observability, accessibility, performance budgets, ordered implementation tasks, and explicit deferrals.
  - No P7 gameplay source changes.
- [x] **P7-0101 — Define shared class contracts and configuration.**
  - Stable class IDs, action IDs, action states, target kinds, rejection reasons, selection records, resource records, cooldown/channel descriptors, and safe presentation snapshots.
  - All starting classes are unlocked by default; the P11 unlockable class remains absent.
  - Class values live in shared configuration; fixtures verify frozen vocabulary and invariants.
  - No runtime owner, remote, UI, ability effect, healing, ammunition grant, or objective repair.
  - Complete through PR #71 under the bounded `SEQUENCING-EXCEPTION-P6-P7.md` (declarations and invariant fixtures only).
- [x] **P7-0102 — Implement server-owned class selection and assignment.**
  - Players may select an unlocked starting class during briefing only; insertion locks the selection for the run.
  - Duplicate classes are allowed, roster storage is keyed by operative identity rather than fixed slots, and late/stale/cross-player requests fail closed.
  - One small request/state network exposes only validated selection and safe roster snapshots.
  - Disconnect, reconnect policy, operation restart, and teardown are deterministic.
  - Complete through PR #72 under the bounded sequencing exception; no consequential class effect exists yet.
- [x] **P7-0103 — Add the combat specialist vertical slice.**
  - Implement one frequent position-stabilizing combat action from the canonical spec.
  - The action cannot create ammunition, bypass target visibility, hit validation, cadence authority, life restrictions, or operation state.
  - Cost, cooldown, channel/stance interruption, and effect bounds are server-validated and configuration-driven.
	- Presentation makes activation, active duration, interruption, and cooldown legible without revealing hidden enemies.
	- Complete in source with server-owned Brace activation/replay/lifecycle, six-second stance, movement/life/reload/mission interruption, fourteen-second cooldown, bounded cadence composition through the production combat owner, and compact keyboard/gamepad/touch feedback. All 135 Lune fixtures pass.
- [x] **P7-0104 — Add the medic vertical slice.**
  - Implement finite field treatment for an alive injured teammate and the approved bounded revive benefit.
  - The medic cannot self-revive, revive Dead operatives, fabricate health, ignore range/line of sight, erase repeated mistakes, or bypass the existing P3 commit/revision boundary.
  - Healing resources are personal, finite, server-owned, preserved or reset only according to the operation lifecycle, and visibly disclosed to the owner.
- [x] **P7-0105 — Add the engineer vertical slice.**
  - Implement finite nearby field resupply using a configured operation-issued resource budget.
  - Grants commit through the existing ammunition authority boundary, obey weapon compatibility and reserve caps, and never create unlimited or recyclable ammunition.
  - Objective-equipment repair remains P8 integration; P7 may define the interface but may not scaffold an unused objective runtime.
- [x] **P7-0106 — Integrate cross-class interactions and squad presentation.**
  - Add readable class identity, personal resource/cooldown state, teammate action cues, and concise failure reasons.
  - Prove the intended loop: combat specialist creates safe action windows, medic preserves operative viability, and engineer extends ammunition resilience.
  - UI supports text/shape distinctions and does not depend on color or audio alone.
- [x] **P7-0107 — Complete class security, scaling, and multiplayer validation.**
  - Fixtures and adversarial tests cover forged class selection, locked swaps, action replay, stale timestamps/revisions, acting for another operative, invalid targets, resource duplication, cooldown bypass, disconnects, and teardown.
  - Studio sessions cover solo, duplicate-class squads, and balanced 2/3/4-operative squads.
  - Record contribution frequency, idle time during channels, resource use, absence-of-role viability, and whether the balanced squad has materially better options without becoming mandatory.

### P7 execution order

`P7-PLAN-001` → `P7-0101` → `P7-0102` → (`P7-0103` + `P7-0104` + `P7-0105`, one PR at a time) → `P7-0106` → `P7-0107`.

`P7-0101` through `P7-0107` are complete. Brace established shared action-state disclosure, Medic proved finite health/revive integration, Engineer proved capped ammunition-owner/telemetry integration, the composed safe snapshot drives accessible owner and teammate presentation, and the final slice added adversarial/scaling fixtures plus a bounded Studio-only validation ledger.

### P7 exit criteria

Players choose and retain a server-owned starting class for the run. Each class contributes frequently, has a meaningful limitation and finite resource/cooldown, interacts with another role, and remains secure under multiplayer abuse. Any class composition can attempt the operation, while a balanced squad has more resilient options.

### Current P7 status

P7 is **complete** (`P7-PLAN-001` through `P7-0107`). P8 is implemented through `P8-0107` (see [`../specifications/authored-objective-chain.md`](../specifications/authored-objective-chain.md)); `P8-0108` automated coverage is complete and only its live Studio playtest remains. `P9-PLAN-001` through `P9-0105` are **complete** (see [`../specifications/special-enemy-and-boss-encounter.md`](../specifications/special-enemy-and-boss-encounter.md); the Blight Spitter and The Progenitor boss are live `EnemyDirectorService` archetypes with readable client telegraphs); the next unblocked gameplay task is `P9-0106` (encounter security, performance, and class-composition validation), which closes P9.

---

## P8 — Authored operation objectives

### Milestone objective

Expand Operation Blackwater Relay from its current single relay interaction into a complete two-or-three-objective route that forces relocation, creates temporary defensive value, and communicates objective truth clearly.

### Tasks

- [x] **P8-PLAN-001 — Specify the authored objective chain.**
  - Choose the exact two-or-three objectives, authored locations, order/branching policy, interaction requirements, class opportunities, failure conditions, escalation effects, defensive-position value, and relocation pressure.
  - Map every objective to existing landmarks and server-owned mission phases.
  - **Complete** — [`../specifications/authored-objective-chain.md`](../specifications/authored-objective-chain.md) fixes two required objectives (relay restore at `LookoutTower`, decaying signal-booster hold at `MilitaryRoadblock`) and one optional engineer floodlight repair at `ExtractionClearing`, all inside the existing `Infiltration` phase and the single terminal boundary, with the three existing escalation waves re-homed to the chain.
- [x] **P8-0101 — Define objective contracts and authored configuration.**
  - `ObjectiveContracts.luau` fixes the objective/interaction/state/rejection vocabulary and validates definitions and safe objective snapshots.
  - `ObjectiveChainConfig.luau` is the versioned three-objective chain: locations on existing landmarks, prerequisites, interaction kinds, timings, active phases, wave triggers, and disclosure text.
  - `ObjectiveChainResolver.test.luau` covers dependency and configuration invariants purely.
- [x] **P8-0102 — Implement the generic server-owned objective runtime.**
  - `ObjectiveChainResolver.luau` is one pure owner validating phase, revision, prerequisite, bounded delta, and presence before committing any progress; `MissionDirectorService` samples operative presence and applies it.
  - No client declares progress, completion, failure, timestamp, location, class effect, or escalation — progression is presence-driven with no client objective remote.
- [x] **P8-0103 — Replace the placeholder relay interaction with objective one.**
  - The relay is a presence-driven held channel delivered through the generic runtime.
  - Escalation and safe client snapshots route through the existing mission authority — no parallel state machine.
- [x] **P8-0104 — Add objective two and the optional third objective.**
  - The decaying booster charge (required) and the optional engineer floodlight repair each teach a distinct behavior.
  - Completion order and dependencies are deterministic; a locked prerequisite cannot advance the operation.
- [x] **P8-0105 — Add relocation pressure and temporary defensive-position value.**
  - The booster is a decaying accumulated-presence hold that forces a cross-map relocation from the Lookout to the Roadblock and is bounded by the roadblock swarm on completion.
  - No permanent base building, barricade economy, crafting, or open-ended defense mode.
- [x] **P8-0106 — Integrate class opportunities without class gates.**
  - The engineer restores the floodlights fast through the approved objective-equipment repair; any operative can complete the slower manual bypass.
  - Missing a class changes efficiency but never makes a required objective impossible (required objectives ignore class entirely).
- [x] **P8-0107 — Add objective and route presentation.**
  - The safe snapshot carries the objective chain (current objective, progress, decaying state, optional flag, next destination); `MissionController` surfaces it.
  - Presentation discloses no hidden threats or distant supply truth (P4 limits).
- [~] **P8-0108 — Complete objective-chain security and 1/2/4-player validation.**
  - Automated coverage complete: `P8ObjectiveChainSecurityValidation.test.luau` (no-remote authority, wrong phase, stale revision, invalid delta, prerequisite skip, class-gate, distance, bounds, optional-gate) plus `MissionDirectorService.test.luau` (disconnect mid-channel, squad wipe, teardown, and a scripted 1/2/4-operative full-chain success run). Replay/remote spam is structurally impossible (no client objective remote).
  - **Pending:** the live Studio run proving the full chain, forced relocation, temporary defense, readable recovery windows, and bounded runtime work — a manual gate, like the P6 qualitative sign-off.

### P8 execution order

`P8-PLAN-001` → `P8-0101` → `P8-0102` → `P8-0103` → `P8-0104` → (`P8-0105` + `P8-0106`) → `P8-0107` → `P8-0108`.

### P8 exit criteria

The squad completes a readable two-or-three-objective authored route that uses existing landmarks, forces movement, rewards temporary defense and class cooperation, and remains fully server-authoritative from interaction through escalation and failure.

---

## P9 — Special enemy and boss encounter

### Milestone objective

Add one special enemy that disrupts a reliable tactic and one readable authored boss climax that tests lessons already taught by movement, visibility, classes, objectives, scarcity, rescue, and relocation.

### Tasks

- [x] **P9-PLAN-001 — Specify the special enemy and boss encounter.**
  - Lock the reliable tactic being disrupted, counterplay, telegraphs, boss phases, arena/location, objective connection, class contributions, failure readability, accessibility, spawn policy, and performance budgets.
  - **Complete** — [`../specifications/special-enemy-and-boss-encounter.md`](../specifications/special-enemy-and-boss-encounter.md) fixes the disrupted **turtle-and-autofire** tactic, the **Blight Spitter** special enemy (a telegraphed, interruptible Corrosive Bloom area-denial ability on the densest cluster that forces the squad to spread and relocate), and **The Progenitor** three-phase extraction-holdout boss (Carapace vulnerability windows → Brood summons under scarcity → Collapse enrage whose readability pays off the P8 floodlight repair). Both reuse the existing `EnemyDirectorService` owner and the single terminal boundary; the plan maps every decision to `P9-0101`–`P9-0106` and keeps the HROI horde-role and RPG elite-affix systems untouched.
- [x] **P9-0101 — Define special-enemy contracts, configuration, and pure decisions.**
  - Stable archetype/action/state/rejection IDs and all tuning values.
  - Pure resolver covers target choice, legal ability use, cooldowns, interruption, death inertness, and deterministic tie-breaks.
  - **Complete** — `src/shared/Combat/SpecialEnemyContracts.luau` fixes the Blight Spitter archetype ID, behavior-state and ability-action vocabulary, rejection reasons, and the fact/decision/lingering-zone shapes (reusing the P3-compatible `AuthoritativeEnemyAttack`). `src/shared/Config/SpecialEnemyConfig.luau` holds the bounded balance values (health, ranged engagement, Corrosive Bloom windup/radius/damage/cooldown, cluster radius, the lingering pool, active-zone cap, and authored rarity) with cross-config invariants against `EnemyConfig`. `src/server/Systems/SpecialEnemyBehaviorResolver.luau` is the pure, deterministic resolver: densest-cluster targeting with lexical tie-breaks, the `Begin → Continue → Commit` charge lifecycle, the commit burst against every Alive operative in radius, death/stand-down inertness, and a companion `resolveLingeringDamage` for the pool ticks. Fixtures `tests/SpecialEnemyContracts.test.luau` and `tests/SpecialEnemyBehaviorResolver.test.luau` cover vocabulary/invariants and the full decision surface. No runtime integration yet (that is `P9-0102`).
- [x] **P9-0102 — Integrate the special enemy into the production director.**
  - Reuse the existing enemy identity, health, spawning, damage, cleanup, stand-down, and bounded evaluation owner.
  - No per-enemy scheduler or client authority; special actions use bounded server-owned work.
  - **Complete** — `EnemyDirectorService` now owns the Blight Spitter as a real archetype through its existing boundaries: archetype-aware spawning (own health, no elite affix), the pure `SpecialEnemyBehaviorResolver` driving movement and the Corrosive Bloom charge lifecycle, the commit burst and lingering-pool ticks committed through the P3 damage boundary (with the same Iron Hide mitigation as walker melee), authored rarity introduced on the roaming pass at the configured escalation level and bounded by `MaximumConcurrent`, and full death/cleanup/stand-down/teardown integration (lingering pools cleared on stand-down). The bloom telegraph is disclosed via replicated model attributes (`EnemyPresentationContracts`), leaving the readable client presentation to `P9-0105`. Still one heartbeat, one evaluation pass, zero per-enemy connections/timers/raycasts/remotes/randomness. Fixtures: the Blight Spitter section in `EnemyDirectorService.test.luau` plus the wiring in `P5IntegrationValidation.test.luau`.
- [x] **P9-0103 — Define boss contracts, configuration, and phase resolver.**
  - Stable phase, transition, vulnerability, attack, summon, objective, success, and failure vocabulary.
  - Pure phase transitions use server-owned health/objective/time facts and deterministic precedence.
  - **Complete** — `src/shared/Combat/BossContracts.luau` fixes The Progenitor's `boss.progenitor` archetype (sourced from the shared registry), the monotonic `Carapace → Brood → Collapse → Defeated` phases and their fixed order, the Slam action lifecycle, the `Pending`/`Defeated` outcome, rejection reasons, and the fact/decision shapes. `src/shared/Config/BossConfig.luau` holds the balance (health, ordered phase thresholds, per-phase Slam windup/cooldown/exposure with enrage tightening, Slam radius/damage, the Brood surge count within the population budget, and the shroud/Collapse-darkness visibility reductions) with invariants against `EnemyConfig`. `src/server/Systems/BossPhaseResolver.luau` is the pure resolver: monotonic health-driven phase transitions with fixed precedence, the post-Slam exposure window that alone makes the boss vulnerable, the `Begin → Continue → Commit` Slam with an in-radius AoE against Alive operatives, the one-shot Brood summon, the shroud/darkness override (the P8 floodlight repair pays off in Collapse), and terminal defeat. Fixtures `tests/BossContracts.test.luau` and `tests/BossPhaseResolver.test.luau` cover the vocabulary/invariants and the full decision surface. No runtime, arena, telegraph, or summon integration yet (that is `P9-0104`+).
- [x] **P9-0104 — Implement the boss runtime and authored arena integration.**
  - One boss instance is owned through the production enemy/operation boundaries.
  - Phase transitions, attacks, adds, vulnerability windows, and terminal state are revision-safe, bounded, and cleaned up.
  - **Complete** — `EnemyDirectorService` owns the single Progenitor as an archetype through its existing boundaries: `spawnBoss` places one authored instance (larger footprint, own health, no elite affix); `applyBossBehavior` runs the pure `BossPhaseResolver` on the shared evaluation pass to advance the monotonic phase, open post-Slam exposure windows, commit the Slam AoE through the P3 boundary, summon the one-shot bounded Brood add surge (fair-spawn-validated walkers around the boss), and set the shroud/Collapse-darkness visibility override. Boss health commits are **rejected unless the boss is in an exposure window** (`commitHealthState` vulnerability gate), so operative fire only lands during telegraphed windows. `readGameplayVisibilityRadiusStuds` exposes the shroud so `OperativeCombatRuntimeService` shrinks targeting visibility, not just presentation. `readBossState` exposes the defeat outcome; `MissionDirectorService.beginHoldout` spawns the boss at the extraction clearing with the P8 floodlight fact. Death/cleanup/stand-down/teardown are handled (defeat frees the slot, stand-down freezes the boss, teardown clears boss state). Still one heartbeat, one evaluation pass, zero per-enemy connections/timers/raycasts/remotes and no randomness. The boss-defeat → terminal-result convergence is deferred to `P10-0102` (which owns "boss outcome"); the readable Slam/phase telegraphs are `P9-0105`. Fixtures: the boss section in `EnemyDirectorService.test.luau`, the shroud wiring in `OperativeCombatRuntimeService.test.luau`, and the holdout boss spawn in `MissionDirectorService.test.luau` and `P5IntegrationValidation.test.luau`.
- [x] **P9-0105 — Add readable telegraphs and accessible presentation.**
  - Every dangerous boss/special action has enough position, timing, shape, text, animation, or audio redundancy to support learning.
  - Presentation cannot reveal an undisclosed enemy early or legalize a client-predicted hit.
  - **Complete** — `src/shared/Config/SpecialEncounterTelegraphConfig.luau` maps the Blight Spitter Corrosive Bloom and the Progenitor Slam to the authoritative disclosure attributes and defines the boss phase/armored-vs-exposed status vocabulary. The client-only `src/client/Controllers/SpecialEncounterTelegraphController.luau` (one `RenderStepped`, one `ChildAdded`/`ChildRemoved` pair on `EnemyEntities`, a fixed disc pool, one boss status label) renders each dangerous action with redundant cues — world-space ground disc at the **server-disclosed** landing centre, a numeric countdown, text, shape, and animation (never color alone) — plus the bloom's lingering toxic-ground footprint and an always-visible boss `CARAPACE/BROOD/COLLAPSE` + `EXPOSED/ARMORED` indicator so players learn when their fire lands. Telegraphs appear only after the server commits to the action (no early disclosure), and the controller reads no health, sends no remote, predicts no consequence, and follows only the replicated root (no client-legalized hits). Fixtures: `tests/SpecialEncounterTelegraphConfig.test.luau` and the `tests/SpecialEncounterTelegraphSourceAudit.test.luau` bounded-and-cosmetic audit. The Studio mix/readability review (audio, contrast, overlapping telegraphs) remains a manual gate, like other presentation slices.
- [ ] **P9-0106 — Complete encounter security, performance, and class-composition validation.**
  - Test forged phase/health/target/action facts, stale transitions, disconnects, wipe, stand-down, replay, and cleanup.
  - Profile representative horde plus special plus boss load for 1/2/4 operatives.
  - Studio runs verify counterplay is attributable and no unexplained ammo/recovery requirement invalidates prior choices.

### P9 execution order

`P9-PLAN-001` → `P9-0101` → `P9-0102` → `P9-0103` → `P9-0104` → `P9-0105` → `P9-0106`.

### P9 exit criteria

The special enemy clearly disrupts one dominant tactic with learnable counterplay. The boss provides a readable coordinated climax, accepts contributions from all starting classes, respects prior resource decisions, and runs within bounded server performance.

---

## P10 — Match completion, failure, extraction, and replay

### Milestone objective

Turn the existing mission terminal state into a complete player-facing match loop: final extraction or holdout, authoritative success/failure, understandable results, deterministic cleanup, and a safe replay path.

### Tasks

- [ ] **P10-PLAN-001 — Specify terminal operation flow and result semantics.**
  - Lock success/failure causes, extraction/holdout rules, result facts, contribution facts needed later by P11, cleanup ownership, replay behavior, leave/disconnect/rejoin policy, and disclosure.
- [ ] **P10-0101 — Define match-result and extraction contracts/configuration.**
  - Stable result, cause, extraction, readiness, cleanup, and replay IDs.
  - Safe result snapshots contain only server-authored operation facts and no persistent XP yet.
- [ ] **P10-0102 — Implement one authoritative terminal-result resolver.**
  - Mission success, objective failure, squad failure, boss outcome, abandonment, and timeout converge on one first-commit-wins terminal boundary.
  - Duplicate or conflicting terminal events cannot produce multiple results.
- [ ] **P10-0103 — Integrate the final extraction or holdout sequence.**
  - Presence, timing, boss/objective prerequisites, pressure, and completion are server-read and revision-safe.
  - Late entry, early departure, incapacitation, death, and disconnect behavior are explicit.
- [ ] **P10-0104 — Add result presentation.**
  - Success/failure screen explains the cause, key operation events, personal/squad contribution facts, and next action.
  - No XP/rank/unlock promise is displayed until P11 commits it.
- [ ] **P10-0105 — Implement deterministic match cleanup and replay.**
  - Stop mission, enemy, objective, class-action, cache, life, movement restriction, presentation, and validation-probe state in a documented order.
  - Replay creates a fresh operation identity and no stale timers, connections, revisions, cache history, class resources, enemies, or result state.
- [ ] **P10-0106 — Complete leave, disconnect, rejoin, and shutdown handling.**
  - Define what is retained only within the active server session, when a reconnect may resume, and when a slot becomes permanently abandoned.
  - No disconnect can duplicate contribution, class resources, ammunition, life, objective credit, or terminal rewards.
- [ ] **P10-0107 — Validate the full non-persistent match loop.**
  - Automated tests cover every terminal cause, race, replay, and cleanup owner.
  - 1/2/4-operative Studio sessions complete success, squad failure, objective failure, abandonment, disconnect during extraction, and replay without developer intervention.

### P10 execution order

`P10-PLAN-001` → `P10-0101` → `P10-0102` → `P10-0103` → `P10-0104` → (`P10-0105` + `P10-0106`) → `P10-0107`.

### P10 exit criteria

A complete operation ends once in an understandable success or failure, cleans up every runtime owner, and can begin a fresh replay without stale state. The loop works for one to four operatives and safely handles leave/disconnect edge cases.

---

## P11 — Persistent XP, ranks, and one class unlock

### Milestone objective

Add reliable server-owned progression that rewards victory and meaningful participation, grants limited progress on failure, survives data-service problems safely, and unlocks one side-grade specialist without paid power or permanent combat inflation.

### Tasks

- [ ] **P11-PLAN-001 — Specify progression, persistence, and the unlockable class.**
  - Lock XP sources, contribution vocabulary, victory/failure weighting, anti-idle rules, rank ladder, unlock rank, unlockable-class identity, schema/versioning, retry/failure policy, observability, privacy, and migration policy.
- [ ] **P11-0101 — Define progression contracts and configuration.**
  - Stable profile version, rank, XP-event, contribution, award, unlock, load/save-state, and rejection IDs.
  - XP curves and caps are configuration-driven and fixture-tested.
- [ ] **P11-0102 — Implement a persistence adapter with versioning and failure recovery.**
  - Server-only DataStore access, session ownership, schema validation, migration, bounded retry/backoff, update-safe writes, and copied reads.
  - Moment-to-moment match correctness never depends on persistence availability.
- [ ] **P11-0103 — Implement pure contribution and XP award resolution.**
  - Consume only P10 terminal facts and server-recorded contribution events.
  - Prevent duplicate match awards, negative/invalid values, client-authored contribution, and failure farming.
- [ ] **P11-0104 — Integrate the military-style rank ladder.**
  - Apply committed XP once, derive rank deterministically, and disclose progress without granting material permanent stat power.
- [ ] **P11-0105 — Implement the unlockable side-grade specialist.**
  - Add one distinct capability approved by the P11 plan, unlocked at an attainable rank.
  - Reuse P7 class contracts/assignment/action boundaries and prove it is a side-grade rather than a stronger replacement.
- [ ] **P11-0106 — Add anti-idle and abuse safeguards.**
  - Bound repeated low-effort contributions, duplicate sessions, reconnect award replay, result spoofing, and save/load races.
  - Do not punish legitimate low-damage medic/engineer contribution.
- [ ] **P11-0107 — Add progression and persistence presentation.**
  - Show loaded/offline/error state, current XP/rank, earned XP breakdown, unlock progress, and newly unlocked class.
  - Never imply a save succeeded before the server confirms its persistence state.
- [ ] **P11-0108 — Complete persistence failure, migration, and multiplayer validation.**
  - Fixtures cover schema corruption, old versions, timeouts, throttling, duplicate awards, server shutdown, reconnect, and unavailable DataStore behavior.
  - Studio/test-environment runs verify success/failure awards, rank-up, unlock, reload, and safe degraded operation.

### P11 execution order

`P11-PLAN-001` → `P11-0101` → `P11-0102` → `P11-0103` → `P11-0104` → `P11-0105` → (`P11-0106` + `P11-0107`) → `P11-0108`.

### P11 exit criteria

Players earn server-owned, duplicate-safe XP from complete matches, advance through a small rank ladder, and unlock one side-grade class. Persistence is versioned, recoverable, observable, and unable to corrupt match authority or grant paid/material permanent power.

---

## P12 — Cooperative balance, performance, accessibility, and polish

### Milestone objective

Turn the complete feature loop into a difficult but learnable MVP release candidate. Tune from evidence, remove fixed-four-player assumptions, keep server work bounded, improve readability/accessibility, and prove the full operation repeatedly for one to four players.

### Tasks

- [ ] **P12-PLAN-001 — Define the release-candidate validation matrix and target experience.**
  - Lock target operation duration, success/failure bands, scarcity indicators, rescue frequency, class contribution goals, objective pacing, boss readability, performance budgets, supported controls/accessibility scope, and release-blocking severity rules.
- [ ] **P12-0101 — Consolidate end-to-end telemetry and baseline the current build.**
  - Produce comparable 1/2/3/4-operative reports for duration, objective timing, enemy load, shots, caches, dry transitions, damage, incapacitations, revives, class actions, boss phases, result causes, frame/server budgets, and cleanup residue.
  - Telemetry remains read-only and does not become a production analytics dependency unless separately approved.
- [ ] **P12-0102 — Tune solo-to-four-player pressure scaling.**
  - Adjust only configuration-backed population, cadence, damage, recovery, objective, and timing values supported by evidence.
  - Avoid fixed player slots and verify collection-based scaling remains compatible with a later maximum of eight.
- [ ] **P12-0103 — Tune class dependence and composition resilience.**
  - Balanced squads should have materially better options, while solo and duplicate-role squads retain a difficult but possible path.
  - Tune resources/cooldowns/contribution windows without adding new classes or power inflation.
- [ ] **P12-0104 — Tune scarcity, relocation, and operation pacing.**
  - Align ammunition, medical resources, objective timing, recovery windows, temporary defensive positions, special-enemy disruption, and final climax.
  - Remove dominant camping routes and predetermined starvation without flattening tension.
- [ ] **P12-0105 — Profile and optimize horde, special-enemy, boss, visibility, and UI load.**
  - Measure first, then make focused changes to evaluation cadence, raycast budgets, instance counts, replication, rendering, and cleanup.
  - No speculative framework rewrite or premature eight-player content expansion.
- [ ] **P12-0106 — Complete accessibility and readability pass.**
  - Ensure critical information uses redundant text/shape/position/timing cues, readable contrast, configurable volume where applicable, understandable controls, and non-audio-only warnings.
  - Review darkness, class cues, objective guidance, damage/rescue, scarcity, special attacks, boss phases, extraction, and results.
- [ ] **P12-0107 — Audit and remove fixed-four-player assumptions.**
  - Search contracts, arrays, spawn assignment, UI, class roster, objective participation, enemy scaling, result/contribution, persistence, and cleanup for fixed slots or hard-coded four-player indexing.
  - Add tests using more than four synthetic identities where runtime Studio limits or content are not yet expanded.
- [ ] **P12-0108 — Complete full security and regression audit.**
  - Re-run every client request abuse case across movement, combat, life, visibility, pings, caches, classes, objectives, enemies, boss, results, replay, and progression.
  - Prove no client can establish consequential state and no owner leaks timers, connections, instances, remotes, or stale revisions after replay/shutdown.
- [ ] **P12-0109 — Run release-candidate playthroughs and close MVP.**
  - Complete repeated one-, two-, three-, and four-operative runs across intended compositions and both success/failure outcomes.
  - Record known limitations, release blockers, performance evidence, accessibility findings, and final tuning values.
  - Update the charter/MVP/readmes/roadmap/smoke test to one synchronized release-candidate status.

### P12 execution order

`P12-PLAN-001` → `P12-0101` → (`P12-0102` + `P12-0103` + `P12-0104`, evidence-driven and one PR at a time) → `P12-0105` → `P12-0106` → `P12-0107` → `P12-0108` → `P12-0109`.

### P12 exit criteria

The complete MVP operation is difficult, readable, learnable, secure, bounded, replayable, persistent, and repeatedly completable for one to four operatives. Class, objective, scarcity, enemy, boss, result, and progression systems support the intended cooperative arc without fixed-four-player architecture, paid power, or unresolved release-blocking defects.

---

## Immediate next actions

1. Schedule the **P8-0108** live Studio playtest of the full objective chain (forced relocation and temporary defense). P8 is implemented and fixture-validated through `P8-0107`. **P9-PLAN-001** through **P9-0105** are complete (see [`../specifications/special-enemy-and-boss-encounter.md`](../specifications/special-enemy-and-boss-encounter.md); the Blight Spitter and The Progenitor boss are live `EnemyDirectorService` archetypes with readable client telegraphs); begin **P9-0106** (encounter security, performance, and class-composition validation), the final P9 task.
2. Preserve P6's qualitative-sign-off limitation for measured replay during P12 balance validation.
4. In parallel where evidence-independent: finish the **VIS-0102** firearm presentation integration per `VISUAL-PRODUCTION-TRACK.md`, and run the outstanding P5 pressure-loop Studio playthrough recorded in the smoke test.
