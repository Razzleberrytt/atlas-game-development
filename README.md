# Atlas Game Development

Atlas is the GitHub-first development home for a **cooperative first-person action RPG on Roblox**.

The game combines readable FPS combat, randomized loot and buildcraft, long-term progression and world access, secrets, and replayable cooperative expeditions.

## Player promise

Every meaningful session should provide:

1. **Discovery** — something the player did not fully expect.
2. **Growth** — power, options, access, knowledge, mastery, collection, or social progress.
3. **Story** — at least one moment worth describing to another player.

## Primary production rule

> Build one polished, replayable expedition before expanding into a large world.

The first product is a five-to-ten-minute vertical slice containing preparation, an outdoor route, an optional secret, a short procedurally assembled dungeon, three enemy roles, one elite, the Gatekeeper boss, randomized equipment, saving, and cooperative play.

## Source of truth

The active implementation and quality authority is:

- [`docs/roadmap/BLUEPRINT-V2.0-EXECUTION.md`](docs/roadmap/BLUEPRINT-V2.0-EXECUTION.md)

Historical execution context remains available:

- [`docs/roadmap/BLUEPRINT-V1.9-EXECUTION.md`](docs/roadmap/BLUEPRINT-V1.9-EXECUTION.md)
- [`docs/roadmap/UNIFIED-MASTER-ROADMAP.md`](docs/roadmap/UNIFIED-MASTER-ROADMAP.md)

When documents conflict, **Blueprint v2.0 and captured evidence win**. Existing systems are assets to reconcile with the blueprint, not permission to maintain parallel authoritative implementations.

## Evidence status

The project uses the v2.0 evidence scale:

`E0 design → E1 source → E2 Studio start → E3 solo loop → E4 multiplayer/adversarial → E5 device/reliability → E6 outside-player fun → E7 live telemetry`

**Current level: E1.** The uploaded v0.7 baseline passed its reproducible static audit with zero blocking issues and one documented warning: 278 remaining `any` tokens. Static acceptance does not imply Roblox Studio acceptance.

Per project direction, Roblox Studio verification is reserved for the final integrated verification pass. Until then, repo-side fixtures may be added and inspected, but no Studio, multiplayer, device, performance, or player result may be claimed.

## Current checkpoint — ownership, recovery, and integrated-loop completion

The active repo-verifiable queue is:

- owner-only inventory state and adversarial cross-player rejection;
- item comparison and equipment-to-combat handoff;
- dismantle and salvage;
- inventory-capacity retry and overflow recovery;
- participation eligibility and personal reward isolation;
- persistence adapters, session ownership, sequential migration, quarantine, unknown-write reconciliation, and failure recovery;
- preparation room, Verdant Scar route, Underroot Vault, elite, and Gatekeeper integration;
- final source audit and type-debt ratchet;
- final Studio verification and evidence capture.

No broader world, loot-category, social, monetization, or live-service expansion is allowed until this gate is passed.

## Repository map

- `docs/roadmap/` — canonical roadmap and active execution queue
- `docs/bible/` — supporting product vision and design history
- `docs/specifications/` — source-of-truth system behavior
- `docs/architecture/` — technical boundaries and engineering rules
- `docs/decisions/` — design and architecture decisions
- `docs/production/` — workflow, validation, and Definition of Done
- `games/living-kingdoms/` — Roblox/Rojo project
- `prompts/` — reusable agent prompts
- `templates/` — task, specification, decision, and bug templates

## Engineering laws

1. The server owns valuable game truth.
2. `main` stays playable.
3. Each implementation task produces one testable result.
4. Stable IDs and explicit versions are mandatory.
5. Valuable mutations use idempotent transaction IDs.
6. Clients submit intent, never outcomes.
7. Reusable engines outrank one-off content piles.
8. No runtime, Studio, CI, performance, or player result is claimed without evidence.
9. Do not create parallel authoritative systems.
10. The polished core loop outranks the eventual feature list.
11. Source assembly is E1, not gameplay acceptance.
12. Type and logging debt must not increase silently.

## Agent start order

1. Read this file.
2. Read `docs/roadmap/BLUEPRINT-V2.0-EXECUTION.md`.
3. Read the nearest `AGENTS.md` for files being changed.
4. Inspect existing contracts, registries, services, and tests before adding anything.
5. Implement the first incomplete v2.0 task that can honestly be completed in the current environment.
6. Preserve E1 status until final Studio evidence exists.
7. Record acceptance evidence honestly and prepare the final verification path.

## Project status

**Phase:** vertical-slice ownership, recovery, and integrated-loop completion  
**Evidence:** E1 — source assembled and statically audited  
**Active milestone:** Blueprint v2.0 repo-side completion before final verification  
**Working title:** unresolved  
**Roblox project path:** `games/living-kingdoms/`
