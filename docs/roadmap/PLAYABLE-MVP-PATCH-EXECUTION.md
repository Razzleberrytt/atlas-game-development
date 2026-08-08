# Atlas — Playable MVP + Patch Execution v2.9

**Status:** CURRENT EXECUTION-SEQUENCING AUTHORITY  
**Adopted:** 2026-08-08  
**Scope:** Product implementation order after and around the active v2.7 runtime stabilization gate.  
**Supersedes for sequencing:** any older roadmap interpretation that would build broad future systems before the next playable checkpoint.  
**Does not supersede:** accepted runtime evidence, current Roblox platform behavior, Blueprint v2.7 runtime safety/rollout requirements, canonical ownership/security rules, or explicit architecture decisions.

## Why this document exists

Atlas already has a complete long-range roadmap. The problem is not lack of scope; it is execution shape.

The game must become playable early, stay playable, and grow through small upgrade patches that can be tested and debugged in isolation. A future system being fully specified does not make it higher priority than the next playable checkpoint.

The controlling production rule is now:

> **Always leave Atlas playable. Build the smallest complete loop, test it, fix it, then add one coherent layer.**

## Precedence rule

For implementation sequencing, use this order:

```text
accepted runtime evidence / current Roblox platform behavior
→ Blueprint v2.7 + Production Core v2.7 while the active stabilization/rollout gate remains open
→ PLAYABLE-MVP-PATCH-EXECUTION.md (this document)
→ Current Product Authority + MASTER-ROADMAP.md for product direction and complete scope inventory
→ Active Place Rollout + Cross-System Traceability + production controls
→ accepted current specifications / architecture decisions
→ specialist visual/environment/Studio guidance
→ historical charters, pivots and older roadmaps
```

This means:

- v2.7 may still block unsafe runtime activation;
- once work is eligible, this document decides **which playable slice comes first**;
- `MASTER-ROADMAP.md` remains the complete destination and requirement inventory, but its later phases may not leapfrog the playable patch order below;
- build-ahead work should preferentially prepare the **next playable patch**, not whichever future system is easiest to implement;
- agents must not use a detailed future specification as permission to expand breadth early.

## Global patch law — STOP / PLAY / FIX

Every playable milestone and upgrade patch ends at a hard gate:

1. **STOP** — do not begin the next patch while a known blocker prevents the current build from being played end to end.
2. **PLAY** — run the current representative loop in Studio using the applicable evidence checklist.
3. **FIX** — repair regressions, lifecycle failures, broken transitions, unreadable gameplay, progression/reward faults, or severe performance defects before expansion.
4. **REPLAY** — prove the loop can be repeated, not merely completed once.
5. **THEN EXPAND** — only after the patch exit gate is satisfied does the next patch become runtime-eligible.

Static validation remains required, but static validation does not replace Studio/runtime evidence for playable claims.

## Patch design rules

Each patch should:

- add one coherent player-facing layer;
- preserve the previous patch's end-to-end loop;
- include regression coverage for the previous playable baseline;
- avoid unrelated architectural rewrites;
- keep server authority and canonical ownership intact;
- use temporary/minimal implementations where they are sufficient to test the player loop;
- defer breadth until the underlying loop proves it deserves expansion;
- record exact known limitations instead of hiding unfinished scope behind polish.

A patch is not complete because its code merged. It is complete when its intended player-facing result is playable and its required evidence is recorded.

# Gate 0 — Runtime stabilization + world audit

**Status:** ACTIVE / PARTIALLY COMPLETE

Before MVP runtime activation:

- finish the dependency-safe Blueprint v2.7 rollout/stabilization work required for a trustworthy playable baseline;
- preserve the accepted R1 rollback checkpoint and subsequent evidence chain;
- close required listener/presentation/lifecycle blockers rather than building around them;
- use the completed BA-010 Main World/environment audit and its follow-up specifications to decide what world content is kept, refined, rebuilt, replaced, removed, or added;
- do not require the final Main World before MVP 0.1 — only the smallest coherent preparation/return surface needed for the complete run.

**Gate 0 exit:** Atlas has a trustworthy runtime baseline on which a complete player loop can be assembled without knowingly depending on broken state delivery, presentation ownership, or lifecycle behavior.

# MVP 0.1 — First Complete Run

**Priority:** HIGHEST PLAYER-FACING PRIORITY AFTER GATE 0

Target player loop:

```text
spawn / arrive
→ orient and prepare
→ choose a weapon/build
→ enter one expedition
→ explore a readable route
→ fight several encounter types
→ receive loot/reward decisions
→ defeat an elite
→ reach and defeat one boss / terminal encounter
→ receive result/reward
→ return to preparation space
→ equip or apply an upgrade
→ start another run
```

Target first-run duration: roughly **5–10 minutes**, adjustable after play evidence.

## Minimum viable scope

Use the smallest coherent implementation that proves the loop. Prefer existing working systems when available.

Minimum target content:

