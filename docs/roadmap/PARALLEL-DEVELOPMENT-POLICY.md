# Atlas Parallel Development Policy

**Status:** CURRENT GOVERNANCE OVERRIDE  
**Effective:** 2026-08-12  
**Purpose:** keep runtime stabilization rigorous without freezing unrelated product development.

## Core rule

Pending Studio evidence, rollout work, or an unresolved runtime defect does **not** create a blanket repository freeze.

Atlas may continue building gameplay, RPG systems, Main World content, environment systems, weapons, enemies, crafting, progression, persistence preparation, monetization preparation, live-service tooling, visuals, developer tooling, and other roadmap work in parallel with Blueprint v2.7 stabilization.

Blueprint v2.7 remains authoritative for the runtime-state/presentation migration and for evidence required to call that runtime path accepted. It no longer controls whether unrelated or dependency-safe source development may proceed.

## What this policy supersedes

This policy supersedes older wording that says or implies any of the following merely because v2.7 gates remain open:

- `BLOCKED BY V2.7` as a blanket project status;
- `does not authorize` new gameplay/content systems;
- `stop feature expansion` when the problem is confined to another runtime path;
- `do not add scope` solely because Studio/device evidence is pending;
- `only after Tickets 331–360` for unrelated source work;
- broad freezes on RPG, world, enemy, weapon, progression, monetization, live-service, or content-factory work.

Those clauses remain relevant only when a concrete dependency or regression directly affects the work being attempted.

## Parallel lanes

Work may proceed concurrently in any of these lanes:

1. **Runtime stabilization** — v2.7 state delivery, semantic suppression, presentation ownership, cleanup, soak, and evidence.
2. **Core gameplay** — combat feel, horde pressure, encounters, rewards, classes, enemies, weapons, missions, dungeon/runtime systems.
3. **RPG/progression** — run builds, relics, result summaries, balance, durable-value preparation, persistence preparation.
4. **Main World/environment** — authored world recovery, biomes, structures, resources, NPC presentation, traversal, streaming-ready content, atmosphere.
5. **Content factories** — environment, weapon visuals/skins, enemy presentation, crafting/gathering visuals.
6. **Product/business** — monetization preparation, live-service scaffolding, analytics, retention tooling, onboarding, UX, store/purchase presentation.
7. **Developer infrastructure** — validators, registries, test fixtures, build tooling, observability, import/export, Rojo/Studio integration.

The existence of one active lane does not make the others illegal.

## Guardrails

Parallel work must still obey these rules:

- **No duplicate authority.** A new feature may not create a second owner for combat truth, inventory, progression, rewards, persistence, networking, or presentation primitives already owned elsewhere.
- **Do not hide evidence.** A failing runtime test stays failing until fixed; feature work cannot relabel it as accepted.
- **Separate built from verified.** Source-complete work may be `BUILT — VERIFICATION PENDING`; only evidence can make it `VERIFIED`.
- **Contain risky integration.** Changes that could destabilize an unresolved runtime path should use branches, feature flags, isolated mappings, or other reversible boundaries until validated.
- **Fix concrete regressions first when they collide.** If new work directly breaks the active path, that defect takes priority over continuing the same integration.
- **Automated validation remains required.** Dependency-safe source work should pass applicable static/unit/build checks before merge.
- **Runtime promotion gates remain real.** A system may be built before all Studio gates pass, but it may not be promoted, published, or called production-ready without the evidence required for that claim.

## Blocking rule

A task is `BLOCKED` only when there is a **specific, direct dependency** that prevents safe progress.

Valid blockers include:

- required source contract does not exist;
- work would overwrite or conflict with an active owner and cannot be isolated;
- a reproducible regression makes further work in the same path unsafe;
- a required external/manual fact is necessary to choose an implementation safely;
- platform/API limitations make the task impossible as designed.

Invalid blockers include:

- another roadmap lane is unfinished;
- Studio evidence is pending for an unrelated subsystem;
- v2.7 is still open in general;
- the project has not yet reached a later evidence level;
- a future manual test exists but source-safe work can continue without guessing its result.

## Merge rule

A parallel increment may merge when:

1. it does not create conflicting gameplay/runtime authority;
2. applicable automated validation passes;
3. it is reversible or isolated where runtime risk remains;
4. documentation/status labels accurately distinguish built from verified;
5. no concrete known regression is being concealed.

Runtime-risky activation can remain disabled while the underlying source, data contracts, models, registries, tests, and tooling merge normally.

## Release and promotion rule

Parallel development changes **what may be built**, not **what may be claimed**.

Blueprint v2.7 evidence gates still control acceptance of the state/presentation rollout. Main World acceptance gates still control claims about Main World runtime readiness. Multiplayer/device/performance gates still control those claims. Monetization or persistence must still satisfy their own correctness/security requirements before production use.

## Task-selection rule

When asked to continue or implement the next roadmap task:

1. inspect current `main` and open PRs for overlap;
2. fix any concrete regression that directly blocks the path being changed;
3. otherwise choose the highest-ROI unfinished task across all available lanes;
4. prefer work that is modular, reversible, and testable;
5. merge successful dependency-safe increments without waiting for unrelated manual gates;
6. keep verification status honest.

## Conflict rule

When this policy conflicts with older v2.7 scope-freeze wording, **this policy controls the scope decision**. Blueprint v2.7 and Production Core v2.7 still control the technical invariants and evidence requirements of their runtime stabilization lane.

> Stabilize rigorously, build continuously. Evidence controls promotion; it does not freeze invention.
