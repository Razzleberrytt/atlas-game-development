# Atlas — Execution Dashboard v1.2

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-09  
**Purpose:** answer four questions quickly: **what is true, what is NOW, what is NEXT, and what must wait?**

For detailed patch acceptance, use `PLAYABLE-MVP-PATCH-EXECUTION.md`. For complete long-range scope, use `MASTER-ROADMAP.md`. For repeated-friction/reuse decisions, use `DEVELOPMENT-FLYWHEEL.md`. Do not duplicate those documents here.

## 1. Current truth

- **MVP 0.1 source implementation:** **100% BUILT — VERIFICATION PENDING**.
- **Known required MVP 0.1 source gaps:** none currently identified.
- **Human/Studio P0 lane:** one consolidated exact-build MVP 0.1 play/device/performance pass.
- **Agent/source lane:** **Patch 0.2 — Combat Feel + Readability**.
- **Engineering leverage policy:** active; comparable dependency-safe tasks favor reusable/data-driven/testable/toolable implementations without delaying player value for speculative abstraction.
- **Estimated path to 1.0:** ~30% planning estimate only; status/evidence labels are authoritative.

Current playable loop:

```text
safe arrival → prepare → melee start → deliberate expedition launch
→ explore → fight → earn firearm → loot/reward decision
→ elite → boss/terminal → result → return → bank/equip
→ replay with temporary state reset and durable state preserved
```

## 2. NOW → NEXT → LATER

### NOW

**Finish existing overlapping Patch 0.2 PR #316 before creating duplicate teammate-melee presentation work.**

Desired result: server-confirmed teammate melee swings are readable in third person without moving combat authority to the client.

### NEXT

After #316 is resolved and no MVP 0.1 runtime failure has appeared:

1. improve **local melee impact + enemy reaction quality**;
2. then improve **firearm differentiation / recoil / FOV / audio / VFX readability**;
3. then **enemy telegraphs / elite / boss readability**.

Within those increments, prefer extending reusable presentation/reaction contracts so later weapons and enemies become cheaper to add, but do not stop Patch 0.2 for a speculative framework.

### LATER

Do not pull these forward unless they remove a real dependency for the current patch:

- Patch 0.3 loot/build replayability;
- Patch 0.4 RPG progression;
- Patch 0.5 Main World/environment expansion;
- Patch 0.6 systemic replayability;
- Patch 0.7 persistence hardening;
- Patch 0.8 co-op/social/session expansion;
- Patch 0.9 content/pipeline expansion;
- release-candidate hardening.

### WIP limit

- one active implementation PR for the current capability;
- at most one additional non-overlapping feature PR when the first is externally blocked;
- documentation/workflow maintenance does not count as a feature PR;
- never start a second implementation for work already covered by an open PR.

## 3. P0 Studio verification lane

When Studio/device evidence can be run, it outranks source expansion.

Run one exact-build pass covering:

```text
spawn / safe arrival
→ deliberate launch
→ route/navigation
→ Field Hatchet input/cadence/feedback
→ Service Pistol recovery
→ firearm response
→ Stalker/Spitter pressure
→ loot + upgrade/relic interaction
→ elite
→ boss/terminal
→ result/debrief
→ return
→ banking/forfeiture
→ durable equip
→ run-two reset/preservation
→ representative keyboard/controller/touch
→ representative performance/readability
```

Promote MVP 0.1 to **VERIFIED** only when the required evidence passes. Any actual failure discovered here becomes NOW immediately and preempts Patch 0.2.

## 4. Planning snapshot

Percentages are rough planning indicators, not acceptance evidence.

| Area | Planning progress | Status truth |
|---|---:|---|
| Foundation / architecture | ~85% | mature |
| MVP 0.1 source | **100%** | **BUILT — VERIFICATION PENDING** |
| MVP 0.1 consolidated verification | ~94% | integrated pass remains |
| 0.2 combat feel/readability | ~15% | BUILDING |
| 0.3 loot/builds | ~25% | foundations present |
| 0.4 RPG progression | ~20% | foundations present |
| 0.5 Main World/environment | ~25% | planning advanced, production partial |
| 0.6 systemic replayability | ~15% | foundations present |
| 0.7 persistence hardening | ~35% | substantial foundations present |
| 0.8 co-op/social/session | ~15% | basic foundations present |
| 0.9 content/pipeline | ~10% | preparation present |
| Release-candidate hardening | ~5% | mostly future |
| **Estimated path to 1.0** | **~30%** | planning estimate only |