- one compact preparation/Main World bridge surface;
- one expedition launch path;
- one authored outdoor/route segment;
- one small repeatable dungeon/encounter sequence;
- roughly three distinct enemy tactical questions/families or equivalent encounter roles;
- one elite;
- one boss/terminal encounter;
- two or three meaningfully distinct weapon/build choices;
- basic abilities where required by the current combat identity;
- health, failure, recovery/retry and return flow;
- basic randomized or choice-based loot/rewards;
- minimal equipment/loadout handling;
- minimal inventory sufficient for the loop;
- minimal progression sufficient to make the second run meaningfully different;
- minimal safe persistence only for state that must survive the test/rejoin loop;
- basic 1–4 player support only to the extent required by current co-op foundations and evidence gates;
- at least one optional discovery/secret or equivalent curiosity reward.

Do **not** block MVP 0.1 on broad crafting, a full economy, a huge skill tree, multiple regions, hundreds of items, full matchmaking, final overworld art, or launch monetization.

## MVP 0.1 acceptance questions

- Can a fresh tester understand how to start?
- Can they complete the loop without developer intervention?
- Does the return flow work reliably?
- Can the loop be repeated in the same session?
- Does a reward or build decision create a reason to try again?
- Are combat, objectives and navigation readable enough to diagnose fun rather than confusion?

**Primary product signal:** a tester voluntarily chooses to start another run.

# Patch 0.2 — Combat Feel + Readability

**Goal:** make the already-playable loop satisfying to control and understand.

Prioritize:

- responsiveness and input feel;
- weapon differentiation;
- hit/impact feedback;
- enemy reactions;
- reload/attack cadence readability;
- movement/combat flow;
- ability feedback;
- enemy telegraphs;
- weak points or equivalent tactical targets where appropriate;
- elite readability;
- boss mechanic readability;
- combat audio/VFX polish;
- damage/death/reward punctuation;
- relevant presentation accessibility controls.

**Exit question:** is the same MVP run substantially more enjoyable because fighting itself feels good?

# Patch 0.3 — Loot + Build Replayability

**Goal:** create a strong reason to replay the proven combat loop.

Add only as much depth as can be evaluated clearly:

- item/upgrade rarity or quality bands;
- randomized stats or bounded affixes where appropriate;
- meaningful weapon/build rolls;
- armor/equipment only where it improves decisions;
- basic set/synergy concepts if they create distinct playstyles;
- strong reward presentation;
- comparison/equip flow;
- inventory improvements required by the new decisions;
- dismantle/sell/salvage only if a coherent owner/value model already exists;
- boss/elite reward identity.

**Exit question:** does the player want another run because they are curious about or pursuing a better/different build?

# Patch 0.4 — RPG Progression

**Goal:** make Atlas feel meaningfully RPG-like without burying the proven run loop.

Candidate scope:

- XP/rank progression;
- bounded long-term unlocks;
- archetype/class progression;
- ability/skill choices;
- stat or side-grade progression where justified;
- world/activity unlocks;
- quests and NPC interactions;
- introductory crafting/gathering only if the canonical economy/inventory boundaries are ready;
- achievements/challenges/codex progress.

Prefer a small testable progression map over a huge skill tree.

**Exit question:** does progression create anticipation between runs without making the current gameplay obsolete?

# Patch 0.5 — Main World + Environment Expansion

**Goal:** turn the preparation bridge into a memorable, readable home without sacrificing iteration speed.

Use BA-010 and subsequent world specifications as the source for environment decisions.

Expand deliberately through:

- arrival/re-entry readability;
- landmark hierarchy;
- Forward Operations Hub / authored overworld integration as authorized;
- traversal routes and dead-travel reduction;
- service/interaction placement;
- environmental storytelling;
- secrets/discovery;
- dynamic/world encounters where useful;
- terrain, vegetation, structures, props, lighting, atmosphere, VFX and audio;
- streaming/performance-aware composition;
- future expansion seams.

**Exit question:** does the world make players curious and help them understand where to go next?

# Patch 0.6 — Procedural / Systemic Replayability

**Goal:** multiply content without requiring one-off manual content at the same rate.

Candidate multipliers:

- modular dungeon/route assembly;
- encounter director improvements;
- enemy variants;
- elite modifiers;
- affix/build combinations;
- procedural or rotating objectives;
- randomized encounter situations;
- world events;
- dungeon/run modifiers;
- secret/room variation;
- boss/miniboss variation where readable.

Randomness must preserve navigation, objective and difficulty clarity.

**Exit question:** can the same content kit generate meaningfully different runs without becoming incoherent?

# Patch 0.7 — Durable Persistence + Valuable State Hardening

**Goal:** harden the systems that survived playable testing before scaling the amount of valuable data.

Re-adopt the existing persistence quality work here, including as applicable:

- durable inventory/progression ownership;
- account/character progression boundaries;
- currencies/unlocks that have proven product value;
- versioned migrations;
- capacity retry;
- durable overflow/recovery;
- session ownership;
- duplicate/replay resistance;
- sequential migrations;
- quarantine/recovery paths;
- unknown-write reconciliation;
- no-blank-overwrite protection;
- disconnect/rejoin correctness;
- transaction idempotency for valuable mutations.

