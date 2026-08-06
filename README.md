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

The first product is a five-to-ten-minute vertical slice containing preparation, an outdoor route, an optional secret, a short procedurally assembled dungeon, three enemy families, one elite, one boss, randomized equipment, saving, and cooperative play.

## Source of truth

The active implementation roadmap is:

- [`docs/roadmap/BLUEPRINT-V1.9-EXECUTION.md`](docs/roadmap/BLUEPRINT-V1.9-EXECUTION.md)

The earlier consolidated roadmap remains historical context:

- [`docs/roadmap/UNIFIED-MASTER-ROADMAP.md`](docs/roadmap/UNIFIED-MASTER-ROADMAP.md)

When documents conflict, **Blueprint v1.9 wins**. Existing systems are assets to reconcile with the blueprint, not permission to maintain parallel authoritative implementations.

## Current checkpoint — Blueprint v1.9 ownership proof

The active queue is Tickets **136–150**:

- Studio/runtime discrepancy capture;
- registry and deterministic-loot proof;
- exactly-once personal rewards;
- owner-only inventory state;
- item comparison and equipment handoff;
- dismantle and salvage;
- capacity retry and overflow recovery;
- participation eligibility;
- persistence adapters, session ownership, migration, quarantine, and failure recovery.

No broader loot-category expansion is allowed until one earned item survives save failure, leave/rejoin, retry, migration, and duplicate attempts without loss or cloning.

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
8. No Studio or CI result is claimed without evidence.
9. Do not create parallel authoritative systems.
10. The polished core loop outranks the eventual feature list.

## Agent start order

1. Read this file.
2. Read `docs/roadmap/BLUEPRINT-V1.9-EXECUTION.md`.
3. Read the nearest `AGENTS.md` for files being changed.
4. Inspect existing contracts, registries, services, and tests before adding anything.
5. Implement the first incomplete v1.9 task that can honestly be completed in the current environment.
6. Preserve the Studio-only status of Ticket 136 until actual Studio evidence exists.
7. Record acceptance evidence honestly.

## Project status

**Phase:** vertical-slice ownership and recovery proof  
**Active milestone:** Blueprint v1.9 Tickets 136–150  
**Working title:** unresolved  
**Roblox project path:** `games/living-kingdoms/`
