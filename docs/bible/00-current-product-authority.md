# Atlas — Current Product Authority

**Status:** CURRENT PRODUCT AUTHORITY  
**Adopted:** 2026-08-08  
**Refreshed:** 2026-08-16  
**Scope:** product identity, design priorities, roadmap interpretation, and product-level conflict resolution.  
**Current execution:** [`../roadmap/EXECUTION-DASHBOARD.md`](../roadmap/EXECUTION-DASHBOARD.md).

This document defines **what Atlas is trying to become**. It does not maintain the daily task queue and does not grant permission to bypass runtime/security/persistence evidence requirements.

Historical Living Kingdoms documents remain valuable provenance, but old camera, combat, genre, branch, or phase assumptions do not silently override current Atlas direction.

## Product identity

Atlas is a **cooperative action RPG on Roblox** built around:

- readable, skillful cooperative combat;
- run-based build and loot decisions;
- durable progression and world access without mandatory runaway power inflation;
- a recognizable safe Main World players return to;
- authored plus replayable expeditions, routes, dungeons, encounters, elites, and bosses;
- discovery, landmarks, secrets, quests, NPCs, vendors, gathering, and crafting where they make the core loop better;
- strong solo-to-co-op support;
- server-authoritative valuable game truth;
- reproducible, bounded procedural/systemic variation;
- data-driven content architecture that can scale without parallel gameplay authorities.

The existing Living Kingdoms runtime is an implementation asset, not disposable prototype code. Working combat, camera, mission, enemy, progression, loot, persistence, world, and presentation systems are preserved unless a focused decision deliberately replaces them.

**Do not infer a camera or combat rewrite from product strategy alone.** Canonical source and accepted specifications decide the current implementation until an explicit migration changes it.

## North-star player promise

A session should repeatedly create this feeling:

> **I know where I am, I understand what is threatening us, my choices change the run, my teammates matter, the world makes me curious, and I want one more expedition.**

When priorities conflict, favor features that strengthen that promise over breadth for its own sake.

## Core player-facing rhythm

```text
safe arrival / home
→ orient and prepare
→ choose a humble starting path / build
→ form or enter an expedition context
→ explore a readable route
→ face roaming pressure + authored encounters
→ discover / collect / choose meaningful rewards
→ decide whether to push deeper
→ defeat an elite and terminal/boss encounter
→ receive a clear outcome
→ return safely
→ bank/equip/unlock/learn
→ choose what to do next
```

A run should create tension and decisions without becoming opaque, unfair, or dependent on developer explanation.

## Product pillars

### 1. Readable intensity

Combat may be intense, but threats, telegraphs, damage, failure, objectives, and recovery should be understandable.

Difficulty should come from:

- positioning;
- timing;
- target priority;
- movement;
- enemy combinations;
- resource pressure;
- build choices;
- exploration risk;
- cooperation;
- knowledge/mastery.

Avoid opaque one-shots, unreadable clutter, unwinnable generation, and health inflation as substitutes for difficulty.

### 2. Curiosity and discovery

The game should reward looking around rather than only following HUD markers.

Use:

- landmarks;
- optional routes;
- caches/secrets;
- environmental storytelling;
- discoveries/codex facts;
- dynamic events;
- meaningful biome/region identity;
- rewards that create tension between safety and exploration.

### 3. Builds change decisions

Loot, relics, classes, equipment, affixes, abilities, and progression should alter tactics—not only produce larger numbers.

Run-to-run variation should create moments like:

- “this weapon changes how I approach the next room”;
- “this relic makes a risky synergy worth trying”;
- “this class lets me solve a team problem differently”;
- “this route/resource discovery changes what we do next.”

### 4. Durable identity without compulsory power creep

Long-term progression can include:

- XP/ranks;
- classes/archetypes/side-grades;
- loadouts;
- bounded stat/talent choices;
- discoveries/codex/achievements;
- world/dungeon access;
- starting options;
- cosmetics/expression;
- challenge modifiers.

