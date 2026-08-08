# Atlas — Current Product Authority

**Status:** CURRENT PRODUCT AUTHORITY  
**Adopted:** 2026-08-08  
**Scope:** Product direction, roadmap interpretation, and conflict resolution.  
**Runtime execution authority:** Blueprint v2.7 remains controlling for the active rollout until its gates close.  
**Implementation sequencing authority:** [`../roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`](../roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md) controls which player-facing slice is built next once work is dependency-safe.

This document exists because the repository contains valuable Living Kingdoms history whose product assumptions no longer describe the entire Atlas destination. Historical documents remain useful provenance, but agents must not let an older camera, combat, world, or genre statement silently override the current Atlas roadmap.

## Product identity

Atlas is a **cooperative action RPG on Roblox** built around:

- readable, skillful cooperative combat;
- run-based build and loot decisions;
- persistent progression and world access without mandatory power inflation;
- a recognizable safe overworld / Main World that players return to;
- authored and replayable expeditions, dungeons, encounters, elites, and bosses;
- discovery, landmarks, secrets, quests, NPCs, vendors, gathering, and crafting where they improve the core loop;
- strong solo-to-co-op support, with multiplayer systems designed around server authority and resilient lifecycle ownership;
- a data-driven content architecture that can expand without creating parallel gameplay authorities.

The current Living Kingdoms runtime is an important implementation asset, not a disposable prototype. Existing tactical/isometric camera behavior, automatic-combat systems, survival pressure, classes, objectives, RPG run-build systems, persistence boundaries, and authored-operation work must be preserved unless a focused future decision explicitly replaces them.

**Do not infer a camera or combat rewrite from this strategic authority document.** Camera mode, aiming model, and combat presentation remain whatever the canonical runtime and accepted specifications currently implement until an explicit architecture/design decision changes them with migration and evidence.

## Primary production rule

> Build the smallest complete playable loop, prove it, then improve Atlas through coherent upgrade patches while preserving the playable baseline.

The required development rhythm is:

```text
stabilize
→ playable MVP
→ play / debug / fix
→ one coherent upgrade patch
→ replay / regression test
→ next patch
```

The roadmap may describe the full destination now. Description does not authorize early implementation, and a later broad phase may not leapfrog the current playable patch merely because its specification is complete.

## Player-facing macro loop

```text
arrive in the Main World
→ orient and discover what is available
→ interact / prepare / choose loadout or build
→ form or join an expedition context
→ enter an authored route, mission, dungeon, or operation
→ fight, explore, discover, and make build/reward decisions
→ defeat an elite/boss or reach a terminal outcome
→ return safely to the Main World
→ apply durable progress/unlocks where allowed
→ choose what to do next
```

The shorter expedition loop remains:

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

## Main World / overworld role

The Main World is not a decorative menu and must not become a giant empty open world.

Its job is to provide a memorable, readable, expandable home for:

- arrival and orientation;
- loadout and character preparation;
- NPCs and quest surfaces;
- vendors/economy surfaces;
- crafting and gathering integration where justified;
- social/party preparation;
- dungeon/expedition entrances;
- progression/world-access feedback;
- exploration, landmarks, secrets, and environmental storytelling;
- clean return/replay flow.

The accepted architectural direction is:

**authored overworld / HubTown → canonical expedition launch → modern operation runtime → return**

The recovered authored overworld and the modern operation forest are separate coordinate/lifecycle spaces. Do not squeeze one into the other or reactivate legacy gameplay services to obtain presentation content.

## RPG depth

Atlas should feel meaningfully RPG-like without requiring a permanent gear treadmill.

### Run-based depth

Run/operation power may include:

- build-defining upgrade choices;
- relics or bounded equipment decisions;
- weapon/class synergies;
- elite modifiers;
- temporary resources;
- reward choices that alter how the current run is played.

These systems should create different tactical decisions, not merely larger numbers.

### Durable progression

Long-term systems may include:

- XP/ranks;
- class or side-grade unlocks;
- skill/progression mapping;
- world and dungeon access;
- quests/discoveries/codex progress;
- cosmetics and expression;
- challenge modifiers and additional starting options.

Durable progression must not erase the value of knowledge, execution, cooperation, or expedition difficulty. Any permanent combat power must remain bounded and explicitly justified.

## World and content expansion philosophy

Prefer reusable engines and validated content contracts over one-off content piles.