Do not optimize for percentage movement. Optimize for the next patch exit condition and, when choices are otherwise comparable, future marginal implementation cost.

## 5. Patch path and exit signal

| Patch | Goal | Exit signal | Compounding target |
|---|---|---|---|
| **0.2 Combat Feel** | make the existing run satisfying/readable | fighting itself is substantially more enjoyable | reusable feedback/reaction contracts |
| **0.3 Loot + Builds** | create build-driven replay motivation | player wants another run for a different/better build | validated item/affix/reward data |
| **0.4 RPG Progression** | create durable anticipation | progression adds anticipation without invalidating current play | reuse stat/effect/reward owners |
| **0.5 Main World** | create a memorable readable home | world creates curiosity while next action stays clear | stable IDs, registries, composition data |
| **0.6 Systemic Replayability** | multiply variety from reusable systems | same content kit produces meaningfully different readable runs | encounter/modifier/route/event combinatorics |
| **0.7 Persistence Hardening** | make valuable state trustworthy | progress survives realistic lifecycle/failure scenarios | lifecycle/migration regression defenses |
| **0.8 Co-op/Social** | make co-op easier and more valuable | group play is clearer/funner without authority regressions | multiplayer coverage over existing owners |
| **0.9 Content/Pipeline** | scale proven systems efficiently | breadth is mostly data/reusable-owner driven | cash in accumulated tooling and schemas |
| **RC 1.0** | production readiness | full production checklist passes without hiding a weak core loop | accumulated tests/audits reduce hardening cost |

Detailed capability lists live in `PLAYABLE-MVP-PATCH-EXECUTION.md` and `MASTER-ROADMAP.md`; agents should open them only when the current task needs that detail.

## 6. Status vocabulary

Use only:

```text
NOT STARTED
BUILDING
BUILT — VERIFICATION PENDING
VERIFIED
DEFERRED
BLOCKED — concrete reason required
HISTORICAL
```

Pending Studio evidence does not erase completed source work. Source checks do not prove Studio behavior.

## 7. Agent task algorithm

When asked to continue:

1. fetch current `main`;
2. inspect open PRs;
3. read **NOW → NEXT → LATER** above;
4. check for a concrete runtime-safety or newly discovered milestone failure;
5. if one exists, fix it first;
6. otherwise take NOW;
7. take NEXT only if NOW is resolved or externally blocked and the work does not overlap;
8. select the smallest coherent increment that advances the current patch exit signal;
9. if two candidates are similarly valuable and dependency-safe, prefer the one with greater near-term reuse, data conversion, regression protection, friction automation, or agent clarity; consult `DEVELOPMENT-FLYWHEEL.md` when non-obvious;
10. classify risk using root `AGENTS.md`;
11. run the matching `python scripts/validate.py <profile>` locally/through CI;
12. merge successful dependency-safe work;
13. update this dashboard only when NOW/NEXT, blocker, status, or meaningful progress changes.

## 8. Immediate stop conditions

Stop expansion and fix when any of these is true:

- client input can author consequential truth;
- valuable state can blank, duplicate, replay, or corrupt;
- two systems compete for the same authority/presentation ownership;
- reset/replay/respawn leaks state or listeners;
- late readiness/late join loses authoritative current facts;
- supported input/device paths cannot complete the current milestone;
- generated content becomes unreadable or unwinnable;
- severe performance/readability failure invalidates the playable loop;
- an evidence claim cannot identify a reproducible build/place/run.

## 9. Scope control

Until the current loop earns expansion, avoid broad speculative work such as giant extra regions, PvP, raids, housing, auction houses, mounts/vehicles, dozens of classes, item-count growth for its own sake, large monetization catalogs, or seasons/battle passes.

Leverage work follows the same scope rule: no giant refactor, framework, generator, or abstraction without identified near-term consumers and a bounded payoff.

> **One dashboard, one NOW task, low WIP, automatic validation, coherent milestone testing — and each patch should make the next patch cheaper when practical.**