Permanent power must not erase the value of execution, knowledge, cooperation, or expedition difficulty.

### 5. A real home, not a menu and not an empty MMO map

The Main World exists to make return, preparation, discovery, and future expansion feel physical and memorable.

It should support:

- arrival/orientation;
- preparation/loadouts;
- NPC/quest surfaces;
- vendors/economy when useful;
- crafting/gathering when useful;
- social/party preparation;
- expedition/dungeon entrances;
- world-access/progression feedback;
- exploration/landmarks/secrets;
- clean return/replay flow.

Accepted architectural direction:

```text
authored overworld / HubTown
→ canonical expedition launch
→ modern operation runtime
→ return
```

Recovered Studio content is preservation/migration/presentation input. Do not reactivate legacy gameplay services merely to obtain world art or authored content.

### 6. Co-op that creates interdependence without punishing solo play

Co-op should make players feel more capable together because roles/builds/positioning/support complement one another.

Support:

- solo viability where practical;
- 1–4 player core sessions initially;
- party formation/invites/friend joins;
- readiness/launch clarity;
- revive/support mechanics;
- scaling that preserves tactical identity;
- reconnect/late-join rules;
- run/session ownership and cleanup;
- low-friction communication/presence.

Do not require social complexity that adds friction without improving cooperative play.

### 7. Procedural variation with authored quality

Randomness should multiply replayability while remaining reproducible, readable, navigable, and winnable.

Server-owned seeds may influence:

- dungeon/route layout;
- encounters/events;
- enemy variants/modifiers;
- loot/rewards;
- environmental variation;
- discoveries;
- resource distribution;
- selected world-state systems.

Stable truths should not randomly drift without reason: core controls, combat rules, reward validation, story facts, and canonical durable ownership remain dependable.

## Combat identity

Atlas is an action RPG, not a stationary wave-defense game.

Existing horde/director systems may create pressure internally, but player-facing pacing should read as:

- roaming danger;
- pursuit/ambush;
- authored encounter pressure;
- elite events;
- terminal/boss confrontations;
- traversal risk;
- decisions about when to push, regroup, retreat, or extract/finish.

Numbered-wave presentation should not dominate the experience unless a specific mode intentionally calls for it.

The exact camera/aiming/attack implementation remains an architecture/runtime decision. Product authority requires only that the result is readable, responsive, skillful, and compatible with current controls/platform constraints.

## Opening power curve

The preferred opening arc is **humble → discovery → capability** rather than spawning with every strong option.

A melee-capable or otherwise modest starting path can make recovered firearms/gear feel earned. Implementation must remain mechanically truthful: do not disguise one combat contract as another to fake the fantasy.

## Loot and run stakes

Loot should create decisions about what to use, keep, bank, dismantle, or risk.

A run may contain temporary power/value that disappears on failure or replay. Durable identity/value is preserved only through canonical persistence owners.

Preferred failure philosophy:

- failure ends or meaningfully resets the active expedition;
- unbanked run loot/temporary power may be lost;
- safely banked state, achievements, discoveries, codex progress, unlocked options, and other explicitly durable identity survive according to their canonical rules;
- failure should teach rather than feel arbitrary.

## Progression philosophy

Long-term progression should primarily create:

- more choices;
- clearer identity;
- mastery paths;
- new starting options;
- access to new content;
- build variety;
- expression;
- reasons to return.

Avoid a design where account age alone trivializes the game.

## Economy, gathering, crafting

These are **support systems**, not mandatory checkboxes.

Gathering/crafting/economy should ship only when resources and outputs create meaningful decisions in the core loop.

Do not add tree cutting, ore nodes, recipes, currencies, vendors, or profession grinds merely because RPGs often have them.

## Housing / guild / large-social systems

