# Atlas — Static Playable Evidence Gate

**Status:** CURRENT PRODUCT EVIDENCE GATE  
**Adopted:** 2026-08-17  
**Scope:** Living Kingdoms / Atlas first integrated playable proof  
**Execution authority:** `EXECUTION-DASHBOARD.md`

## Decision

Atlas will prove the existing core expedition loop on a **fixed, deterministic layout before further procedural/world breadth is allowed to drive execution**.

This is a product-evidence decision, not a request to rebuild systems that already exist.

The repository already contains substantial canonical camera, combat, enemy, mission, loot, progression, persistence, world, and presentation systems. Those owners remain authoritative. The gate uses the current runtime to answer the question source inspection cannot answer:

> Is the smallest complete Atlas run understandable, satisfying, and worth immediately replaying?

## Why this path wins

The current product authority says to build the smallest coherent playable result and measure what source cannot prove. The patch sequence also defines MVP 0.1 as the first complete repeatable run, while procedural/systemic replayability is a later product layer.

A procedural generator can prove deterministic geometry, but it cannot prove:

- combat feels good;
- damage and enemy intent are readable;
- objectives are understandable;
- rewards feel meaningful;
- return/replay flow is clear;
- the player wants another expedition.

Those are currently higher-information questions.

Therefore the fixed integrated run is the next product gate. Procedural work remains valuable, but it is downstream of evidence that the underlying loop deserves multiplication.

## Important: do not rebuild the game

Static-first means **static-first validation**, not greenfield implementation.

Do not create replacement camera, combat, enemy, mission, loot, inventory, persistence, or world owners merely to construct a test slice. Use current canonical source and the smallest existing configuration/path that can exercise the loop.

If the current fixed path cannot complete the gate, record the exact reproducible failure and fix only the smallest canonical owner responsible for that failure.

## Test topology

Use current `main` and its fixed/deterministic expedition spatial path. Do not require procedural cardinal generation, multi-run spatial ownership, a large Main World expansion, crafting, deeper class trees, additional regions, or monetization to conduct this gate.

The target integrated rhythm is:

```text
safe arrival / preparation
→ deliberate expedition launch
→ fixed readable route
→ movement + combat pressure
→ objective progress
→ meaningful reward / loot interaction
→ elite or terminal/boss outcome where current content supports it
→ result
→ return
→ bank/equip/understand the outcome
→ choose whether to replay
```

When a current system is absent or broken, that fact is evidence. Do not paper over it with a new parallel subsystem.

## Gate A — Boot and reset

Pass when the same test configuration can be started, completed/failed, returned/reset, and started again without accumulating broken lifecycle state.

Record:

- exact place/build/ref;
- player count;
- configuration/seed if applicable;
- start path;
- result/return path;
- any soft-lock, duplicate listener, stale UI, orphaned entity, or reset failure.

A reproducible lifecycle failure authorizes a focused FIX before further evidence work.

## Gate B — Combat readability and control

A tester should be able to move, aim/attack, understand major incoming threats, identify why meaningful damage/death occurred, and distinguish success/failure feedback without developer narration.

Observe:

- responsiveness;
- hit/impact confirmation;
- enemy telegraphs and target readability;
- damage/death explanation;
- camera/HUD obstruction;
- recovery/reset clarity;
- obvious unfair or confusing states.

Do not add extra weapons, enemies, abilities, effects, or difficulty merely to increase feature count before this gate is coherent.

## Gate C — Complete fixed expedition

A first-time tester should be able to understand what to do, progress through the fixed route, reach a legitimate result/failure, and return without live developer coaching.

Record friction by stage:

1. arrival/orientation;
2. launch;
3. route comprehension;
4. objective comprehension;
5. combat/encounter comprehension;
6. result/failure comprehension;
7. return;
8. replay affordance.

If the player gets lost, stalled, or confused, classify whether the root cause is UX, world readability, objective lifecycle, encounter state, presentation, or a runtime defect before changing code.

## Gate D — Reward and replay desire

The player should understand what they earned or lost, what changed, and what they can do next.

At least one current reward/build outcome should be legible enough that a tester can explain why it matters without being taught the implementation.

The directional replay signal is:

> **At least 50% of first-time external testers who reach a legitimate result choose another attempt without being prompted to do so.**

For a very small cohort, treat this as a decision signal rather than statistical proof. Record the raw counts and observations; do not manufacture precision.

If replay desire is weak, fix the strongest measured source of friction before adding procedural breadth.

## Evidence cadence

Use a small fast cohort first. The purpose is to expose high-leverage failures in days, not to conduct a launch-scale study.

Recommended minimum packet:

- one developer-controlled smoke run to confirm the environment is testable;
- at least three clean repeat/reset attempts;
- several first-time external attempts when available;
- raw observation notes, not retrospective memory;
- exact reproduction for any failure that should become source work;
- explicit pass/fail/unknown for each gate above.

Do not claim a fact was measured when it was inferred from source.

## What may execute while this gate is active

Allowed:

- documentation/evidence setup required to run the gate;
- a focused source fix for a reproducible gate failure;
- narrowly necessary test/build/runtime repair that makes the gate runnable;
- safety/security/data-integrity fixes that independently preempt product work.

Not allowed as automatic NEXT work:

- procedural route expansion;
- additional dungeon themes;
- large Main World expansion;
- broad content multiplication;
- crafting/economy breadth;
- deep class/skill-tree expansion;
- guild/housing/trading systems;
- monetization;
- generic hardening that does not fix a measured gate problem or known safety defect.

The 1,000-ticket LKB inventory remains candidate inventory. During this gate, an unlocked backlog mutex is not permission to select unrelated candidate work merely to keep an agent busy.

## LKB-0481 handling

LKB-0481 procedural spatial resolution is valuable later, but it is no longer the current product priority.

Its existing branch/PR work must be preserved as candidate implementation evidence rather than deleted or copied into a replacement owner. It may be re-audited and re-authorized after the fixed playable gate passes, if it remains the highest-ROI next layer against then-current `main`.

Do not merge it solely because work has already been invested. Do not discard it solely because priority changed.

## Exit decision

### PASS

The fixed run is coherent enough that the coordinator may resume normal source selection. Re-rank the smallest next player-value capability against current evidence. Procedural replayability becomes eligible, not automatic.

### FAIL

Select the **single highest-leverage measured failure**, map it to the canonical owner, implement the smallest fix, validate it, and rerun the affected gate.

### UNKNOWN

If the environment/evidence is insufficient to judge, improve the evidence setup only. Do not convert uncertainty into feature work.

## Operating rule

> **Prove one understandable, satisfying, repeatable run before multiplying it.**

The point is not to make Atlas smaller. The point is to make every later system multiply something players have already shown is worth multiplying.
