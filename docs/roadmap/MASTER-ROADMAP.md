# Atlas — Master Roadmap v3.0

**Status:** CURRENT LONG-RANGE PRODUCT SCOPE  
**Refreshed:** 2026-08-16  
**Purpose:** describe the complete destination and dependency shape without maintaining a second daily execution queue.  
**Current execution:** [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md).  
**Player-facing patch layering:** [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md).

## Product destination

Atlas is a **cooperative action RPG on Roblox** built around:

- readable, skillful cooperative combat;
- run-based build/loot decisions;
- durable identity and progression without mandatory runaway power inflation;
- a recognizable safe Main World players return to;
- replayable expeditions, dungeons, encounters, elites, and bosses;
- discovery, landmarks, secrets, quests, NPCs, vendors, gathering/crafting where they improve the loop;
- server-authoritative valuable game truth;
- reproducible and diagnosable procedural/systemic variation;
- data-driven content growth through stable owners/registries;
- strong solo-to-co-op support;
- evidence-driven live operation.

Product-direction conflicts are resolved by [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md).

## What this document owns

This roadmap owns **long-range scope and dependency intent**.

It does **not** own:

- today's task — the dashboard does;
- whether unrelated work may proceed — Parallel Development Policy does;
- automated-vs-manual cadence — Automated-First / Build-Through policies do;
- runtime facts — source + accepted evidence do;
- exhaustive concern identities — the `LK-001`–`LK-300` development taxonomy does.

Historical versioned checkpoints, old PR numbers, and old evidence-gate queues are intentionally not duplicated here.

## Authority relationship

```text
accepted runtime evidence / current Roblox platform behavior
→ canonical source + repository configuration
→ Current Product Authority
→ Parallel Development Policy
→ Execution Dashboard
→ Automated-First / Build-Through policies
→ Playable Patch Scope
→ this Master Roadmap
→ specialist architecture/specifications/production guidance
→ Development Taxonomy/Atlas/coverage report for cross-system accounting
→ historical provenance
```

## Core architecture laws

1. **One authority per valuable truth.** Combat, health, enemy state, mission state, loot, inventory, progression, persistence, economy, and ownership remain server-authoritative.
2. **No parallel gameplay architecture.** New features extend canonical owners or explicit stable seams before new services are considered.
3. **Repository-first.** `games/living-kingdoms/src` is canonical runtime source; Rojo project mappings define DataModel placement; tests and validators are first-class production assets.
4. **Stable identity.** Prefer validated IDs/references/configuration over hidden object coupling.
5. **Deterministic where useful.** Seeded/generated systems must be reproducible and bounded.
6. **Playability before breadth.** Preserve a complete playable baseline while adding coherent layers.
7. **Evidence honesty.** Source/static facts never pretend to prove Studio/device/player experience.
8. **Durable-value safety.** Valuable mutations are lease/ownership/replay/idempotency safe as appropriate.
9. **Content scales through seams.** Repeated families trend toward validated data/configuration and bounded extension cost.
10. **World generation remains readable.** Randomness never excuses impossible navigation, unclear objectives, or unwinnable layouts.
11. **Low WIP.** Parallel eligibility prevents freezes; it does not justify branch sprawl.
12. **Coverage is accounting, not authority.** `LK-001`–`LK-300` exposes gaps without demanding one subsystem per row.

## Current program checkpoint

The changing checkpoint belongs in [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md). At this roadmap refresh, the durable Patch 0.7 layer is automated-acceptance closed for non-deferred rows and current main is in concrete maintenance/audit hardening rather than a newly activated broad feature patch.

Do not add detailed future/current PR lists here. They become stale too quickly and belong in the dashboard or GitHub itself.

# Product layers

## Foundation — Repository, runtime safety, observability

**Outcome:** the project can change rapidly without losing authority, evidence, reproducibility, or rollback ability.

Scope:

- GitHub-first canonical source;
- Rojo operation + dedicated Main World mappings;
- pinned development toolchain;
- formatting/lint/unit/integration/build validation;
- runtime ownership/lifecycle rules;
- network contract validation;
- state/presentation rollout safety;
- migration/rollback evidence;
- source/import reconciliation;
- capability/extension/effect-route registries;
- development-coverage registry/auditor;
- deterministic diagnostics and production evidence tooling.

Versioned v2.7 documents remain specialist authority for the runtime state/presentation stabilization boundary they describe. They are not the general product task queue.

## MVP 0.1 — First complete repeatable run

**Outcome:** one complete run can be understood, completed, returned from, and replayed without developer intervention.

Must contain coherent versions of:

- safe arrival/preparation;
- deliberate launch;
- exploration/route;
- combat and enemy variety;
- loot/reward choice;
- elite + boss/terminal outcome;
- failure/retry;
- return;
- banking/equipment/upgrade;
- replay reset;
- minimal persistence needed by the loop.

## Patch 0.2 — Combat feel + readability

**Outcome:** controls/combat feel deliberate and outcomes are legible.

Must mature:

- movement/input responsiveness;
- melee/ranged handling;
- weapon differentiation;
- hit/impact/death feedback;
- enemy telegraphs/reactions;
- elite/boss readability;
- combat HUD/camera/audio/VFX;
- device/accessibility behavior.

## Patch 0.3 — Loot + build replayability

**Outcome:** players make interesting run/build decisions and want another attempt.

Must mature:

- item identity/rarity/equipment;
- deterministic affixes/modifiers;
- loot/reward generation;
- inventory/equipment UX;
- comparison/dismantling where justified;
- run-build synergies;
- reward fairness and server authority.

## Patch 0.4 — RPG progression

**Outcome:** long-term identity expands choices without trivializing execution/difficulty.

Must mature:

- character levels/ranks where justified;
- classes/archetypes;
- stats/talents/loadouts;
- durable unlocks;
- discoveries/codex/achievements;
- bounded permanent power;
- respec/recovery;
- progression persistence/presentation.

## Patch 0.5 — Main World + environment

**Outcome:** players return to a recognizable, navigable, expandable home.

Must mature:

- authored Main World districts/biomes;
- landmarks/route hierarchy;
- traversal support/redundancy/readability;
- preparation/social/NPC anchors;
- expedition entrances/return flow;
- world atmosphere/lighting/audio;
- environment composition;
- streaming/performance readiness;
- secrets/environmental storytelling.

Direction:

```text
authored overworld / HubTown
→ canonical expedition launch
→ modern operation runtime
→ return
```

## Patch 0.6 — Procedural/systemic replayability

**Outcome:** content variation multiplies replayability without sacrificing readability or debuggability.

Must mature:

- reproducible run seeds;
- modular room/route/dungeon generation;
- layout/socket/navigation validation;
- encounter/event variation;
- enemy/loot/boss modifier variation;
- bounded world/event systems;
- reproduction keys/diagnostics/fallbacks;
- generation quality metrics.

## Patch 0.7 — Durable persistence hardening

**Outcome:** valuable state survives lifecycle failure/replay/rejoin/migration safely.

Must mature:

- canonical account/value ownership;
- session leases;
- idempotent valuable mutations;
- migration/quarantine/recovery;
- duplication/rollback resistance;
- inventory/progression preservation;
- disconnect/crash/shutdown correctness;
- automated failure/acceptance matrices.

**Current acceptance summary:** 86 / 100 ranked rows implemented; 14 deliberately deferred with explicit reasons. Detailed proof is machine-readable in `../production/PATCH-0.7-ACCEPTANCE-MATRIX.json`.

## Patch 0.8 — Co-op/social/session expansion

**Outcome:** groups can reliably form, enter, recover, complete, and replay cooperative sessions.

Must mature:

- party formation/invites/friend joins;
- readiness/expedition selection;
- session/run ownership;
- matchmaking where justified;
- reserved server / teleport lifecycle;
- reconnect/late join;
- party-scoped procedural instances;
- revive/support/co-op scaling;
- social presence/communication;
- disconnect/cleanup semantics.

## Patch 0.9 — Content expansion + production pipeline

**Outcome:** content breadth grows without linear engineering cost or authority drift.

Must mature:

- data-first enemy/weapon/item/affix/class/content families where proven;
- quest/NPC/vendor/crafting/gathering contracts where they serve the core loop;
- dungeon/world content factories;
- content prerequisite/reward/reference validation;
- extension-cost budgets;
- content QA/observability;
- production cadence tooling;
- onboarding/retention analytics needed before launch.

## RC — Production hardening

**Outcome:** a stable release candidate can be shipped, observed, and rolled back safely.

Must mature:

- end-to-end regression/acceptance;
- performance/memory/network profiling;
- keyboard/controller/touch/accessibility evidence;
- exploit/security review;
- DataStore/recovery validation;
- publishing/configuration/asset readiness;
- analytics/incident diagnostics;
- launch balance/onboarding/readability;
- release/rollback procedure;
- monetization only when fair, secure, platform-compliant, and product-ready.

## 1.0 — Release

**Outcome:** ship a coherent, trustworthy cooperative action RPG whose core loop, durable state, co-op/session lifecycle, world, and production controls are supported by the evidence required for their claims.

## LIVE — Evidence-driven operation

**Outcome:** post-launch investment follows observed player/runtime evidence.

