# Atlas — Execution Dashboard v1.0

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Adopted:** 2026-08-09  
**Purpose:** one compact source of truth for what is done, what is being verified, what agents should build next, and what remains before 1.0.

This dashboard does **not** replace product direction or detailed specifications. It sits above the longer roadmap documents for day-to-day task selection:

```text
accepted runtime evidence / current Roblox platform behavior
→ Blueprint v2.7 + Production Core v2.7 for genuine runtime-safety blockers
→ EXECUTION-DASHBOARD.md for daily task selection and progress truth
→ PLAYABLE-MVP-PATCH-EXECUTION.md for patch scope and acceptance details
→ MASTER-ROADMAP.md for the complete product requirement inventory
→ specialist specifications / architecture / visual-production documents
→ historical roadmaps
```

If this dashboard and an older roadmap disagree about **what to do next**, use this dashboard unless an accepted runtime-safety requirement says otherwise.

---

# 1. Current checkpoint

## Product state

Atlas is no longer in skeleton-building mode. The planned **MVP 0.1 source loop is end-to-end built**, but the milestone remains **BUILT — VERIFICATION PENDING** until one consolidated exact-build Studio/device pass proves the complete loop.

Current intended loop:

```text
safe arrival
→ prepare
→ humble melee start
→ deliberately launch expedition
→ explore
→ fight
→ discover / earn firearm
→ loot / reward decision
→ elite
→ boss / terminal encounter
→ result
→ return to safety
→ bank eligible gear
→ equip / upgrade
→ start another run
```

## Progress snapshot

These percentages are **planning indicators, not evidence levels or acceptance gates**. Update them only when meaningful work changes the phase materially.

| Area | Planning progress | Evidence/status truth |
|---|---:|---|
| Foundation / architecture | ~85% | Mature; preserve canonical ownership/security boundaries |
| MVP 0.1 source implementation | **100%** | **BUILT — VERIFICATION PENDING** |
| MVP 0.1 consolidated verification | **~94%** | One integrated Studio/device pass remains |
| Patch 0.2 combat feel/readability | ~15% | BUILDING; PR #316 overlaps current melee-presentation work |
| Patch 0.3 loot/build replayability | ~25% | Partial foundations exist; broad patch not yet executed |
| Patch 0.4 RPG progression | ~20% | Partial run/progression foundations exist |
| Patch 0.5 Main World/environment | ~25% | Strong planning/contracts; broad player-facing production remains |
| Patch 0.6 systemic replayability | ~15% | Seed/director foundations exist |
| Patch 0.7 persistence hardening | ~35% | Durable inventory/session foundations exist |
| Patch 0.8 co-op/social/session expansion | ~15% | Basic multiplayer foundations exist |
| Patch 0.9 content expansion/pipeline | ~10% | Prepared content/data infrastructure exists |
| Release-candidate hardening | ~5% | Mostly future acceptance/production work |
| **Estimated path to 1.0** | **~30%** | Planning estimate only; status/evidence fields remain authoritative |

Do not optimize development around raising percentages. Optimize around completing the next playable exit gate.

---

# 2. Status vocabulary

Use only these current-status labels for actively maintained roadmap work:

- **NOT STARTED** — no meaningful implementation exists.
- **BUILDING** — active implementation is incomplete.
- **BUILT — VERIFICATION PENDING** — intended source behavior exists and automated/static checks pass, but required Studio/device/human evidence is incomplete.
- **VERIFIED** — required milestone evidence is recorded and accepted.
- **DEFERRED** — useful later, but not the best current work.
- **BLOCKED — <concrete reason>** — cannot safely progress because a specific dependency, authority, data-safety, or runtime result is missing.
- **HISTORICAL** — provenance only; not current task authority.

Never use “locked” merely because work belongs to a later patch. Later work may proceed when it directly enables the current milestone, removes a real dependency, or is an isolated high-value improvement.

---

# 3. Current lanes

There are exactly two valid lanes at this checkpoint.

## Lane A — Human / Studio milestone verification

**Priority:** P0 whenever Studio/device evidence can be run.

Run one consolidated exact-build MVP 0.1 pass:

1. spawn / safe arrival;
2. verify no hostile pressure before deliberate launch;
3. launch expedition;
4. verify route/navigation/readability;
5. verify Field Hatchet input, cadence, prediction, hit feedback and life-state behavior;
6. recover the first Service Pistol from the intended chest path;
7. verify firearm response and weapon differentiation;
8. encounter Stalker/Spitter pressure;
9. use direct world loot/reward interactions;
10. resolve an upgrade/relic choice;
11. defeat elite;
12. complete boss/terminal encounter;
13. verify result/debrief;
14. return to safety;
15. verify completed-run banking and failed/abandoned-run forfeiture behavior;
16. equip durable gear in the existing RPG menu;
17. start run two and verify fresh temporary state plus preserved durable state;
18. repeat representative checks on keyboard, controller and touch;
19. capture representative performance/readability evidence.

### MVP 0.1 verification exit

Promote MVP 0.1 to **VERIFIED** only when:

- a fresh tester can complete the loop without developer intervention;
- return/replay works in the same session;
- temporary run state resets correctly;
- eligible durable state survives correctly;
- required keyboard/controller/touch interactions work;
- no known severe lifecycle, authority, presentation or performance defect invalidates the run;
- evidence identifies the exact build/place/run.

Any actual failure found here immediately becomes the highest-priority FIX and preempts later-patch expansion.

## Lane B — Agent source-safe build-through

**Priority:** P1 while the consolidated Studio/device pass is unavailable and no known runtime failure exists.

Current patch: **0.2 — Combat Feel + Readability**.

Before starting overlapping work, inspect **open PR #316** and rebase/finish/close it as appropriate.

Preferred order inside Patch 0.2:

1. teammate melee swing presentation / multiplayer combat readability;
2. local melee impact and enemy reaction quality;
3. firearm differentiation and recoil/FOV/audio/VFX readability;
4. enemy telegraphs and attack readability;
5. elite readability;
6. boss mechanic readability;
7. movement/combat flow and ability feedback;
8. death/reward punctuation;
9. combat accessibility presentation controls;
10. patch-level Studio/play evidence and fixes.

Do not create new MVP 0.1 scope merely because its consolidated verification is pending.

---

# 4. Completed MVP 0.1 source capabilities

Treat these as **implemented**, not as open roadmap tasks unless evidence reveals a regression:

- safe preparation/arrival surface;
- deliberate expedition launch before pressure arms;
- authored outdoor route and operation flow;
- optional Lookout Cache discovery;
- Field Hatchet melee authority and target/damage path;
- device-neutral primary attack routing;
- melee cadence enforcement, including misses;
- local predicted melee swing feedback;
- server-confirmed melee hit feedback;
- life-state gating for melee input/presentation;
- humble melee → earned firearm opening;
- first personal chest Service Pistol recovery;
- stronger firearm discovery pool preserved afterward;
- server rejection of firearm fire/reload while in melee mode;
- firearm presentation and weapon-specific camera/FOV response;
- direct `E` / controller / touch chest interaction;
- contextual run-upgrade/relic choices;
- Stalker + Blight Spitter pressure mix;
- elite/terminal outcome flow;
- completed-run banking versus failed/abandoned-run forfeiture;
- replay reset of temporary run power;
- durable inventory session lifecycle/leases;
- durable owned-item equip authority;
- equipped durable weapon handoff into the next launch;
- existing RPG menu integration for durable gear;
- warm daytime operation/environment baseline;
- automated repository validation around these boundaries.

Agents must not reimplement any item in this list without a concrete regression or replacement decision.

---

# 5. Remaining roadmap to 1.0

## Patch 0.2 — Combat Feel + Readability

**Status:** BUILDING  
**Goal:** make the existing run enjoyable and easy to read.

Remaining target capabilities:

- stronger weapon differentiation;
- impact/hit feedback;
- enemy reactions;
- readable attack/reload cadence;
- improved movement/combat flow;
- ability feedback;
- enemy telegraphs;
- tactical target/weak-point opportunities where useful;
- elite readability;
- boss mechanic readability;
- combat audio/VFX polish;
- damage/death/reward punctuation;
- presentation accessibility options.

**Exit:** the same MVP run is substantially more enjoyable because combat itself feels good.