New quests, NPCs, vendors, crafting recipes, resources, routes, encounters, dungeons, items, affixes, bosses, landmarks, secrets, and events should be representable as data/configuration wherever practical and validated for orphan references, duplicate IDs, cycles, impossible prerequisites, and invalid rewards.

Procedural/random systems should increase replayability while preserving authored readability. Randomness must not make objectives, navigation, difficulty, or rewards incomprehensible.

## Cooperative and social direction

Atlas is cooperative first. Future party/session infrastructure should eventually support:

- party formation and invitations;
- friend joins;
- readiness and expedition selection;
- public/private session policy;
- matchmaking where justified;
- reserved-server/teleport lifecycle where appropriate;
- disconnect/reconnect rules;
- late-join policy;
- deterministic return-to-hub behavior.

Do not invent party-leader or matchmaking authority inside unrelated tasks. Those models require dedicated contracts and evidence.

## Economy and crafting direction

Quests, vendors, gathering, crafting, and item progression may exist, but they must share canonical inventory/persistence/currency owners.

Before broad activation, the roadmap must define:

- currencies and ownership;
- sources and sinks;
- pricing and value bands;
- recipe/resource rarity;
- duplicate/salvage/overflow behavior;
- transaction idempotency;
- exploit resistance;
- telemetry and inflation/balance review.

Do not activate isolated vendor/crafting/gathering systems that create an incoherent economy.

## Visual and environment quality bar

The game should not ship with a generic Roblox-template world or a sophisticated backend attached to placeholder geography.

Main World and expedition environments should prioritize:

- recognizable landmarks;
- readable navigation and sightlines;
- deliberate traversal time;
- terrain and prop composition with controlled repetition;
- environmental storytelling;
- coherent materials, lighting, atmosphere, VFX, and audio;
- strong silhouette and gameplay readability;
- StreamingEnabled compatibility and measured performance;
- modular expansion seams.

Visual approval requires Studio/camera evidence. Source shape alone cannot prove atmosphere, composition, scale, or readability.

## Monetization guardrails

Monetization is locked behind the outside-player fun/repeat-intent gate.

Never sell:

- raw best-in-slot combat power;
- exclusive mandatory classes/equipment;
- paid recovery from failure;
- required match resources;
- progression shortcuts that undermine the designed progression experience.

Future monetization should favor cosmetics, presentation, expression, and other non-dominating value. Exact products and pricing require a dedicated post-fun-gate roadmap phase.

## Release philosophy

A release candidate is not the end of the roadmap. The product path includes:

- runtime stability and security;
- integrated vertical slice;
- durable persistence;
- world/environment acceptance;
- performance/accessibility/device validation;
- outside-player playtests;
- production telemetry;
- policy/compliance and localization readiness;
- soft launch / staged release;
- rollback/hotfix operations;
- post-launch balance and content expansion driven by evidence.

The implementation path to that release is governed by the playable patch sequence rather than by completing every long-range phase in isolation.

## Explicit non-goals before the core loop is proven

Do not prematurely build:

- multiple huge regions/continents;
- PvP;
- raids;
- housing;
- unrestricted player trading/auction house;
- vehicles/mounts;
- dozens of classes;
- hundreds of items for item-count's sake;
- broad monetization catalogs;
- speculative backend systems unsupported by a demonstrated player need;
- seasonal/battle-pass structures solely to manufacture retention.

These may be revisited only through later roadmap decisions after the core game earns expansion.

## Authority and precedence

When product documents conflict, use this order:

```text
accepted runtime evidence / current Roblox platform behavior
→ active runtime execution authority (currently Blueprint v2.7 + Production Core v2.7)
→ PLAYABLE-MVP-PATCH-EXECUTION.md for implementation sequencing
→ this Current Product Authority + MASTER-ROADMAP.md for product direction and complete scope
→ active rollout / cross-system / production-control documents
→ accepted current specifications and architecture decisions
→ specialist visual/environment/Studio bibles
→ historical project charters, pivots, and older roadmaps
```

`MASTER-ROADMAP.md` remains the complete product-path and requirements inventory. When its phase ordering can be satisfied in more than one safe way, the playable patch document controls the chosen implementation order.

Historical documents may still contain intentionally preserved principles. They do not regain authority merely because a current implementation originated there.

## Change rule

If a future decision materially changes product identity—camera model, combat model, overworld structure, progression philosophy, multiplayer topology, monetization guardrails, or another foundational assumption—record it as an explicit decision and update this authority document, the playable patch execution document, and the master roadmap together.