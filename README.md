# Atlas Game Development

Atlas is the GitHub-first development home for a **cooperative action RPG on Roblox**.

The project combines readable combat, run-based build decisions, durable progression/world access, discovery, a recognizable Main World, and replayable cooperative operations. Existing Living Kingdoms systems are preserved as working assets while the roadmap converges them on one authoritative runtime and presentation architecture.

## Primary production rule

> **Always leave Atlas playable. Build the smallest complete loop, test it, fix it, then add one coherent upgrade layer.**

The development rhythm is now explicitly:

```text
stabilize
→ playable MVP
→ play / debug / fix
→ coherent upgrade patch
→ replay / regression test
→ next patch
```

The complete roadmap remains valuable, but broad future phases may not leapfrog the current playable patch merely because they are already documented.

## Product authority

Read [`docs/bible/00-current-product-authority.md`](docs/bible/00-current-product-authority.md) before interpreting older product documents.

The older [`docs/bible/00-project-charter.md`](docs/bible/00-project-charter.md) is retained as historical Living Kingdoms design provenance. Its older product assumptions do not silently override the current Atlas direction. Existing runtime behavior is still preserved until an explicit decision authorizes a migration.

## Roadmap authority

Three layers intentionally coexist:

### 1. Active runtime stabilization

**Blueprint v2.7 — Rollout & Observability** controls current runtime safety/stabilization while its applicable evidence gates remain open:

- [`docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md`](docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md)
- [`docs/roadmap/PRODUCTION-CORE-V2.7.md`](docs/roadmap/PRODUCTION-CORE-V2.7.md)
- [`docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`](docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md)
- [`docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md`](docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md)

### 2. Playable implementation sequence — current precedence

[`docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`](docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md) is **Playable MVP + Patch Execution v2.9** and controls which player-facing slice is implemented next once work is dependency-safe.

Its order is:

```text
Gate 0   runtime stabilization
MVP 0.1  first complete run
0.2      combat feel/readability
0.3      loot + build replayability
0.4      RPG progression
0.5      Main World + environment expansion
0.6      procedural/systemic replayability
0.7      durable persistence hardening
0.8      co-op/social/session expansion
0.9      content expansion + production pipeline
RC       production hardening
1.0      release
LIVE     measured upgrade patches
```

Every player-facing milestone ends with a hard **STOP / PLAY / FIX / REPLAY / THEN EXPAND** gate.

### 3. Complete product path

[`docs/roadmap/MASTER-ROADMAP.md`](docs/roadmap/MASTER-ROADMAP.md) remains **Master Roadmap v2.8**, the complete product-path and requirements inventory. It preserves the full scope through world/environment, persistence, progression, economy, content pipelines, quality, analytics, operations, safety/compliance, localization, ethical monetization, launch and live operations.

Those requirements are mapped into the playable patch sequence rather than discarded. When a broad v2.8 phase contains more scope than the current patch needs, agents implement the **smallest coherent dependency-safe subset** that advances the current playable patch.

## First player-facing target — MVP 0.1

After the active stabilization gate is sufficiently safe, the highest-priority target is one complete repeatable run:

```text
spawn / arrive
→ orient and prepare
→ choose a weapon/build
→ enter one expedition
→ explore a readable route
→ fight
→ receive loot/reward decisions
→ defeat an elite
→ defeat one boss / terminal encounter
→ return
→ equip or apply an upgrade
→ start another run
```

Target first-run duration is roughly **5–10 minutes**, subject to play evidence.

The primary product signal is not feature count. It is whether a tester can finish the loop without developer intervention and voluntarily wants another run.

## Combined-world status

The original Studio preservation gap has been repaired:

- 28/28 Studio-only source files are preserved;
- 1,775/1,775 Workspace identity/hierarchy rows are preserved;
- broad property-backed authored-world reconstruction exists;
- stable world-content IDs/contracts exist;
- the live Forward Operations Hub is the current preparation bridge;
- the recovered authored overworld remains a separate future coordinate/lifecycle space;
- the intended end state is **authored overworld / HubTown → canonical expedition launch → modern operation runtime → return**.

See [`games/living-kingdoms/CANONICAL-RUNTIME.md`](games/living-kingdoms/CANONICAL-RUNTIME.md).

## Main World rule

The Main World is a first-class product surface, not a decorative 3D menu.

