# Atlas Game Development

An AI-first development framework and home of **Living Kingdoms**, the temporary working title for a brutally difficult cooperative isometric survival game on Roblox.

## Current objective

Build one finite, authored survival operation in which separated players find one another, combine specialist abilities, manage scarce ammunition and recovery resources, withstand escalating enemy pressure, and complete an extraction or final objective.

The initial MVP targets 1–4 players while keeping the architecture compatible with a later maximum of 8 cooperative players.

## Operating rule

Atlas exists to help ship the game—not delay it. Infrastructure work is time-boxed, `main` stays playable, and each implementation task should produce one testable result.

## Repository map

- `docs/bible/` — canonical product vision and game-design decisions
- `docs/specifications/` — source-of-truth behavior for game objects and systems when added
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
5. `docs/decisions/0001-cooperative-survival-pivot.md`
6. `docs/decisions/0002-automatic-combat-targeting.md`
7. `prompts/codex-master-prompt.md`

For Windows installation and Roblox Studio synchronization, follow the [Windows local setup guide](docs/production/LOCAL-SETUP.md).
For Luau formatting and static analysis, follow the [Luau tooling guide](docs/production/LUAU-TOOLING.md).
For the reusable Studio launch check and first successful result, see the [smoke-test record](docs/production/SMOKE-TEST.md).

## Project status

**Atlas version:** 0.1  
**Living Kingdoms phase:** P1 — Tactical player movement and character controller

**Next executable task:** LK-0102 — define and enforce the initial movement authority boundary

Final public branding is unresolved. Living Kingdoms remains the working title and internal project identifier; naming work is outside the current scope.
