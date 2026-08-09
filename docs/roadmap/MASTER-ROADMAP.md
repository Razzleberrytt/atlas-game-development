# Atlas — Master Roadmap v2.8

**Milestone/product authority:** Atlas v2.8 complete product path  
**Active runtime execution authority:** Blueprint v2.7 Rollout & Observability  
**Date:** 2026-08-08  
**Current evidence claim:** E2 on the accepted pinned-artifact R1/replay packet

This document describes the full dependency-gated path from the current repository through a polished vertical slice, durable game, launch, and post-launch operation.

**v2.8 does not authorize agents to skip the active v2.7 rollout.** Blueprint v2.7, Production Core v2.7, the active-place rollout, and accepted runtime evidence still control current runtime execution order. Future phases exist here so the destination is explicit before they become eligible.

Read [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) before interpreting older product documents.

## Status legend

- `[ ]` planned / not started
- `[~]` active, partially complete, or preparation exists
- `[x]` complete with applicable evidence
- `[!]` blocked by an earlier gate
- `[L]` deliberately locked future phase
- `[H]` historical implementation record; useful provenance but not current execution authority

## Authority model

```text
accepted runtime evidence / current Roblox platform behavior
→ Blueprint v2.7 + Production Core v2.7 for active runtime execution
→ Current Product Authority + this Master Roadmap v2.8
→ Active Place Rollout + Cross-System Traceability + production-control artifacts
→ accepted current specifications / architecture decisions
→ specialist visual/environment/Studio bibles
→ historical charters, pivots and older roadmaps
```

A future phase being documented here is not permission to implement it early.

# Current checkpoint — 2026-08-08

Repository state at v2.8 adoption (commit `60229a32ec1f7db3b87a68e5f81ddf8115e665f1`):

- accepted evidence remains **E1**;
- the earlier R1 artifact is no longer valid as an acceptance run because a client-bootstrap stall invalidated every run against that artifact;
- R1 must be re-pinned to a recorded CI artifact at or after the client-bootstrap fix (`91a1ebe3d04b6d99495f19e7a809bc2b4135fd97`) and rerun under the evidence packet rules;
- PR #221 remains prepared/blocked single-listener consolidation work;
- PR #222 remains stacked/prepared R2 ready-gated publisher work and may not activate early;
- the original Studio import preservation gap has been repaired: all 28/28 Studio-only sources and 1,775/1,775 Workspace identity/hierarchy rows are now preserved;
- property-backed authored-world reconstruction has advanced beyond the first damaged-archive manifests;
- stable world-content contracts and canonical runtime ownership guidance exist;
- a modern Forward Operations Hub shell exists as the temporary preparation bridge;
- the recovered authored overworld is intentionally a separate future coordinate/lifecycle space from the modern operation forest;
- held source-managed reconstructions exist for major authored-overworld elements including WorldPath, DungeonPortal, and the quest board;
- a pre-launch operation-selection contract is being prepared separately; its existence does not authorize early runtime wiring.

Runtime evidence refresh after adoption:

- **R1 accepted on a new pinned CI artifact**: workflow run 31282591558, artifact ID 9028866465, source/build identity c55287fac4ecefc120c541958a6a06049b0a78cd; the fresh packet is [`../production/evidence/2026-08-08-r1-playable-replay-loop.md`](../production/evidence/2026-08-08-r1-playable-replay-loop.md);
- the capture advanced from 50 to 238 valid compatibility-state messages over 94 seconds, with zero invalid messages, zero queue/discard warnings, and zero enabled broad Highlight targets;
- the same run closed a P10-0105 acceptance defect: after a terminal result, run 2 now restores 100 health and movement, dismisses the prior debrief, accepts the new operation's revision, and advances the opening objective;
- accepted evidence advances to **E2** because the pinned artifact started and initialized cleanly; E3–E5 remain open because later reset/respawn, delayed-ready, late-join, multiplayer, streaming, and profiling matrices are not closed by a one-client R1 run.

## Refreshed since adoption — 2026-08-08

