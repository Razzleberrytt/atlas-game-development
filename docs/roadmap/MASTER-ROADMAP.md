# Atlas — Master Roadmap v2.7

**Active authority:** Blueprint v2.7 Rollout & Observability  
**Date:** 2026-08-07  
**Current evidence claim:** E1 until accepted Studio evidence advances it

This document is the milestone-level view. Detailed execution order lives in [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md), and day-to-day rules live in [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md).

Older P0–P12 and blueprint roadmaps remain historical implementation records. They no longer authorize new work ahead of the active v2.7 gate.

## Status legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete with applicable evidence
- `[!]` Blocked by an earlier gate
- `[H]` Historical implementation record; not current execution authority

## Current program state

| Program area | Status | Current meaning |
|---|---|---|
| Repository/tooling foundation | [x] | GitHub-first source, Rojo/tooling/tests/CI exist; current CI result remains the controlling static evidence. |
| Core gameplay systems | [H] | Significant movement/combat/life/enemy/objective/run-build/result work exists in source. Existing behavior is preserved as an asset, not treated as proof of the new runtime gate. |
| v2.7 state/presentation rollout | [~] | **Active milestone.** Inventory legacy producers/consumers, add readiness/semantic suppression, centralize Highlight ownership, and prove cleanup. |
| E2 Studio initialization | [!] | Cannot be claimed from documentation alone. Requires captured Studio startup evidence. |
| E3 integrated solo behavior | [!] | Begins only after rollout blockers are closed enough to run a trustworthy integrated loop. |
| E4 multiplayer/adversarial | [!] | Requires two-player reset/disconnect/ownership/attribution evidence after E3 path is stable. |
| Durable persistence/value | [!] | Deliberately gated until runtime state, ownership, cleanup, and retry behavior are accepted. |
| Broader vertical-slice integration | [!] | Preparation/outdoor route/dungeon/boss integration resumes only after the current runtime gate is accepted. |
| Device/performance acceptance | [!] | Requires representative captures and reliability evidence, not source inference. |
| Outside-player fun/repeat intent | [!] | Requires a stable integrated build first. |
| Broad world/live-service expansion | [!] | Explicitly out of scope until the polished repeatable loop is proven. |

## North-star sequence

The target product remains one polished, replayable cooperative expedition:

```text
prepare
→ choose a build/weapon
→ readable authored route
→ mixed combat with distinct tactical questions
→ information/discovery interaction
→ repeatable dungeon/encounter sequence
→ elite/reward decision
→ boss/result
→ return
→ choose to play again
```

Exact names and implementations may be reconciled with existing Living Kingdoms systems. The roadmap protects the player-facing loop and authority boundaries rather than requiring needless rewrites.

# Phase R — Active-place rollout and incident closure

**Status: [~] ACTIVE**

This phase supersedes feature expansion until its promotion gate is accepted.

## R0 — Inventory and baselines — Tickets 331–335

- [ ] **331** Freeze a development copy and record build identity.
- [ ] **332** Inventory every direct/indirect `HordeNetwork.State` producer.
- [ ] **333** Inventory every effective client listener and owning controller.
- [ ] **334** Capture baseline State attempts/sec, sends/sec, and queue symptoms.
- [ ] **335** Capture every Highlight producer/Adornee and baseline connection/presentation gauges.

### Exit gate

- producer/consumer inventory is complete enough to name all known call sites;
- baseline measurements are recorded before architecture changes;
- rollback build/commit is identified.

## R1/R2/R3 — State delivery cutover — Tickets 336–345

- [ ] **336** Enable the earliest compatibility listener in a development place.
- [ ] **337** Prove exactly one effective compatibility listener and no doubled presentation.
- [ ] **338** Enable client-ready gating and delayed-controller test.
- [ ] **339** Migrate the first producer behind semantic key + mutation-derived change token.
- [ ] **340** Prove unchanged attempts suppress and actual sends fall.
- [ ] **341** Migrate round-state producer.
- [ ] **342** Migrate objective-state producer.
- [ ] **343** Migrate route-state producer.
- [ ] **344** Migrate landmark-state producer.
- [ ] **345** Capture before/after per-key rate differences.

### Exit gate

```text
listener-before-ready path understood
pre-ready current state intentionally retained/gated
semantic keys distinguish independent current facts
unchanged state is suppressed
actual network send rate is bounded by mutation
no newly doubled client presentation
```

## R4 — Presentation ownership — Tickets 346–350

- [ ] **346** Route route-guide highlighting through the shared lease registry.
- [ ] **347** Route landmark highlighting through the shared lease registry.
- [ ] **348** Enable broad-target rejection and investigate every violation.
- [ ] **349** Run stream-out/rebind for route, landmark, secret, and marked target.
- [ ] **350** Capture baseline/peak/end presentation gauges.

### Exit gate

```text
one production Highlight owner
route and landmark semantic ownership remain distinct
0 broad production Highlight targets
stream-out suspends local visual without clearing gameplay truth
rebind restores correct visual when target returns
presentation objects return to baseline after cleanup
```

## R5 — Soak, closure, and compatibility removal — Tickets 351–360

