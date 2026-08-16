# Atlas — Playable Patch Scope v3.0

**Status:** CURRENT PLAYER-FACING PATCH SCOPE  
**Refreshed:** 2026-08-16  
**Purpose:** define what each playable product layer is trying to achieve without competing with the execution dashboard.  
**Current task selection:** [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md).

This document is a **product sequencing map**, not a live task queue. Dated implementation narration, old PR numbers, and superseded “next task” instructions belong in Git history, evidence packets, or historical docs—not in current patch authority.

## Authority relationship

Use:

```text
accepted runtime evidence / current Roblox platform behavior
→ canonical source + repository configuration
→ Current Product Authority for product identity
→ Parallel Development Policy for work eligibility
→ Execution Dashboard for NOW / NEXT
→ Automated-First + Build-Through policies for cadence/status
→ this document for player-facing patch intent
→ Master Roadmap for long-range scope
→ specialist specifications / architecture / production controls
```

The dashboard may select a defect, maintenance lane, dependency, migration, evidence task, or tooling task between numbered product patches when that is the highest-ROI safe work.

## Patch law

Every patch should:

- add one coherent player-facing layer;
- preserve the playable baseline unless an explicit migration replaces it;
- keep valuable game truth server-owned;
- reuse canonical owners rather than creating parallel systems;
- prefer data/configuration for repeated content families;
- include focused automated regression coverage;
- keep failure/recovery paths diagnosable;
- state manual/Studio facts as unmeasured until evidence exists;
- remain small enough to debug and roll back coherently.

A patch is not `VERIFIED` merely because code merged. A source-complete patch may be **BUILT — VERIFICATION PENDING** while evidence catches up.

## Product path

```text
MVP 0.1  first complete repeatable run
0.2      combat feel + readability
0.3      loot + build replayability
0.4      RPG progression
0.5      Main World + environment
0.6      procedural/systemic replayability
0.7      durable persistence hardening
0.8      co-op/social/session expansion
0.9      content expansion + production pipeline
RC       production hardening
1.0      release
LIVE     measured upgrade patches
```

This sequence expresses product layering, not a claim that the dashboard is currently executing the next number in the list.

# MVP 0.1 — First Complete Repeatable Run

**Goal:** prove the complete core loop with the smallest coherent implementation.

Target loop:

```text
safe arrival
→ orient / prepare
→ humble starting path
→ deliberate expedition launch
→ explore + fight
→ discover/earn gear
→ loot/reward decision
→ elite
→ boss / terminal encounter
→ result
→ return
→ bank/equip/upgrade
→ replay
```

Minimum product qualities:

- a safe preparation/return surface;
- deliberate expedition start;
- readable exploration/combat route;
- several distinct tactical enemy questions;
- meaningful loot/reward interaction;
- elite + terminal/boss outcome;
- failure stakes that forfeit unbanked run value without erasing durable identity;
- replay that resets temporary run power cleanly;
- device-neutral critical interaction paths;
- server-owned rewards/combat/progression consequences;
- enough variation or discovery to create a reason for another run.

**Current interpretation:** the source loop has extensive implementation history and remains subject to truthful evidence status. Do not resurrect old MVP 0.1 “next task” text; consult current source, dashboard, and evidence.

# Patch 0.2 — Combat Feel + Readability

**Goal:** make the loop satisfying and legible moment to moment.

Focus:

- responsive input/movement/combat cadence;
- weapon identity and differentiation;
- melee/ranged feedback;
- hit/impact/damage/death punctuation;
- enemy reactions and telegraphs;
- elite/boss readability;
- ability feedback;
- camera/HUD combat clarity;
- device/accessibility presentation;
- audio/VFX feedback without obscuring tactical information.

Exit intent: players understand why combat outcomes happened and controls feel deliberate rather than mushy or noisy.

# Patch 0.3 — Loot + Build Replayability

**Goal:** make successive runs tactically different because of item/build decisions.

Focus:

- item identity/rarity/power clarity;
- equipment slots and comparison;
- deterministic affix/modifier architecture;
- meaningful reward choices;
- run-build synergies;
- loot generation/distribution fairness;
- server-authoritative equip/dismantle/reward flow;
- compact inventory UX;
- replay motivation driven by choices, not only larger numbers.

Exit intent: players can explain how two runs/builds differed and why they want another attempt.

# Patch 0.4 — RPG Progression

**Goal:** add durable identity and progression without erasing skill or expedition difficulty.

Focus:

- character identity/levels/ranks where justified;
- classes/archetypes/side-grades;
- stats/talents/skill mapping;
- loadouts and unlocks;
- discoveries/codex/achievements;
- bounded durable power;
- respec/recovery rules;
- progression presentation;
- secure persistence through existing durable owners.

Exit intent: long-term progress expands choices and identity more than it inflates mandatory power.

# Patch 0.5 — Main World + Environment

**Goal:** turn the safe home into a memorable, readable, expandable place rather than a menu or giant empty map.