- current `main` checkpoint before PR #245: `26898b21bffd8e4b50001da2e3812e17760bab6a`;
- **BA-010 closed at E1**: the Main World/environment audit and composition specification is complete in [`../specifications/main-world-environment-audit.md`](../specifications/main-world-environment-audit.md) (merged via PR #241); see the refreshed W0 status below;
- **BA-011 closed at E1**: the Main World source representation/placement strategy is complete in [`../specifications/main-world-source-representation-strategy.md`](../specifications/main-world-source-representation-strategy.md), locked by `MainWorldRepresentationConfig` (merged via PR #242); see the refreshed W1 status below;
- **BA-012 closed at E1**: the canonical Hub interaction registry (preparation/board/vendor/NPC/crafting/gathering/portal/social anchors and owner/dependency boundaries) is complete in [`../specifications/canonical-hub-interaction-registry.md`](../specifications/canonical-hub-interaction-registry.md) (merged via PR #243); no runtime activation;
- root `CLAUDE.md` was added as a companion mechanical/architecture reference alongside this operating contract; it does not change roadmap authority or task selection;
- accepted evidence level is E2, PR #222 remains blocked behind consolidation/R2 dependencies, and the combined-world preservation counts remain unchanged; the R1 re-pin requirement is closed by the runtime-evidence refresh above;
- the Main World environment production plan is complete at E1 through BA-013; the next assigned Track 1 task is **BA-014 — Main World acceptance matrix**, per [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md).

## Current program state

| Program area | Status | Current meaning |
|---|---|---|
| Repository/tooling foundation | [x] | GitHub-first source, Rojo, validation, CI, reproducible builds and agent workflow exist. |
| Combined-game preservation | [x] | Studio source/hierarchy recovery is repaired; preserved legacy services remain inert. |
| Product authority reconciliation | [x] | Current Atlas product authority exists; older Living Kingdoms charter is explicitly historical. |
| v2.7 runtime rollout | [~] | **Primary runtime lane.** R1 and exact-build single-listener consolidation are accepted; R2 remains the next runtime dependency. |
| Controlled build-ahead | [~] | Pure contracts, data, audits, reconstruction and dormant seams may continue without activating future runtime scope. |
| Main World / environment preparation | [~] | Forward Operations Hub is live as a bridge; authored overworld reconstruction is held; full overworld lifecycle is not active. |
| E2–E4 integrated evidence | [~] | E2 Studio initialization accepted; E3/E4 integrated and multiplayer evidence remain blocked by later runtime gates. |
| Durable persistence/value | [!] | Deliberately blocked until runtime ownership/cleanup is accepted. |
| Vertical-slice activation | [!] | Preparation allowed; broad runtime integration waits for active gates. |
| Device/performance/accessibility | [!] | Requires representative integrated build and measured evidence. |
| Outside-player fun gate | [!] | Requires stable integrated loop. |
| Analytics/live telemetry | [L] | Production instrumentation and E7 promotion belong after a representative player loop exists. |
| Monetization | [L] | Locked behind outside-player fun/repeat-intent evidence. |
| Launch/live operations | [L] | Locked until release-candidate gates pass. |

# North-star product sequence

The strategic loop is:

```text
Main World arrival
→ safe orientation / discovery
→ interaction / humble starting-path choice
→ deliberate party or expedition launch
→ seeded authored route / operation / dungeon
→ mixed combat + exploration + discovery
→ build / loot / reward decisions
→ elite / boss / terminal outcome
→ return safely to Main World
→ bank eligible progress and retain durable identity
→ choose what to do next
```

The first proof remains deliberately smaller:

```text
arrive safely and prepare
→ choose a humble starting path
→ deliberately enter one readable seeded route
→ mixed combat with distinct tactical questions
→ information/discovery interaction
→ repeatable dungeon/encounter sequence
→ elite/reward decision
→ boss/result
→ return or lose unbanked run gains on death
→ choose to play again
```

Current product authority defines this as an exploration-first, hard-but-fair extraction RPG. Existing horde/director machinery may supply roaming pressure and authored encounter events, but numbered-wave/tower-defense presentation is not a target experience. The ordinary HUD is contextual; direct world interactions use native `E`/controller/touch prompts with server-owned consequences; seeded variation must remain reproducible, navigable and winnable. The humble melee-first opening, safe-home lifecycle and durable death/unlock boundary require their own scoped runtime migrations and evidence rather than compatibility shortcuts.

# A0 — Product authority reconciliation

**Status: [x] DOCUMENTATION AUTHORITY ESTABLISHED**

Purpose: prevent autonomous agents from treating historical camera/combat/world assumptions as the current strategic destination.

Complete when:

- current product authority is explicit;
- historical charter is clearly marked historical;
- runtime behavior is protected from accidental strategic-document rewrites;
- future foundational changes require an explicit decision record.

Current authority: [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md).

# R — Active-place rollout and incident closure

**Status: [~] ACTIVE RUNTIME LANE — BLUEPRINT v2.7 CONTROLS EXECUTION**

Do not duplicate Tickets 331–360 here. The controlling detail remains:

- [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md)
- [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md)
- [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md)
- [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md)

R1 acceptance is complete on the exact identity recorded in
[`../production/evidence/2026-08-08-r1-playable-replay-loop.md`](../production/evidence/2026-08-08-r1-playable-replay-loop.md).
The next dependency-safe runtime sequence is:

1. rebase and revalidate PR #221's single-listener consolidation against current `main`;
2. capture its declared listener/presentation evidence without removing the R1 rollback checkpoint;
3. keep PR #222's R2 publisher blocked until consolidation is accepted;
4. then execute R2 delayed-ready/current-state delivery evidence before R3 semantic suppression.

### R exit gate

The v2.7 closure packet must prove bounded semantic state delivery, intended listener ownership, centralized presentation ownership, cleanup stability, delayed-ready/late-join correctness, streaming rebind, reset/respawn stability, multiplayer lifecycle correctness, and retained rollback checkpoints.

# B — Controlled build-ahead preparation

**Status: [~] ACTIVE PREPARATION LANE**

Canonical queue: [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md).

Agents may continue safe preparation that does not activate gated runtime behavior.

Current useful categories include:

- world-content IDs/contracts and reconstruction data;
- held authored-overworld composition contracts;
- quest/NPC/vendor/crafting/gathering contracts;
- dungeon/portal/operation-selection contracts;
- enemy/loot/progression coverage audits;
- authored route/landmark/encounter data;
- onboarding/input/UI information architecture;
- content reference/orphan/cycle validation;
- integration planning and source audits.

Build-ahead code must remain dormant or explicitly blocked when its runtime gate has not passed.

# W — Main World and environment

**Status: [~] PREPARATION ACTIVE; FULL RUNTIME ACTIVATION BLOCKED**

The Main World is a first-class product surface, not a 3D menu or filler open world.

The accepted architectural direction is:

```text
authored overworld / HubTown
→ canonical preparation / operation selection
→ expedition / operation runtime
→ return to authored overworld
```

The modern Forward Operations Hub is the current bridge, not the final Main World.

## W0 — Current-world audit and disposition

**Status: [~] SOURCE/EVIDENCE AUDIT COMPLETE; STUDIO VISUAL REVIEW PENDING**

BA-010 records the current dispositions and composition requirements in
[`../specifications/main-world-environment-audit.md`](../specifications/main-world-environment-audit.md).
Its completion does not constitute visual, traversal, streaming, audio or performance acceptance.

Audit all current/preserved world content and classify significant elements as:

`KEEP / REFINE / REBUILD / REPLACE / REMOVE / MISSING`

Required audit coverage:

- spawn/arrival flow;
- HubTown / Forward Operations Hub;
- routes, roads, traversal times and dead travel;
- landmarks, points of interest and world boundaries;
- terrain, foliage, rocks, structures, props and repetition;
- scale consistency, silhouette and sightlines;
- environmental storytelling;
- lighting, sky, fog/haze, materials, VFX and color grading;
- ambient audio/music-zone architecture where applicable;
- collision, instance counts, script ownership, streaming and replication;
- expansion seams for quests, NPCs, vendors, crafting, gathering, dungeons and social systems.

Studio visual review is required for composition/atmosphere claims.

## W1 — Main World spatial plan

**Status: [~] SOURCE/PLACEMENT STRATEGY COMPLETE; FINAL ACTIVATION BLOCKED**

BA-011 defines the dedicated place/project boundary, source/model/Terrain ownership,
streaming groups, and arrival/return anchor policy in
[`../specifications/main-world-source-representation-strategy.md`](../specifications/main-world-source-representation-strategy.md),
locked by `MainWorldRepresentationConfig`. Its completion does not activate the Main
World, create a Roblox place, reconstruct Terrain, or change the current operation
runtime. BA-012 has since completed the canonical Hub interaction registry, and
BA-013 defines the held environment kits, quality tiers, production ceilings,
Terrain workflow and streaming/performance targets in
[`../specifications/main-world-environment-production-plan.md`](../specifications/main-world-environment-production-plan.md).
The next dependency-safe Main World task is BA-014 — acceptance matrix.

Define a readable loop:

```text
Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return
```

Lock:

- primary spawn and re-entry points;
- landmark hierarchy;
- district/service placement;
- road/trail/navigation language;
- portal/expedition entrance locations;
- social/rest/preparation spaces;
- discovery/secret opportunities;
- future expansion seams;
- intended traversal-time bands.

## W2 — Environment production

**Status: [~] PRODUCTION PLAN COMPLETE; BROAD PRODUCTION/ACTIVATION HELD**

BA-013 defines the evidence-bounded production units, ownership boundaries,
provisional asset/scene budgets, quality tiers, Terrain manifest workflow,
semantic streaming rules and BA-014 performance targets in
[`../specifications/main-world-environment-production-plan.md`](../specifications/main-world-environment-production-plan.md).
These are E1 planning ceilings, not accepted Studio/device evidence and not
permission to activate the Main World. Playable MVP + Patch Execution v2.9
keeps broad environment production in Patch 0.5; Gate 0/MVP 0.1 may use only a
separately authorized minimal preparation/return surface and do not wait for
the final Main World.

Production scope includes:

- terrain and biome language;
- vegetation/rock/prop kits;
- structures/ruins/interiors;
- water/environmental surfaces;
- lighting/sky/atmosphere/fog;
- environmental VFX/particles;
- ambient audio/music regions;
- environmental storytelling;
- controlled repetition and LOD/streaming strategy.

Do not add broad geometry simply because it is possible; each pass requires gameplay-camera review.

## W3 — Main World gameplay integration

**Status: [L]**

Integrate only through canonical owners:

- NPCs / dialogue;
- quests / operation board;
- vendors/economy;
- crafting/gathering;
- inventory/loadout preparation;
- progression/world access;
- dungeon/expedition entry;
- social/party preparation;
- onboarding;
- discoveries/secrets.

## W4 — World technical acceptance

**Status: [L]**

Measure:

- StreamingEnabled behavior;
- client/server instance cost;
- memory;
- collision/query burden;
- draw/render cost;
- mobile/low-graphics readability;
- network replication;
- spawn/return reliability;
- portal/transition reliability.

## W5 — Main World acceptance gate

**Status: [L]**

A fresh player should be able to spawn, orient, find major services, understand how to start an adventure, recognize major landmarks, explore without hopeless confusion, and understand what to do after returning.

# S — Party, social and matchmaking/session infrastructure

**Status: [L]**

Do not invent this inside unrelated expedition tasks.

Plan dedicated contracts for:

- party creation/invites/friend join;
- membership and readiness;
- leader/host policy if the product actually needs one;
- expedition selection authority;
- public/private session policy;
- matchmaking rules where justified;
- reserved server/teleport lifecycle where appropriate;
- disconnect/reconnect and late-join policy;
- AFK and abandoned-party handling;
- deterministic return-to-hub behavior;
- abuse/security boundaries.

Existing lobby membership/readiness remains an asset; new topology must extend rather than duplicate it.

# E — Evidence promotion

**Status: [~] E2 ACCEPTED; E3–E4 BLOCKED BY LATER RUNTIME GATES**

## E2 — Studio initialization

Accept only when a repository-synchronized build starts cleanly enough for the intended systems to initialize and diagnostics to be trustworthy.

**Accepted 2026-08-08** on pinned artifact 9028866465. See
[`../production/evidence/2026-08-08-r1-playable-replay-loop.md`](../production/evidence/2026-08-08-r1-playable-replay-loop.md).

## E3 — Single-player integrated behavior

Accept only when the intended prepare/adventure/result/return loop can repeat without state, presentation, cleanup, reward or compatibility regressions.

## E4 — Multiplayer/adversarial behavior

Accept only after ownership, attribution, reset, disconnect, delayed readiness, replay/retry, audience isolation and adversarial client inputs behave correctly.

## E5 — Device/performance/reliability

Owned by Phase Q acceptance.

## E6 — Outside-player fun

Owned by Phase F acceptance.

## E7 — Live telemetry

Owned by Phase T after production telemetry exists.

# D — Durable persistence and valuable state

**Status: [!] BLOCKED UNTIL R + E3/E4**

Reuse the strong historical P11/durable-value work rather than reinventing it.

Required sequence:

1. persistence adapter boundary;
2. session ownership/lease rules;
3. versioned/sequential migrations;
4. no-blank-overwrite protection;
5. unknown-write reconciliation;
6. inventory/reward overflow recovery;
7. deterministic/idempotent transaction replay;
8. XP/rank/unlock commit boundaries;
9. leave/rejoin/shutdown/failure testing;
10. observability and degraded-mode behavior.

Do not persist a state model still leaking, duplicating, or changing ownership semantics in memory.

# M — Long-term progression

**Status: [L]**

Historical P11 and the RPG integration plan contain reusable groundwork.

Define the final durable layer for:

- account/career XP and ranks;
- class/side-grade unlocks;
- skill/progression mapping;
- weapon/starting-option unlocks where justified;
- world/dungeon access;
- quest/discovery/codex progress;
- achievements/challenges;
- cosmetics/expression;
- respec/reset policy;
- catch-up/new-player policy.

Permanent power must remain bounded enough that knowledge, execution, cooperation and run-build choices continue to matter.

# ECON — Economy, crafting and resource value

**Status: [L]**

Before vendor/crafting/gathering activation, define one coherent economy using canonical inventory/persistence/currency owners.

Required design:

- currencies and ownership;
- sources and sinks;
- vendor price/value bands;
- crafting costs and recipe tiers;
- resource rarity and gathering cadence;
- duplicate-item handling;
- salvage/dismantle policy;
- inventory overflow/recovery;
- transaction IDs/idempotency;
- exploit/duplication resistance;
- economy telemetry;
- inflation/value review.

# C — Content production pipeline

**Status: [~] PREPARATION AUTHORIZED**

Turn content expansion into validated data authoring rather than repeated bespoke code.

Target data-driven authoring for:

- quests and objective chains;
- NPC definitions/dialogue references;
- vendors/catalogs;
- recipes/resources/gathering nodes;
- items/affixes/reward tables;
- routes/landmarks/discoveries/secrets;
- encounter beats/enemy compositions;
- dungeons/room sequences;
- elites/boss slots;
- events/challenge modifiers.

Required validators should catch:

- duplicate IDs;
- orphan references;
- dependency cycles;
- impossible prerequisites;
- inaccessible destinations;
- invalid reward/item references;
- incompatible affixes;
- invalid economy references;
- content that bypasses canonical owners.

A content pipeline is successful when new content mostly requires authored data plus bounded presentation, not another service.

# V — First complete vertical slice

**Status: [!] RUNTIME ACTIVATION BLOCKED; PREPARATION AUTHORIZED**

Promote prepared work into the smallest complete replayable RPG expedition.

Dependency order:

1. preparation/loadout start;
2. Main World/Forward Hub preparation surface and operation entry;
3. authored outdoor route and landmarks;
4. mixed-combat sequence;
5. optional discovery/secret interaction;
6. repeatable dungeon/room sequence;
7. elite + meaningful item/build decision;
8. boss/terminal outcome;
9. result/reward commit;
10. return/replay invitation.

Exit only when the loop is coherent enough to evaluate as a game, not merely as connected systems.

# Q — Quality, balance, device, performance, accessibility and reliability

**Status: [!] REQUIRES REPRESENTATIVE INTEGRATED BUILD**

Re-adopt the strongest historical P12 gates into current authority.

Required work includes:

- end-to-end telemetry baselines for 1/2/3/4 players;
- solo-to-four-player pressure scaling;
- class-composition resilience;
- scarcity/relocation/pacing tuning;
- horde/enemy/boss/visibility/UI profiling;
- desktop/mobile/controller action coverage;
- StreamingEnabled behavior;
- memory/instance/presentation cleanup;
- low-graphics readability;
- reduced-motion behavior;
- safe-area and input coverage;
- accessibility using redundant text/shape/position/timing cues;
- removal of fixed-four-player assumptions;
- full security/regression audit;
- repeated release-candidate playthroughs.

Measured evidence beats intuition.

# F — Outside-player fun and repeat-intent gate

**Status: [!] REQUIRES STABLE INTEGRATED LOOP**

Fresh players should be able to explain:

- what their goal was;
- why they took damage or failed;
- what enemy/encounter pressures asked them to do;
- what their build/reward choice changed;
- what they wanted to do next.

Track observed confusion, completion, abandonment and voluntary replay. The strongest signal is choosing to play again.

**Monetization and broad content expansion remain locked until this gate produces a credible positive signal.**

# T — Production telemetry and E7

**Status: [L]**

After a representative loop exists, define production-safe analytics for decisions such as:

- onboarding completion;
- Main World → expedition conversion;
- party size/session start;
- expedition starts/completions;
- abandonment points;
- failure/result causes;
- objective timing;
- deaths/incapacitations/revives;
- class/build/upgrade/relic choices;
- loot/reward choices;
- boss phase/completion;
- return/replay rate;
- session length;
- retention cohorts;
- performance/error/reliability signals.

Telemetry must be bounded, privacy/policy appropriate, versioned enough for analysis, and must not become gameplay authority.

E7 requires actual live telemetry, not a logging API existing in source.

# OPS — Runtime configuration, staged rollout and rollback operations

**Status: [L]**

Build only when a production need exists.

Plan:

- feature flags with explicit owners/removal gates;
- balance/config values separable from code where safe;
- emergency disable switches for high-risk optional systems;
- development/staging/production configuration policy;
- staged rollout/rollback procedure;
- migration compatibility windows;
- incident runbooks;
- build/place identity tracking.

Do not turn every value into remote configuration; keep security-critical rules authoritative and reviewable.

# SAFE — Platform safety, security and compliance

**Status: [L] WITH BASELINE SECURITY ALREADY ACTIVE**

The repository's server-authority/security rules remain mandatory now. Before public launch, add a formal release gate for:

- Roblox policy/content-maturity review;
- text filtering where player/user text exists;
- social/chat/UGC policy review;
- PolicyService-dependent behavior where applicable;
- violence/readability/content review;
- exploit/security audit;
- asset/audio/source-rights audit;
- privacy/data-handling review;
- purchase/entitlement policy review;
- moderation-safe fallbacks.

# LOC — Localization readiness

**Status: [L]**

Before broad launch:

- externalize player-facing strings where practical;
- define stable localization keys/context;
- cover UI, quests, NPC dialogue, item descriptions and metadata;
- test text expansion and mobile layout;
- define language fallback behavior;
- localize discovery/store metadata when appropriate.

Localization readiness should be architectural before translation becomes a content-scale problem.

# MON — Ethical monetization

**Status: [L] LOCKED BEHIND F**

Do not implement a broad monetization catalog before the game proves fun/repeat intent.

Future eligible directions may include:

- cosmetics;
- visual/presentation expression;
- optional non-dominating convenience only if it does not undermine progression or match difficulty;
- cosmetic bundles/passes/products where appropriate.

Never sell raw best-in-slot power, mandatory progression, paid recovery from failure, required match resources, or exclusive dominant classes/equipment.

Any purchase system requires receipt/idempotency, entitlement reconciliation, failure recovery, policy review and analytics.

# L — Launch pipeline

**Status: [L]**

The release path should be explicit:

```text
internal alpha
→ limited outside playtest
→ closed/controlled beta
→ soft launch / limited production exposure
→ release candidate
→ public production launch
```

Required launch work includes:

- release-blocker severity rules;
- build/place rollback checkpoint;
- smoke/regression matrix;
- icon/thumbnail/video/description/store metadata;
- audience/device settings;
- content maturity/policy checks;
- localization readiness;
- telemetry dashboards/alerts;
- hotfix procedure;
- known-limitations record;
- launch-day monitoring and rollback owner.

# LIVE — Post-launch operations and expansion

**Status: [L]**

After launch, expand from evidence rather than roadmap vanity metrics.

Potential work includes:

- balance/hotfix cadence;
- bug and exploit response;
- onboarding/readability improvements;
- new items/build choices;
- new quests/discoveries;
- new enemies/elites/bosses;
- new dungeons/expeditions;
- additional Main World areas;
- additional classes/sidegrades;
- challenge modes/events;
- retention/replay experiments;
- later seasonal structures only when the player base and content pipeline justify them.

Every expansion should reuse canonical owners and the content pipeline rather than creating a parallel game inside the game.

# Scope protection

Until Phase F is accepted, do not broadly activate:

- multiple huge regions/continents;
- PvP;
- raids;
- housing;
- unrestricted player trading/auction house;
- vehicles/mounts;
- dozens of classes;
- hundreds of items for item-count's sake;
- broad monetization catalogs;
- speculative backend complexity;
- seasonal/battle-pass systems solely to manufacture retention.

# Global stop conditions

Stop and fix when:

- remote queue/discard warnings occur in supported normal play;
- state rate/connections/presentation objects grow across reset without gameplay reason;
- client input can author damage, rewards, inventory, progression, economy or ownership;
- two runtime owners compete for the same gameplay/presentation truth;
- late join/delayed readiness loses current facts;
- stream-out is interpreted as gameplay completion;
- animation/viewmodel/camera listeners multiply across lifecycle transitions;
- broad Highlights or presentation obscure gameplay;
- low-graphics/mobile removes critical information;
- valuable persistence can blank, duplicate or replay incorrectly;
- build-ahead work activates before its gate;
- a recovered legacy gameplay service is resurrected beside its canonical replacement;
- Main World/world additions cannot explain their gameplay purpose or fail performance/readability review;
- content data contains unresolved IDs/cycles/impossible dependencies;
- monetization weakens the game's intended difficulty/progression contract;
- an evidence claim cannot point to a reproducible packet/build/place identity.

# Execution rule for agents

1. Read the Current Product Authority and this roadmap for destination/context.
2. For runtime work, obey Blueprint v2.7 and Production Core v2.7 first until the rollout closes.
3. In build-ahead mode, select only a READY task authorized by the build-ahead queue.
4. Do not choose a locked future phase merely because it appears valuable.
5. Prefer the lowest dependency-safe task that unlocks more work without bypassing evidence.
6. Update status only when the applicable Definition of Done and evidence level are satisfied.
7. Preserve current runtime behavior unless the task explicitly authorizes a migration.

# Next highest-ROI work at this checkpoint

Two lanes remain valid:

### Human/Studio runtime lane

**Rebase/revalidate the prepared PR #221 single-listener consolidation and capture its declared listener/presentation evidence.** R1 is now accepted; consolidation is the next dependency before the R2 ready-gated publisher may activate.

### Agent build-ahead lane

Continue the first READY dependency-safe task in [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md), favoring work that strengthens world-content contracts, Main World composition/audit, operation-selection seams, content validation, or vertical-slice content without booting gated runtime systems.

> Complete map, disciplined execution: describe the whole destination now, but build only the next dependency-safe slice.