## Patch 0.3 — Loot + Build Replayability

**Status:** DEFERRED / FOUNDATIONS PRESENT  
**Goal:** make players want another run for build reasons.

Target capabilities:

- item rarity/quality bands;
- bounded randomized stats/affixes;
- meaningful weapon/build rolls;
- armor/equipment decisions where useful;
- small synergy/set concepts only when they create distinct playstyles;
- stronger reward reveals;
- comparison/equip flow;
- inventory improvements required by those decisions;
- salvage/dismantle/sell only after one coherent value/economy owner exists;
- elite/boss reward identity.

**Exit:** replay motivation comes from curiosity or pursuit of a different/better build.

## Patch 0.4 — RPG Progression

**Status:** DEFERRED / FOUNDATIONS PRESENT  
**Goal:** create durable RPG anticipation between runs.

Target capabilities:

- account/career XP and ranks;
- bounded permanent unlocks;
- archetype/class progression;
- ability/skill choices;
- stat/side-grade progression where justified;
- world/activity unlocks;
- quests and NPC interactions;
- introductory crafting/gathering only when economy/inventory ownership is ready;
- achievements/challenges/codex/discovery progress.

**Exit:** progression increases anticipation without making current gameplay obsolete.

## Patch 0.5 — Main World + Environment Expansion

**Status:** DEFERRED / PREPARATION ADVANCED  
**Goal:** turn the preparation bridge into a memorable, readable home.

Reuse the completed BA-010–BA-014 audit/planning work. Remaining production includes:

- arrival/re-entry readability;
- final landmark hierarchy;
- authored-overworld / Forward Operations Hub integration as authorized;
- routes and dead-travel reduction;
- service/interaction placement;
- environmental storytelling;
- secrets/discoveries;
- terrain/vegetation/structures/props;
- lighting/atmosphere/VFX/audio;
- streaming/performance-aware composition;
- future expansion seams;
- execution of the Main World Studio acceptance matrix.

**Exit:** the world creates curiosity while making the next action understandable.

## Patch 0.6 — Procedural / Systemic Replayability

**Status:** DEFERRED / FOUNDATIONS PRESENT  
**Goal:** multiply replay value without multiplying bespoke code at the same rate.

Target capabilities:

- curated modular dungeon/route assembly;
- improved encounter-director variation;
- enemy variants;
- elite modifiers;
- rotating/procedural objectives;
- randomized encounter situations;
- world events;
- run/dungeon modifiers;
- secret/room variation;
- boss/miniboss variation where readable;
- server-owned reproducible seed/content identity.

**Exit:** the same content kit creates meaningfully different, still-readable runs.

## Patch 0.7 — Durable Persistence + Valuable State Hardening

**Status:** DEFERRED / SUBSTANTIAL FOUNDATIONS PRESENT  
**Goal:** make valuable state trustworthy before its breadth grows.

Remaining hardening:

- account/character ownership boundaries;
- versioned sequential migrations;
- capacity retry and durable overflow recovery;
- quarantine/recovery paths;
- unknown-write reconciliation;
- no-blank-overwrite guarantees;
- transaction idempotency;
- duplicate/replay resistance;
- disconnect/rejoin/shutdown/failure testing;
- degraded-mode observability.

**Exit:** meaningful progress survives realistic lifecycle and failure scenarios.

## Patch 0.8 — Co-op / Social / Session Expansion

**Status:** DEFERRED / BASIC MULTIPLAYER FOUNDATIONS PRESENT  
**Goal:** make cooperative play easier, clearer and more valuable.

Target capabilities:

- party formation/invites;
- friend join;
- readiness/activity selection;
- public/private session policy;
- matchmaking where justified;
- late join/reconnect policy;
- squad state and pings;
- revive/co-op interaction refinement;
- solo-to-party difficulty/scaling policy;
- reward isolation/shared-credit rules;
- deterministic return-to-hub;
- abuse/security boundaries.

**Exit:** cooperative play is clearer and more fun without weakening authority or lifecycle stability.

## Patch 0.9 — Content Expansion + Production Pipeline

**Status:** DEFERRED / PREPARATION PRESENT  
**Goal:** scale only systems that have earned expansion through play evidence.

