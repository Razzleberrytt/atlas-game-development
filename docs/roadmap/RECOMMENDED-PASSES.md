# Atlas — Recommended Production Passes v2.7

This file is **descriptive only**. It does not control ticket IDs, dependency order, or promotion. The current authority is:

1. [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md)
2. [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md)
3. [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md)

When this file conflicts with the v2.7 queue, the queue wins.

## Pass 1 — Runtime producer/consumer inventory

**Gate:** Tickets 331–335  
**Status:** active prerequisite

Cover:

- every `HordeNetwork.State` producer;
- every effective client listener;
- baseline attempts/sec and sends/sec;
- queue/discard evidence;
- every production Highlight producer and `Adornee`;
- baseline application/character/round connection gauges;
- baseline transient presentation counts.

No architectural migration begins until the before-state is recorded.

## Pass 2 — State-delivery cutover

**Gate:** Tickets 336–345  
**Status:** blocked on Pass 1 evidence

Cover:

- earliest intended compatibility listener;
- client-ready delivery gate;
- semantic state keys;
- mutation-derived change tokens;
- unchanged-state suppression;
- round/objective/route/landmark producer migration;
- before/after per-key rate comparison.

Success means actual network sends fall to the rate required by state mutation without losing current state or creating doubled client presentation.

## Pass 3 — Presentation-ownership cleanup

**Gate:** Tickets 346–350  
**Status:** blocked on relevant state cutover

Cover:

- shared Highlight lease ownership;
- route-guide migration;
- landmark-accent migration;
- status/mark integration with the same registry where applicable;
- broad-target rejection;
- streaming out/rebind behavior;
- baseline/peak/end presentation-object gauges.

Do not run another broad visual-polish pass while two controllers still compete for the same primitive.

## Pass 4 — Reset/respawn/late-join soak

**Gate:** Tickets 351–356  
**Status:** blocked on Passes 2–3

Required matrices:

```text
five operation resets
three character respawns
delayed-ready client
late join
two-player reset/disconnect
100 animation plays
ten-minute active network/presentation soak
```

Primary question: does every gauge return to the accepted baseline, and does network rate remain semantically bounded?

## Pass 5 — Profiling and rollout closure

**Gate:** Tickets 357–360  
**Status:** blocked on clean soak

Cover:

- representative client/server profiling/network capture;
- P0/P1 defect closure and rerun;
- incident closure packet;
- rollback checkpoint review;
- compatibility removal only for ledger rows with accepted replacement evidence.

Compatibility code is removed per proven row, not in one ceremonial cleanup commit.

## Pass 6 — Visual production continuation

**Gate:** accepted v2.7 runtime/presentation ownership for the relevant feature  
**Status:** partially active where it cannot interfere with the rollout; otherwise gated

Existing visual work remains useful, including weapon/operative/enemy/world readability, audio, effects, authored-place conversion, and accessibility. However:

- critical route/landmark/status presentation must use the accepted ownership path;
- no broad procedural geometry pass should be used to avoid Studio review;
- visual polish may not hide unresolved network/lifecycle leaks;
- low graphics and reduced motion must preserve essential gameplay cues.

See [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) and the visual specifications for asset-level detail.

## Pass 7 — Durable-value/persistence proof

**Gate:** accepted rollout plus trustworthy E3/E4 behavior  
**Status:** blocked

Resume only when in-memory ownership and cleanup are trusted.

Cover:

- persistence adapter boundary;
- session ownership;
- sequential migrations;
- no-blank-overwrite;
- unknown-write reconciliation;
- overflow recovery;
- idempotent transaction replay;
- leave/rejoin/shutdown/failure tests.

Do not persist a runtime state model that still leaks or duplicates.

## Pass 8 — Vertical-slice integration

**Gate:** accepted runtime and durable-value dependencies  
**Status:** blocked

Integrate the smallest complete replayable operation:

```text
prepare/loadout
→ authored route
→ mixed pressure
→ discovery/information interaction
→ repeatable encounter/dungeon sequence
→ elite/reward choice
→ boss/result
→ return/replay
```

Existing Living Kingdoms systems may satisfy or replace individual beats; the requirement is one coherent loop using one authoritative state/presentation architecture.

## Pass 9 — Device, accessibility, and performance

**Gate:** representative integrated build  
**Status:** blocked

Measure:

- desktop/mobile frame time;
- network send rates;
- memory/transient object stability;
- streaming/rebind behavior;
- low-graphics readability;
- reduced-motion presentation;
- UI/input safe areas;
- multiplayer server soak.

Measure first; optimize the measured bottleneck.

## Pass 10 — Outside-player usability/fun

**Gate:** stable integrated loop  
**Status:** blocked

Fresh players should be able to explain:

- what they were trying to do;
- what threatened them and why;
- why they failed or succeeded;
- what their build/reward changed;
- what they want to do next.

The strongest outcome is voluntary replay.

## Explicitly deferred broad passes

Do not schedule these while the active rollout or core-loop gates remain open:

- large world/region expansion;
- PvP;
- raids;
- housing;
- unrestricted trading/auction systems;
- battle pass/seasons as a substitute for core retention;
- dozens of new classes;
- hundreds of items before build choices are readable;
- vehicles/mounts;
- broad monetization catalog.

## Historical passes

Older P6–P12, HROI, RPG, VIS, audio, scarcity, tuning, and presentation passes remain visible in Git history and their original specifications. Completed work remains valid. Their old sequencing does not override Tickets 331–360.

> The next pass is the smallest one that closes the current measurable risk—not the most exciting one that can be imagined.
