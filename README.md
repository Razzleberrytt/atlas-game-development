# Atlas Game Development

An AI-first development framework and home of **Living Kingdoms**, a match-based Roblox real-time strategy game.

## Current objective

Build the smallest complete RTS vertical slice:

1. Control an overhead camera.
2. Select multiple workers.
3. Move selected units.
4. Gather wood.
5. Construct a Barracks.
6. Train Swordsmen.
7. Destroy an enemy Town Hall.

## Operating rule

Atlas exists to help ship the game—not delay it. Infrastructure work is time-boxed, `main` stays playable, and each implementation task should produce one testable result.

## Repository map

- `docs/bible/` — product vision and game-design decisions
- `docs/specifications/` — source-of-truth behavior for game objects and systems
- `docs/architecture/` — technical boundaries and engineering rules
- `docs/roadmap/` — ordered milestones and executable tasks
- `docs/decisions/` — architecture and design decision records
- `docs/production/` — development workflow and Definition of Done
- `prompts/` — reusable Codex prompts
- `templates/` — specification, task, decision, and bug templates
- `games/living-kingdoms/` — Roblox/Rojo project home

## Start here

Read these files in order:

1. `docs/bible/00-project-charter.md`
2. `docs/bible/01-mvp.md`
3. `docs/architecture/technical-blueprint.md`
4. `docs/roadmap/MASTER-ROADMAP.md`
5. `prompts/codex-master-prompt.md`

For Windows installation and Roblox Studio synchronization, follow the [Windows local setup guide](docs/production/LOCAL-SETUP.md).
For Luau formatting and static analysis, follow the [Luau tooling guide](docs/production/LUAU-TOOLING.md).
For the reusable Studio launch check and first successful result, see the [smoke-test record](docs/production/SMOKE-TEST.md).

## Project status

**Atlas version:** 0.1  
**Living Kingdoms phase:** Overhead camera

**Next executable task:** LK-0013 — add mouse-wheel zoom