- [ ] **351** Run five resets and compare state/network/connection/presentation gauges.
- [ ] **352** Run three respawns and compare viewmodel/camera/connection/presentation gauges.
- [ ] **353** Run delayed-ready and late-join matrix.
- [ ] **354** Run two-player reset/disconnect matrix.
- [ ] **355** Run 100 animation plays and verify marker-listener stability.
- [ ] **356** Run a ten-minute active network/presentation soak.
- [ ] **357** Capture representative client/server profiling/network evidence.
- [ ] **358** Close all P0/P1 rollout defects and rerun affected matrices.
- [ ] **359** Assemble the incident closure packet and conduct promotion review.
- [ ] **360** Remove compatibility only for ledger rows with accepted replacement evidence and a retained rollback checkpoint.

### R5 promotion gate

All must be captured, not assumed:

```text
all legacy producers/consumers inventoried
intended compatibility listener count understood
0 queue/discard warnings in accepted normal play
semantic sends bounded by real state change
route/landmark/status Highlight ownership centralized
0 broad production Highlight targets
five-reset gauges return to baseline
three-respawn gauges return to baseline
delayed-ready/late-join current-state reconstruction passes
stream-out/rebind passes
100 animation plays do not multiply marker listeners
two-player reset/disconnect attribution and cleanup pass
closure packet accepted
rollback checkpoint retained for each removed compatibility row
```

# Phase E — Evidence promotion

**Status: [!] BLOCKED BY PHASE R**

## E2 — Studio initialization

Accept when the repository-synchronized development place starts, required systems initialize, diagnostics are readable, and no blocking initialization/runtime error invalidates the run.

## E3 — Single-player integrated behavior

Accept after the intended loop can be repeated cleanly with stable state/presentation ownership and evidence explaining important failures/outcomes.

Required emphasis:

- authoritative combat/life/outcome;
- route/objective readability;
- reset/respawn cleanup;
- reward/build state consistency;
- no compatibility regression.

## E4 — Multiplayer/adversarial

Accept after two-player ownership, attribution, reset, disconnect, delayed readiness, replay/retry, and audience isolation behave correctly under deliberate edge cases.

# Phase D — Durable value

**Status: [!] BLOCKED UNTIL R + E3/E4**

Resume the durable-value sequence only after runtime ownership is trustworthy:

1. persistence adapter boundary;
2. session ownership/lease rules;
3. sequential migrations;
4. no-blank-overwrite protection;
5. unknown-write reconciliation;
6. inventory/reward overflow recovery;
7. deterministic/idempotent transaction replay;
8. leave/rejoin/shutdown/failure testing.

Do not persist a state model that is still leaking or duplicating in memory.

# Phase V — Vertical-slice integration

**Status: [!] BLOCKED UNTIL ACCEPTED RUNTIME EVIDENCE**

After durable-value/runtime gates permit it, integrate the smallest complete replayable expedition rather than expanding breadth.

Suggested dependency order:

1. preparation/loadout start;
2. authored outdoor route and landmarks;
3. mixed-combat sequence;
4. optional discovery/secret interaction;
5. repeatable dungeon/room sequence;
6. elite + meaningful item decision;
7. boss/terminal outcome;
8. return/replay invitation.

Each integration step must use the accepted state/presentation/lifecycle architecture rather than reintroducing legacy broadcast or competing visual ownership.

# Phase Q — Device, performance, accessibility, and reliability

**Status: [!] REQUIRES REPRESENTATIVE BUILD**

Accept only from measured evidence:

- desktop and mobile frame-time captures;
- network send-rate profile;
- streaming behavior;
- memory/presentation-object stability;
- low-graphics readability;
- reduced-motion behavior;
- UI safe-area/input coverage;
- multiplayer server soak.

# Phase F — Outside-player fun gate

**Status: [!] REQUIRES STABLE INTEGRATED LOOP**

Fresh players should be able to explain:

- what their goal was;
- why they took damage or failed;
- what different enemy/encounter pressures asked them to do;
- what their build/reward choice changed;
- what they wanted to do next.

The strongest signal is voluntary replay, not roadmap completion.

# Scope protection

Do not start broad expansion while any active stop condition is open.

Not authorized yet:

- multiple large regions/continents;
- PvP;
- raids;
- housing;
- unrestricted trading/auction house;
- battle pass/seasons solely to manufacture retention;
- dozens of classes or hundreds of items before the first build loop is readable;
- vehicles/mounts;
- broad monetization catalog;
- speculative backend complexity unsupported by the vertical slice.

# Stop conditions

Stop and fix when:

- remote queue/discard warnings occur in supported normal play;
- state rate/connections/presentation objects grow across reset without a real gameplay reason;
- a broad Highlight hides gameplay;
- two controllers own the same visual primitive;
- late join/delayed readiness loses current facts;
- stream-out is interpreted as gameplay completion;
- animation listeners multiply;
- viewmodel/camera ownership duplicates after respawn;
- client input can author damage, rewards, inventory, progression, or ownership;
- low-graphics/mobile removes critical information;
- an evidence claim cannot point to a reproducible packet.

# Historical milestone records

Detailed P0–P12, HROI, RPG, VIS, and earlier blueprint histories are retained in the versioned/historical roadmap files and Git history. They remain useful when understanding why systems exist, but they do not override the v2.7 queue or promotion gate.

> The current milestone is not “add more.” It is “make the active state path measurable, single-owned, stable, and removable.”