Its target loop is:

```text
Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return
```

BA-010 and subsequent Main World specifications control world disposition and production decisions. MVP 0.1 should use only the smallest coherent preparation/return surface required for the complete run; broader environment expansion becomes a first-class focus in Patch 0.5.

## Runtime state law

```text
client constructs controllers
→ binds required current-state listeners
→ ClientReady
→ reconstruct current authoritative state
→ consume semantic state changes
```

Independent current facts sharing one physical remote remain independently keyed/retained. Current state is sent because authoritative facts change, not because frames pass.

## Presentation ownership law

Exactly one production owner per primitive/lifecycle responsibility. Route/landmark/status Highlight presentation must converge through the shared lease/ownership architecture rather than competing allocations.

Streaming may remove a local Instance. It does not erase authoritative semantic truth.

## Repository map

- `docs/roadmap/` — playable execution sequence, active runtime authority, complete master path, build-ahead queue and history
- `docs/bible/` — current product authority plus supporting/historical product and visual guidance
- `docs/specifications/` — system behavior inside accepted roadmap boundaries
- `docs/architecture/` — technical boundaries and engineering rules
- `docs/decisions/` — explicit product/architecture decisions
- `docs/production/` — workflow, evidence, validation and Definition of Done
- `games/living-kingdoms/` — canonical Roblox/Rojo game project
- `prompts/` — reusable agent prompts
- `templates/` — task/specification/decision/bug templates

## Engineering laws

1. The server owns valuable game truth.
2. `main` stays playable.
3. Each implementation task produces one testable result.
4. Every player-facing patch preserves and replays the previous playable baseline.
5. Stable IDs and explicit versions are mandatory.
6. Valuable mutations use idempotent transaction IDs where replay is possible.
7. Clients submit intent, never outcomes.
8. Reusable engines and validated content contracts outrank one-off content piles.
9. No runtime, Studio, CI, performance, player-fun, or live-telemetry claim exists without the matching evidence.
10. Do not create parallel authoritative systems.
11. Runtime current state and client presentation have explicit owners and cleanup scopes.
12. Source/static acceptance is E1, not gameplay acceptance.
13. Type, logging, connection, network-rate, presentation-object, world-performance, and content-reference debt must not increase silently.
14. Recovered Studio content is migration/presentation input, not permission to reboot legacy gameplay services.
15. A future roadmap phase being documented is not authorization to implement it early.
16. A known blocker in the current playable loop blocks later-patch breadth until it is fixed or explicitly re-scoped by authority.

## Agent start order

1. Read this file.
2. Read `docs/bible/00-current-product-authority.md`.
3. Read `docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` and identify the current playable patch.
4. Read `docs/roadmap/MASTER-ROADMAP.md` for complete requirements/context.
5. Read `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` and `PRODUCTION-CORE-V2.7.md` for active runtime blockers.
6. Read `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` when runtime evidence is blocked or build-ahead work is requested.
7. Read `games/living-kingdoms/CANONICAL-RUNTIME.md` and the nearest `AGENTS.md`.
8. Fetch current `main` and inspect open related PRs before editing.
9. If a v2.7 dependency blocks the current playable milestone, execute the next dependency-safe blocker or preparation that directly enables it.
10. Otherwise execute the highest-ROI unfinished task for the current playable patch.
11. Do not begin later-patch breadth while a known current-patch blocker remains.
12. Record evidence, ownership, rollback, STOP / PLAY / FIX status and unresolved Studio requirements accurately.

## Authority precedence

```text
accepted runtime evidence / current Roblox platform behavior
→ Blueprint v2.7 + Production Core v2.7 while active stabilization gates remain open
→ Playable MVP + Patch Execution v2.9 for implementation sequencing
→ Current Product Authority + Master Roadmap v2.8 for product direction and complete scope
→ active rollout / cross-system / production controls
→ accepted specifications / architecture decisions
→ specialist visual/environment/Studio guidance
→ historical documents
```

## Project status

**Implementation sequencing:** Playable MVP + Patch Execution v2.9  
**Complete product path:** Master Roadmap v2.8  
**Active runtime stabilization:** Blueprint v2.7 rollout/observability  
**Primary player-facing target after Gate 0:** MVP 0.1 First Complete Run  
**Roblox project path:** `games/living-kingdoms/`
