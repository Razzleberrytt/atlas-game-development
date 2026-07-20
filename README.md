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
5. `docs/roadmap/P6-P12-EXECUTION-ROADMAP.md`
6. `docs/decisions/0001-cooperative-survival-pivot.md`
7. `docs/decisions/0002-automatic-combat-targeting.md`
8. `prompts/codex-master-prompt.md`

For Windows installation and Roblox Studio synchronization, follow the [Windows local setup guide](docs/production/LOCAL-SETUP.md).
For Luau formatting and static analysis, follow the [Luau tooling guide](docs/production/LUAU-TOOLING.md).
For the reusable Studio launch check and first successful result, see the [smoke-test record](docs/production/SMOKE-TEST.md).

## Project status

**Atlas version:** 0.1  
**Living Kingdoms phase:** P6 implementation and telemetry complete (`P6-0101`–`P6-0107`); the controlled 1/2/4-operative scarcity evidence matrix (`P6-0108`) and evidence-based tuning/sign-off (`P6-0109`) remain the gate. P7 contracts and server-owned class selection (`P7-0101`/`P7-0102`) are already complete under the bounded P6/P7 sequencing exception; all class-effect runtime stays blocked until P6 sign-off. In parallel, the high-ROI horde-and-reward vertical slice ([issue #98](https://github.com/Razzleberrytt/atlas-game-development/issues/98)) has merged bounded slices through PR #128: tuned horde pressure and pacing, confirmed hit/kill impact feedback, floating damage text, shooter hit markers, critical-condition urgency, shared run-only Field XP with squad upgrade choices, scarce enemy ammunition/recovery/Field Intel loot, a server-owned five-weapon loadout roster with distinct models and feel, six readable horde roles, threat-responsive environment mood, and client-local firearm/hostile audio sets.

**Next actions:** the per-milestone status table and the detailed P6–P12 task breakdown live in `docs/roadmap/MASTER-ROADMAP.md`, with canonical acceptance gates in `docs/roadmap/P6-P12-EXECUTION-ROADMAP.md`. The immediate gates are manual: the representative Studio playtest validation of the merged horde-and-reward loop (issue #98 / HROI-0108) and the P6-0108 Studio evidence matrix. The first post-sign-off gameplay task is `P7-0103` (combat specialist vertical slice). The visual production track (`VIS-0102`–`VIS-0105`) and its Studio visual/mix reviews proceed in parallel per `docs/roadmap/VISUAL-PRODUCTION-TRACK.md`.

The parallel RPG track is complete through `RPG-0106`, including the deterministic server-owned five-affix elite roster. Its next ordered implementation task is `RPG-0107`, the relic reward and three-slot framework.

Final public branding is unresolved. Living Kingdoms remains the working title and internal project identifier; naming work is outside the current scope.