**Exit question:** can players trust that meaningful progress survives real lifecycle failures?

# Patch 0.8 — Co-op / Social / Session Expansion

**Goal:** deepen the cooperative product after the core loop works solo and in basic multiplayer.

Candidate scope:

- proper party formation/invites;
- friend join;
- readiness;
- activity selection;
- public/private session policy;
- matchmaking where justified;
- late join/reconnect policy;
- squad state and pings;
- revive/co-op interaction refinement;
- difficulty/scaling policy;
- reward isolation/shared-credit rules;
- deterministic return-to-hub behavior;
- abuse/security boundaries.

**Exit question:** is playing with other people easier, clearer and more fun than before without compromising authority or lifecycle stability?

# Patch 0.9 — Content Expansion + Production Pipeline

**Goal:** scale only the systems that have earned expansion through earlier play evidence.

Now increase breadth:

- weapons;
- archetypes/classes;
- enemy families;
- bosses;
- dungeon kits;
- regions/biomes;
- quests/events;
- gear sets/affixes;
- abilities;
- crafting/resource content where validated;
- cosmetics/expression;
- authoring tools, validators and reusable production pipelines.

Favor data-driven reusable production over bespoke feature piles.

**Exit question:** can the team add substantial new content without destabilizing the proven loop or multiplying maintenance cost unsafely?

# Release Candidate 1.0 — Production Readiness

**Goal:** convert the proven, repeatedly upgraded game into a release candidate.

This is where the broader Master Roadmap release work becomes primary:

- onboarding/first-session polish;
- representative device testing;
- performance/memory/network profiling;
- accessibility;
- exploit/security hardening;
- production analytics and E7 readiness;
- runtime configuration/feature flags/rollback;
- safety/compliance;
- localization readiness;
- economy balance where applicable;
- outside-player fun/repeat-intent validation;
- ethical monetization only after the fun gate;
- alpha/beta/soft-launch/production launch criteria.

A 1.0 candidate may not use unfinished breadth to hide a weak core loop.

# Post-1.0 — Live Upgrade Patches

After release, continue the same development law:

```text
observe
→ choose one coherent improvement
→ implement
→ validate
→ play
→ fix regressions
→ release
→ measure
```

Potential post-launch patches may add zones, bosses, weapons, events, classes, progression branches, social features, challenge modes or seasonal content, but each must preserve the playable baseline and use live evidence rather than speculative breadth.

# Relationship to Master Roadmap v2.8

`MASTER-ROADMAP.md` remains the complete requirements and dependency inventory. Its phases are mapped into this execution order rather than deleted.

Examples:

- Main World/environment work maps primarily to Gate 0, MVP 0.1 and Patch 0.5;
- party/social/session work maps to MVP-minimum needs and Patch 0.8;
- persistence work maps to MVP-minimum safe state and Patch 0.7 hardening;
- progression/economy/content work maps to Patches 0.3, 0.4, 0.6 and 0.9;
- quality/device/performance work is continuous, with full release acceptance at 1.0;
- outside-player fun becomes measurable at MVP 0.1 and progressively stronger in later patches;
- analytics/ops/compliance/localization/monetization/launch remain later release gates unless a smaller prerequisite is explicitly required earlier.

When there is ambiguity between "finish an entire Master Roadmap phase" and "finish the next playable patch," choose the smallest dependency-safe work that completes the next playable patch.

# Agent task-selection rule

When an agent is asked to "continue," "work on the roadmap," or "do the next thing":

1. fetch current `main` and inspect related open PRs;
2. identify whether Blueprint v2.7 still has a blocking stabilization dependency;
3. if yes, perform the next dependency-safe blocker or safe preparation that directly enables the next playable checkpoint;
4. otherwise identify the **current playable patch** in this document;
5. choose the highest-ROI unfinished task required for that patch's exit gate;
6. do not start later-patch breadth while a current-patch blocker is known;
7. preserve prior patch regression tests and playable behavior;
8. report the current patch, blocker, evidence produced, and next highest-ROI task.

# Definition of execution success

The roadmap is succeeding when Atlas becomes easier to test as it grows.

The intended development rhythm is:

```text
stable foundation
→ playable MVP 0.1
→ test/debug
→ 0.2 combat patch
→ test/debug
→ 0.3 loot patch
→ test/debug
→ 0.4 progression patch
→ test/debug
→ 0.5 world patch
→ test/debug
→ 0.6 systemic replayability patch
→ test/debug
→ 0.7 persistence hardening
→ test/debug
→ 0.8 co-op/social expansion
→ test/debug
→ 0.9 content expansion
→ release-candidate hardening
→ 1.0
→ measured live patches
```

The game should never again require finishing a giant batch of unrelated roadmap systems before the team can meaningfully play, diagnose and improve it.