```text
measure
→ identify friction/opportunity
→ classify LK concern(s)
→ prioritize by player value + risk + dependency + leverage
→ implement
→ validate
→ compare outcome
→ retain / revise / rollback
```

# System destination map

The product layers above are the main dependency path. The following systems may span multiple patches and should mature when they support that path.

## World / simulation

Destination:

- coherent world-state boundaries;
- region/biome topology;
- terrain/traversal surfaces;
- weather/time/lighting where useful;
- environmental hazards/events;
- world observability;
- reproducible procedural/systemic variation;
- measured route/travel/danger/reward distribution.

## Combat / encounters / enemies

Destination:

- server-owned legality/damage;
- readable melee/ranged/abilities;
- distinct weapons;
- enemy archetypes with clear tactical questions;
- bounded navigation/targeting/attacks;
- elites/bosses;
- encounter pressure/pacing;
- fair difficulty/co-op scaling;
- performance budgets and diagnostics.

## Progression / loot / economy

Destination:

- meaningful run builds;
- durable identity/unlocks;
- item/equipment/affix architecture;
- secure reward/inventory/persistence;
- pricing/currency/vendors only when the gameplay loop needs them;
- crafting/gathering only when resources create real decisions;
- item/currency sinks that preserve value clarity;
- balance/abuse protections.

## Content / narrative / discovery

Destination:

- validated quest/objective contracts;
- NPC/dialogue/faction/settlement surfaces;
- discoveries/codex/secrets;
- content prerequisites/rewards;
- data-first repeated content;
- orphan/cycle/reference validation;
- environmental storytelling.

## Social / session

Destination:

- solo-to-co-op continuity;
- party/session/run identity;
- join/readiness/teleport/reconnect policies;
- co-op support/revive/scaling;
- social presence/communication;
- reliable cleanup and ownership boundaries.

## UX / presentation

Destination:

- understandable onboarding;
- contextual HUD;
- coherent menus/navigation;
- keyboard/controller/touch parity for critical actions;
- accessibility;
- clear errors/recovery;
- responsive movement/camera;
- strong visual/audio/VFX/animation identity within performance budgets.

## Production / live operations

Destination:

- reproducible builds;
- trusted validation/evidence;
- observability/analytics;
- content pipeline;
- release/rollback/incident handling;
- player support/feedback loop;
- measured live balance/content cadence;
- secure monetization only after product readiness.

# Deferred / conditional destination systems

Some systems remain valid long-range ideas but are deliberately **conditional**, not assumed requirements:

- player housing/decorating/ownership;
- guild halls/large guild systems;
- broad player trading;
- large-scale PvP;
- complex simulated faction politics;
- deep profession/economy layers;
- recurring daily/weekly chores;
- launch monetization breadth.

They become current only if evidence/player value justifies them and the dashboard explicitly activates the work. Their presence in the development taxonomy is gap accounting, not a promise to ship them.

# Cross-system coverage accounting

The exhaustive development concern inventory lives outside this roadmap:

- [`../architecture/DEVELOPMENT_TAXONOMY.md`](../architecture/DEVELOPMENT_TAXONOMY.md) — 300 stable concerns;
- [`../architecture/DEVELOPMENT-ATLAS.md`](../architecture/DEVELOPMENT-ATLAS.md) — canonical engine/owner routing;
- `../../config/coverage/living-kingdoms-development.json` — machine-readable coverage;
- [`../production/DEVELOPMENT-COVERAGE-REPORT.md`](../production/DEVELOPMENT-COVERAGE-REPORT.md) — generated gap/health view.

The taxonomy makes broad areas visible without bloating the roadmap with 300 duplicated status lines.

# Definition of progress

A roadmap item progresses only through truth appropriate to its layer:

```text
concept/scope defined
→ canonical owner/seam identified
→ source implemented
→ automated gate green
→ BUILT — VERIFICATION PENDING when manual facts remain
→ evidence collected where required
→ VERIFIED for the supported claim
→ measured player/runtime outcome when live
```

Do not use roadmap prose to upgrade evidence status.

# Roadmap maintenance

- Keep changing NOW/NEXT details in the dashboard only.
- Keep per-patch product intent here/Playable Patch Scope, not branch numbers.
- Keep machine-readable exhaustive concern coverage in the coverage registry.
- Keep detailed evidence in production/evidence artifacts.
- Keep historical implementation/provenance in Git history or explicitly historical documents.
- When a system is removed/replaced, update scope/coverage/owner registries coherently rather than leaving parallel stories.

> **The Master Roadmap is the destination map. The dashboard drives. The taxonomy checks blind spots. Source/evidence decide what is real.**