Focus:

- authored Main World topology;
- districts/biomes/landmarks;
- route readability and redundancy;
- safe arrival/orientation;
- preparation/social/NPC surfaces;
- expedition entrances/return flow;
- world/environment composition;
- traversal support and measurable failure resilience;
- lighting/atmosphere/audio;
- streaming/performance readiness;
- secrets/environmental storytelling.

Architectural direction:

**authored overworld / HubTown → canonical expedition launch → modern operation runtime → return**

Exit intent: players can navigate by place identity and understand where to prepare, explore, and launch without developer guidance.

# Patch 0.6 — Procedural + Systemic Replayability

**Goal:** multiply replayability without sacrificing authored readability or winnability.

Focus:

- reproducible server-owned seeds;
- modular route/dungeon assembly;
- validated room/socket/layout contracts;
- encounter/event variation;
- loot/enemy/boss modifier variation;
- bounded world-system variation;
- generation diagnostics/reproduction keys;
- navigability/winnability validation;
- controlled failure/fallback behavior.

Exit intent: seeds create meaningfully different but debuggable runs, never incomprehensible random soup.

# Patch 0.7 — Durable Persistence Hardening

**Goal:** make valuable durable state trustworthy across retries, replays, rejoin, crashes, migration, and multi-server ownership.

Focus:

- canonical durable ownership;
- session leases;
- idempotent valuable mutations;
- replay/duplication resistance;
- migrations/quarantine/recovery;
- inventory/progression integrity;
- lifecycle shutdown/rejoin behavior;
- automated failure matrices and acceptance.

**Current status:** automated acceptance is closed for all non-deferred ranked rows: **86 / 100 implemented, 14 explicitly deferred**. The detailed machine proof lives in `../production/PATCH-0.7-ACCEPTANCE-MATRIX.json`. This patch is not the current live task queue.

# Patch 0.8 — Co-op / Social / Session Expansion

**Goal:** make cooperative play reliable and easy to enter without weakening authority or lifecycle correctness.

Focus:

- parties/invites/friend joins;
- readiness and expedition selection;
- public/private session policy;
- matchmaking where justified;
- reserved-server/teleport lifecycle;
- reconnect/late-join rules;
- party-scoped run identity;
- revive/support/co-op scaling;
- social presence/communication;
- disconnect/ownership cleanup;
- multi-run/session isolation.

Exit intent: players can form, enter, complete, recover from disruption, and replay cooperative sessions predictably.

# Patch 0.9 — Content Expansion + Production Pipeline

**Goal:** prove Atlas can grow breadth without linear engineering cost or authority drift.

Focus:

- reusable content registries/contracts;
- enemies/weapons/items/affixes/classes/encounters as data-first families where mature;
- quests/NPCs/vendors/crafting/gathering only where they serve coherent loops;
- dungeon/world content factories;
- validation for IDs/references/prerequisites/rewards/cycles/orphans;
- extension-cost budgets;
- content QA and observability;
- production cadence tooling;
- onboarding/retention/analytics surfaces needed before launch.

Exit intent: adding high-quality content usually extends stable seams instead of requiring new bespoke runtime authorities.

# RC — Production Hardening

**Goal:** turn the durable playable game into a release candidate.

Focus:

- regression/acceptance closure;
- performance/memory/network profiling;
- device/accessibility closure;
- exploit/security review;
- DataStore/recovery readiness;
- publishing/environment configuration;
- analytics/incident diagnostics;
- rollback/release procedure;
- launch content/balance/readability polish;
- monetization only when fair, secure, platform-compliant, and product-ready.

# 1.0 — Release

**Goal:** ship a coherent, trustworthy product with a measured live-operations loop.

Release requires evidence appropriate to the claims being made. Source completion alone is not release proof.

# LIVE — Measured Upgrade Patches

Post-launch work follows observed player/runtime evidence rather than speculative breadth:

```text
measure
→ identify friction/opportunity
→ classify LK concern(s)
→ choose highest-ROI safe change
→ implement/validate
→ compare outcome
→ keep/revise/rollback
```

## Scope accounting

The patch path does not attempt to enumerate every development concern inline. Comprehensive cross-system coverage lives in:

- `../architecture/DEVELOPMENT_TAXONOMY.md` (`LK-001`–`LK-300`);
- `../architecture/DEVELOPMENT-ATLAS.md`;
- `../../config/coverage/living-kingdoms-development.json`;
- `../production/DEVELOPMENT-COVERAGE-REPORT.md`.

Those documents expose gaps; the dashboard decides execution.

## Historical implementation detail

Old per-PR checkpoints, obsolete branch numbers, superseded “next highest-ROI task” statements, and dated Studio-environment incidents were deliberately removed from this current scope document. Their provenance remains available in Git history and evidence files. Do not copy them back into current patch authority unless they become current facts again.

> **Patch scope says what good looks like. The dashboard says what we are doing now. Evidence says what is actually proven.**
