# Agent Operating Contract

This repository is designed for GitHub-first development by humans and coding agents. The repository is the source of truth for gameplay code, configuration, tests, technical documentation, and reproducible builds.

## Primary project

The active Roblox game is `games/living-kingdoms`.

Read these files before changing it:

1. `games/living-kingdoms/AGENTS.md`
2. `games/living-kingdoms/README.md`
3. `docs/bible/00-project-charter.md`
4. `docs/bible/01-mvp.md`
5. `docs/architecture/technical-blueprint.md`
6. `docs/roadmap/MASTER-ROADMAP.md`

More specific `AGENTS.md` files override this file for their directory scope.

## Source-of-truth rules

- Treat `games/living-kingdoms/src` as canonical for Luau source.
- Treat `games/living-kingdoms/default.project.json` as canonical for the Rojo DataModel mapping.
- Treat `games/living-kingdoms/tests` as required regression coverage.
- Do not edit generated `.rbxl`, `.rbxlx`, sourcemap, or build-output files as source code.
- Do not import a Roblox place by blindly replacing the existing `src` tree.
- Preserve server authority for combat, progression, persistence, rewards, inventory, health, enemy state, and other consequential gameplay.
- Never trust client-provided positions, timestamps, damage, targets, cooldown completion, currency, inventory, or progression state without server validation.

## Required validation

From the repository root, install the pinned tools in `rokit.toml`, then run:

```bash
python scripts/validate_living_kingdoms_layout.py
stylua --check games/living-kingdoms/src
selene games/living-kingdoms/src

find games/living-kingdoms/tests -type f -name '*.test.luau' -print0 \
  | sort -z \
  | xargs -0 -n1 lune run

rojo build games/living-kingdoms/default.project.json \
  --output /tmp/LivingKingdoms.rbxlx
```

A change is not complete merely because it compiles. Update or add focused tests for behavior changes and document any Roblox-engine behavior that cannot be validated outside Studio.

## Change discipline

- Make the smallest coherent change that completes the task.
- Preserve existing architecture unless the task explicitly requires a migration.
- Prefer pure modules for rules and calculations; keep Roblox service integration at clear runtime boundaries.
- Keep client, server, and shared responsibilities separated.
- Do not invent asset IDs, animation IDs, product IDs, place IDs, universe IDs, or secrets.
- Do not commit credentials, cookies, tokens, local Studio settings, or generated build artifacts.
- Do not weaken tests or remove security checks to make CI pass.
- Update relevant documentation when changing architecture, setup, controls, data contracts, or the Studio boundary.

## Roblox Studio boundary

Routine code development should happen through GitHub, agents, local editors, Rojo, Lune, Selene, StyLua, and CI. Roblox Studio is still required for engine-level playtesting, visual world authoring, terrain, animation authoring, asset permissions, certain instance properties, device emulation, performance profiling, and publishing.

Follow `docs/production/RBXL-IMPORT-MIGRATION.md` whenever a newer `.rbxl` or `.rbxlx` place must be reconciled with repository source.

## Completion report

When finishing a task, report:

- files changed;
- behavior changed;
- validation performed and results;
- remaining Studio-only checks;
- risks, assumptions, or follow-up work.