Player housing, guild halls, complex trading, and large social structures are conditional future systems. They are not current product promises unless evidence/player demand makes them worthwhile and the roadmap/dashboard explicitly activates them.

Their presence in the 300-area development taxonomy means “remember this concern exists,” not “must ship.”

## Monetization principles

Monetization is downstream of product readiness.

Do not sell:

- raw best-in-slot combat power;
- exclusive mandatory classes/equipment;
- recovery from intentionally designed failure pressure;
- client-trusted valuable outcomes;
- manipulative friction created solely to sell relief.

Future monetization may include fair cosmetics/expression/convenience only when:

- the core game is worth playing without payment;
- purchases are server-validated and platform-compliant;
- the value proposition is clear;
- the design does not damage player trust or competitive/co-op integrity.

## UX principles

- Keep the ordinary HUD contextual and decision-focused.
- Critical interactions must work across keyboard/controller/touch through canonical input/prompt systems.
- Present useful recovery/error states instead of silently failing.
- Avoid duplicate inventory/status panels and debug-like telemetry on the normal play surface.
- Accessibility is part of product quality, not final-day polish.

## World / content principles

- Every region/biome/route should have identity and a gameplay reason to exist.
- Landmarks should help navigation, not only decoration.
- Content density should follow travel time and decision value.
- Procedural generation must respect traversal support, readability, encounter space, and performance.
- Main World routes should avoid unnecessary single points of failure when measured alternatives are affordable.
- NPCs/quests/vendors/factions should have clear gameplay roles rather than populate the world with hollow interactions.

## Technical/product contract

Product ambition never overrides these engineering laws:

- server owns valuable game truth;
- no duplicate authority;
- stable IDs/references/contracts;
- deterministic/reproducible systems where appropriate;
- bounded lifecycle/network waits and failure paths;
- durable mutations are replay/duplication safe;
- content growth uses canonical registries/seams when mature;
- source claims and Studio/player evidence remain distinct;
- performance/mobile/controller constraints are first-class Roblox realities.

## Explicit non-goals unless later activated

Atlas is not currently defined by:

- PvP competition;
- large-scale MMO simulation;
- giant empty open-world acreage;
- army-command RTS control;
- stationary endless wave defense as the primary mode;
- mandatory player housing;
- deep trading economy;
- paid power;
- daily-chore retention loops;
- procedural randomness that compromises readability/winnability.

A later evidence-backed product decision may change one of these, but old historical documents cannot do so implicitly.

## Production rule

> **Build the smallest coherent playable result, keep valuable truth authoritative, measure what source cannot prove, and improve Atlas through evidence-driven layers rather than speculative breadth.**

## Roadmap relationship

- [`../roadmap/EXECUTION-DASHBOARD.md`](../roadmap/EXECUTION-DASHBOARD.md) — what happens now.
- [`../roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`](../roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md) — player-facing patch intent.
- [`../roadmap/MASTER-ROADMAP.md`](../roadmap/MASTER-ROADMAP.md) — long-range destination/dependencies.
- [`../architecture/DEVELOPMENT_TAXONOMY.md`](../architecture/DEVELOPMENT_TAXONOMY.md) — comprehensive concern inventory.
- [`../architecture/DEVELOPMENT-ATLAS.md`](../architecture/DEVELOPMENT-ATLAS.md) — concern-to-engine/owner routing.

## Conflict resolution

When product documents disagree:

1. current accepted runtime facts beat prose about implementation reality;
2. this document controls current product identity/design direction;
3. the dashboard controls NOW/NEXT execution;
4. current governance controls work eligibility/WIP/merge rules;
5. current patch/master documents control product layering and scope;
6. specialist architecture/specifications control their accepted technical boundary;
7. historical documents remain provenance only.

If a real product change is desired, make it explicit here/through a decision record and update dependent roadmap/coverage documents coherently. Do not let an old file silently pivot the game.

> **Atlas should feel intense, curious, replayable, cooperative, and trustworthy—not merely large.**
