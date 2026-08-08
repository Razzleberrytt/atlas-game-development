# Atlas Game Development

Atlas is the GitHub-first development home for a **cooperative action RPG on Roblox**.

The project combines readable combat, run-based build decisions, durable progression/world access, discovery, a recognizable Main World, and replayable cooperative operations. Existing Living Kingdoms systems are preserved as working assets while the roadmap converges them on one authoritative runtime and presentation architecture.

## Primary production rule

> Build and prove one polished, replayable expedition and one coherent prepare/adventure/return loop before expanding breadth.

The roadmap describes the full destination now, but agents may implement only the next dependency-safe work authorized by the active runtime or build-ahead lane.

## Product authority

Read [`docs/bible/00-current-product-authority.md`](docs/bible/00-current-product-authority.md) before interpreting older product documents.

The older [`docs/bible/00-project-charter.md`](docs/bible/00-project-charter.md) is retained as historical Living Kingdoms design provenance. Its isometric/automatic-combat and survival-specific statements do not silently override the broader current Atlas product direction. Existing runtime behavior is still preserved until an explicit decision authorizes a migration.

## Roadmap authority

Two layers intentionally coexist:

### Active runtime execution

**Blueprint v2.7 — Rollout & Observability** still controls current runtime execution until its evidence gates close:

- [`docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md`](docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md)
- [`docs/roadmap/PRODUCTION-CORE-V2.7.md`](docs/roadmap/PRODUCTION-CORE-V2.7.md)
- [`docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`](docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md)
- [`docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md`](docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md)

### Complete product path

[`docs/roadmap/MASTER-ROADMAP.md`](docs/roadmap/MASTER-ROADMAP.md) is **Master Roadmap v2.8**. It now describes the complete dependency-gated path through:

- product-authority reconciliation;
- runtime stabilization/evidence;
- Main World and environment;
- party/social/session infrastructure;
- durable persistence;
- long-term progression;
- economy/crafting/resource value;
- content-production pipelines;
- the first complete vertical slice;
- quality/performance/accessibility;
- outside-player fun validation;
- production analytics / E7;
- runtime configuration/operations;
- safety/compliance;
- localization;
- monetization after the fun gate;
- staged launch;
- post-launch/live operations.

Future phases are documented so agents know the destination. They remain locked until their gates open.

## Evidence status

```text
E0 design
→ E1 source/static acceptance
→ E2 Studio initialization
→ E3 single-player integrated behavior
→ E4 multiplayer/adversarial behavior
→ E5 device/performance/reliability
→ E6 outside-player fun
→ E7 live telemetry
```

**Current claimed level remains E1 until accepted Studio evidence advances it.**

## Current active runtime gate

The 2026-08-08 Studio findings invalidated the earlier R1 acceptance artifact because a client-bootstrap stall meant a valid full-client R1 capture was not possible against that build.

The next accepted R1 attempt must use a **recorded CI artifact at or after** client-bootstrap fix `91a1ebe3d04b6d99495f19e7a809bc2b4135fd97`, tied to a fresh evidence packet and exact build/place identity.

PR #221 remains blocked behind R1 acceptance. PR #222 remains stacked/blocked behind #221 and its required evidence.

## Combined-world status

The original Studio preservation gap has been repaired:

- 28/28 Studio-only source files are preserved;
- 1,775/1,775 Workspace identity/hierarchy rows are preserved;
- broad property-backed authored-world reconstruction exists;
- stable world-content IDs/contracts exist;
- the live Forward Operations Hub is the current preparation bridge;
- the recovered authored overworld remains held as a separate future coordinate/lifecycle space;
- the intended end state is **authored overworld / HubTown → canonical expedition launch → modern operation runtime → return**.

See [`games/living-kingdoms/CANONICAL-RUNTIME.md`](games/living-kingdoms/CANONICAL-RUNTIME.md).

## Main World rule

The Main World is a first-class product surface, not a decorative 3D menu.

Its target loop is:

```text
Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return
```

Before broad environment production, the roadmap requires a structured world/environment audit covering layout, landmarks, traversal, terrain/props, lighting/atmosphere/VFX/audio, expansion seams, streaming, performance, and Studio-only visual acceptance.

The current highest-ROI build-ahead task is maintained in [`docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md`](docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md).

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

Exactly one production owner per primitive/lifecycle responsibility. In particular, route/landmark/status Highlight presentation must converge through the shared lease/ownership architecture rather than competing allocations.

Streaming may remove a local Instance. It does not erase authoritative semantic truth.

## Repository map

- `docs/roadmap/` — active execution authority, complete master path, build-ahead queue and history
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
4. Stable IDs and explicit versions are mandatory.
5. Valuable mutations use idempotent transaction IDs where replay is possible.
6. Clients submit intent, never outcomes.
7. Reusable engines and validated content contracts outrank one-off content piles.
8. No runtime, Studio, CI, performance, player-fun, or live-telemetry claim exists without the matching evidence.
9. Do not create parallel authoritative systems.
10. Runtime current state and client presentation have explicit owners and cleanup scopes.
11. Source/static acceptance is E1, not gameplay acceptance.
12. Type, logging, connection, network-rate, presentation-object, world-performance, and content-reference debt must not increase silently.
13. Recovered Studio content is migration/presentation input, not permission to reboot legacy gameplay services.
14. A future roadmap phase being documented is not authorization to implement it early.

## Agent start order

1. Read this file.
2. Read `docs/bible/00-current-product-authority.md`.
3. Read `docs/roadmap/MASTER-ROADMAP.md`.
4. Read `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` and `PRODUCTION-CORE-V2.7.md`.
5. Read `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` when runtime evidence is blocked or build-ahead work is requested.
6. Read `games/living-kingdoms/CANONICAL-RUNTIME.md` and the nearest `AGENTS.md`.
7. Fetch current `main` and inspect open related PRs before editing.
8. For runtime work, execute only the next dependency-safe v2.7 item whose evidence can honestly be produced.
9. For build-ahead work, execute only a task explicitly marked READY and do not activate gated systems.
10. Record evidence, ownership, rollback and unresolved Studio requirements accurately.

## Project status

**Master roadmap:** v2.8 complete product path  
**Active runtime execution:** v2.7 rollout/observability  
**Evidence:** E1  
**Primary runtime blocker:** valid re-pinned R1 Studio evidence run  
**Primary build-ahead lane:** dependency-safe world/content/architecture preparation  
**Roblox project path:** `games/living-kingdoms/`
