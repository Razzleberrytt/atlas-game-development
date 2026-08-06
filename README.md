# Atlas Game Development

Atlas is the GitHub-first development home for a **cooperative first-person action RPG on Roblox**.

The game combines readable FPS combat, Diablo-style randomized loot and buildcraft, WoW-like long-term progression and world access, and replayable cooperative expeditions.

## Player promise

Every meaningful session should provide:

1. **Discovery** — a place, route, enemy, secret, item interaction, clue, or system interaction the player did not fully expect.
2. **Growth** — power, options, access, knowledge, mastery, collection progress, or social progress.
3. **Story** — at least one moment worth describing to another player.

## Primary production rule

> Build one polished, replayable expedition before expanding into a large world.

The first product is a five-to-ten-minute vertical slice containing:

- one preparation room;
- one short outdoor route;
- one optional secret;
- one procedurally assembled dungeon route;
- three enemy families;
- one elite encounter;
- one boss;
- randomized loot and equipment;
- saving;
- solo and cooperative play.

The slice succeeds when outside testers voluntarily start another run.

## Source of truth

The canonical roadmap and active TODO live in:

- [`docs/roadmap/UNIFIED-MASTER-ROADMAP.md`](docs/roadmap/UNIFIED-MASTER-ROADMAP.md)

Existing architecture, systems, and validated gameplay are assets to reuse. They are not automatically product requirements when they conflict with the unified blueprint.

## Current sprint — VS-01 Expedition Foundation

- [x] Establish the unified product direction.
- [x] Preserve the existing server-authoritative Roblox/Rojo architecture.
- [x] Define the first expedition contract and completion gates.
- [ ] Add expedition runtime state ownership.
- [ ] Add deterministic room-sequence assembly.
- [ ] Connect existing combat encounters to expedition phases.
- [ ] Add one elite reward and one boss reward through the equipment pipeline.
- [ ] Add end-of-run results and replay prompt.
- [ ] Validate the complete loop in Roblox Studio with 1, 2, and 4 players.

## Repository map

- `docs/roadmap/` — canonical roadmap, milestones, and active TODO
- `docs/bible/` — supporting product vision and design history
- `docs/specifications/` — source-of-truth system behavior
- `docs/architecture/` — technical boundaries and engineering rules
- `docs/decisions/` — design and architecture decisions
- `docs/production/` — local workflow, validation, and Definition of Done
- `games/living-kingdoms/` — Roblox/Rojo project
- `prompts/` — reusable agent prompts
- `templates/` — task, specification, decision, and bug templates

## Engineering laws

1. The server owns valuable game truth.
2. `main` stays playable.
3. Each implementation task produces one testable result.
4. Reusable engines outrank one-off content piles.
5. Randomness changes situations, not the basic rules.
6. Friends should usually be able to play together despite progression gaps.
7. The polished core loop outranks the eventual feature list.

## Agent start order

1. Read this file.
2. Read `docs/roadmap/UNIFIED-MASTER-ROADMAP.md`.
3. Read the nearest `AGENTS.md` for the files being changed.
4. Inspect existing contracts/config/services before creating a parallel system.
5. Implement the first unchecked task in the active sprint unless blocked.
6. Record acceptance evidence honestly; never invent Studio results.

## Project status

**Phase:** vertical-slice convergence  
**Active milestone:** VS-01 Expedition Foundation  
**Working title:** unresolved  
**Roblox project path:** `games/living-kingdoms/`
