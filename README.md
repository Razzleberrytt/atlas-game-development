# Atlas Game Development

Atlas is the GitHub-first development home for a **cooperative action RPG on Roblox**.

The project combines readable combat, run-based build decisions, long-term progression/world access, discovery, and replayable cooperative operations. Existing Living Kingdoms systems are preserved as working assets while the roadmap converges them on one authoritative runtime and presentation architecture.

## Primary production rule

> Build and prove one polished, replayable expedition before expanding the world.

## Source of truth

The active implementation and quality authority is **Blueprint v2.7 — Rollout & Observability** (2026-08-07):

- [`docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md`](docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md) — controlling authority and Tickets 331–360
- [`docs/roadmap/PRODUCTION-CORE-V2.7.md`](docs/roadmap/PRODUCTION-CORE-V2.7.md) — daily-use production rules and current critical path
- [`docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md`](docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md) — staged migration, observability, rollback, soak, and closure procedure
- [`docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md`](docs/roadmap/CROSS-SYSTEM-TRACEABILITY-V2.7.md) — mechanical/replication/presentation ownership and evidence gates
- [`docs/roadmap/MASTER-ROADMAP.md`](docs/roadmap/MASTER-ROADMAP.md) — milestone-level current roadmap
- [`docs/roadmap/README.md`](docs/roadmap/README.md) — full roadmap index and historical checkpoints

When documents conflict, **accepted runtime evidence and current Roblox platform behavior win, then the v2.7 authority layer**. Older roadmap files remain provenance, not current execution orders.

## Evidence status

The project uses this evidence scale:

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

**Current claimed level remains E1 until accepted Studio evidence advances it.** A documentation update does not promote evidence level.

## Current active gate

Two runtime symptoms captured in the active Studio place remain stop conditions until closure evidence exists:

1. `ReplicatedStorage.HordeNetwork.State` invocation-queue exhaustion/discard warnings;
2. escaped broad blue/yellow `Highlight` presentation.

The screenshot proves symptoms, not exact causes. v2.7 therefore requires producer/consumer inventory, counters, readiness gating, semantic-state suppression, centralized presentation ownership, reset/respawn/late-join/multiplayer soak testing, and a closure packet.

## Current checkpoint — Tickets 331–360

### 331–335: establish the baseline

- freeze a development copy/build identity;
- inventory all legacy State producers and effective client listeners;
- capture baseline State message rates and queue symptoms;
- inventory Highlight producers/Adornees and presentation gauges.

### 336–345: migrate current state deliberately

- establish exactly one intended compatibility listener;
- gate delivery on client readiness;
- identify current facts with semantic keys;
- suppress unchanged state using mutation-derived change tokens;
- migrate round, objective, route, and landmark producers;
- capture before/after per-key send rates.

### 346–350: establish single presentation ownership

- route route-guide and landmark accents through one shared Highlight lease registry;
- reject broad production Highlight targets;
- prove stream-out/rebind behavior;
- capture baseline/peak/end presentation gauges.

### 351–360: soak, close, then remove compatibility

- five-reset and three-respawn leak matrices;
- delayed-ready and late-join matrix;
- two-player reset/disconnect matrix;
- 100-animation-play marker-listener test;
- ten-minute active network/presentation soak;
- profiling/network evidence;
- P0/P1 defect closure;
- incident closure packet;
- compatibility removal only for ledger rows with accepted replacement evidence and a retained rollback checkpoint.

No broader feature expansion is authorized merely because compatibility code hides a warning.

## Runtime state law

```text
client constructs controllers
→ binds required current-state listeners
→ ClientReady
→ reconstruct current authoritative state
→ consume semantic state changes
```

Current state is keyed semantically (`round.phase`, `objective.current`, `route.target`, etc.) and is sent because the underlying fact changed—not because a frame elapsed.

Independent current facts that share one physical remote must remain independent in pre-ready retention. Retain by player + remote + semantic key, not one latest payload for the entire remote.

## Presentation ownership law

Exactly one production owner per primitive:

```text
Highlight             → shared client Highlight lease registry
route guide            → RouteGuidePresentationController
landmark accent        → LandmarkAccentPresentationController
status/mark outline    → status presentation through the same registry
viewmodel              → one viewmodel owner
camera modifiers       → one named modifier stack
animation marker hooks → owning track/controller scope
```

Streaming may remove a local Instance. It does not erase the authoritative semantic fact.

## Repository map

- `docs/roadmap/` — canonical roadmap and active execution queue
- `docs/bible/` — supporting product/visual/Studio specialist guidance and history
- `docs/specifications/` — source-of-truth system behavior inside accepted roadmap boundaries
- `docs/architecture/` — technical boundaries and engineering rules
- `docs/decisions/` — design and architecture decisions
- `docs/production/` — workflow, validation, migration, and Definition of Done
- `games/living-kingdoms/` — Roblox/Rojo project
- `prompts/` — reusable agent prompts
- `templates/` — task, specification, decision, and bug templates

## Engineering laws

1. The server owns valuable game truth.
2. `main` stays playable.
3. Each implementation task produces one testable result.
4. Stable IDs and explicit versions are mandatory.
5. Valuable mutations use idempotent transaction IDs where replay is possible.
6. Clients submit intent, never outcomes.
7. Reusable engines outrank one-off content piles.
8. No runtime, Studio, CI, performance, or player result is claimed without evidence.
9. Do not create parallel authoritative systems.
10. Runtime current state and client presentation have explicit owners and cleanup scopes.
11. Source/static acceptance is E1, not gameplay acceptance.
12. Type, logging, connection, network-rate, and presentation-object debt must not increase silently.

## Agent start order

1. Read this file.
2. Read `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` and `docs/roadmap/PRODUCTION-CORE-V2.7.md`.
3. Read `docs/roadmap/ACTIVE-PLACE-ROLLOUT-V2.7.md` for any current Studio/state/presentation work.
4. Read the nearest `AGENTS.md` for files being changed.
5. Inspect existing contracts, services, remotes, controllers, tests, and lifecycle owners before adding anything.
6. Implement the **lowest-numbered incomplete v2.7 ticket** that can honestly be completed in the current environment.
7. Preserve E1 status until accepted Studio evidence supports promotion.
8. Record evidence and rollback information rather than inferring success from source shape.

## Project status

**Phase:** v2.7 active-place rollout and observability  
**Evidence:** E1 — source/static work exists; active-place runtime closure still required  
**Active milestone:** Tickets 331–360  
**Roblox project path:** `games/living-kingdoms/`