Target breadth:

- weapons;
- classes/archetypes;
- enemy families;
- elites/bosses;
- dungeon kits;
- regions/biomes;
- quests/events;
- gear sets/affixes;
- abilities;
- validated crafting/resource content;
- cosmetics/expression;
- reusable authoring tools/validators/content pipelines.

**Exit:** substantial content can be added mostly through data and reusable owners rather than bespoke service piles.

## Release Candidate 1.0 — Production Readiness

**Status:** DEFERRED  
**Goal:** turn the proven game into a production candidate.

Required acceptance work:

- onboarding/first-session polish;
- representative keyboard/controller/touch/device testing;
- performance/memory/network profiling;
- accessibility;
- exploit/security hardening;
- production analytics/E7;
- runtime configuration/rollback procedures;
- safety/compliance;
- localization readiness;
- coherent economy balance where applicable;
- outside-player fun/repeat-intent testing;
- ethical monetization only after positive fun/replay evidence;
- alpha → beta → soft launch → release-candidate gates.

**Exit:** a release candidate passes the complete production checklist without hiding a weak core loop behind feature breadth.

---

# 6. Task-selection algorithm for agents

When asked to `continue`, `work on the roadmap`, `implement next task`, or equivalent:

1. fetch current `main`;
2. inspect open PRs before starting overlapping work;
3. check for any concrete Blueprint v2.7 runtime-safety blocker or newly discovered Studio failure;
4. if a real blocker/failure exists, FIX it first;
5. otherwise read this dashboard and identify the current patch/lane;
6. choose the smallest high-ROI task that advances the current patch exit gate;
7. prefer player-facing impact over additional speculative contracts when both are safe;
8. preserve server authority, canonical ownership, rollback points and durable-data safety;
9. run automated/static validation for the increment;
10. merge successful dependency-safe increments without requiring an artificial manual test after every tiny change;
11. label source-complete work **BUILT — VERIFICATION PENDING** until its milestone evidence exists;
12. update this dashboard only when status, next task, or meaningful progress changes;
13. report: current patch, what changed, validation evidence, known limitations, and next highest-ROI task.

### Duplicate-work rule

If an open PR already overlaps the intended task, inspect/rebase/finish/close that work before creating another implementation.

### Verification-debt rule

Pending milestone verification is tracked explicitly. It does **not** turn already-built source work back into “not done,” and it does not freeze unrelated dependency-safe progress. A concrete failed runtime result does preempt later work.

---

# 7. Scope-control rules

Until evidence shows the core loop deserves expansion, avoid broad work on:

- giant additional regions;
- PvP;
- raids;
- housing;
- unrestricted trading/auction houses;
- mounts/vehicles;
- dozens of classes;
- item-count expansion for its own sake;
- large monetization catalogs;
- speculative backend complexity;
- seasons/battle passes created before retention is earned.

Prefer one excellent replayable loop over ten shallow systems.

---

# 8. Stop conditions

Stop expansion and fix immediately when any of these become true:

- client input can author damage, rewards, inventory, progression, economy or ownership truth;
- valuable state can blank, duplicate, replay or corrupt;
- two systems compete for the same gameplay/presentation authority;
- a supported reset/replay/respawn path leaks state or listeners;
- delayed readiness/late join loses current authoritative facts;
- normal play produces remote queue/discard warnings;
- presentation objects/connections grow across lifecycle transitions without reason;
- supported input/device paths cannot complete the current milestone;
- critical gameplay information disappears on low graphics/accessibility settings;
- generated content can become unwinnable or unreadable;
- an evidence claim cannot identify a reproducible build/place/run.

---

# 9. Current next task

## If Studio/device testing is available

**P0:** Run the consolidated exact-build **MVP 0.1 STOP / PLAY / FIX** pass and promote the milestone only if the evidence succeeds.

## If source work is the available lane

**P1:** Inspect and finish/rebase **PR #316 — server-confirmed teammate melee swings**, then continue the highest-ROI unfinished **Patch 0.2 Combat Feel + Readability** improvement.

Do not reopen completed MVP 0.1 feature work unless a concrete verification failure proves it needs repair.
