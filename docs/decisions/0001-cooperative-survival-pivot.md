# Decision 0001 — Pivot to Cooperative Isometric Survival

**Status:** Accepted

**Task:** LK-PIVOT-001

**Date:** 2026-07-15

## Context

Living Kingdoms began as a match-based Roblox RTS centered on selecting workers, gathering wood, constructing a Barracks, producing Swordsmen, and destroying an enemy Town Hall. Development completed the repository foundation and the first camera capabilities, but had not invested in unit selection, commanded movement, economy, construction, production, or RTS combat.

The project now has a clearer and more distinctive target: a brutally difficult cooperative isometric survival game built around separated players, limited visibility, interdependent specialist roles, finite ammunition and recovery, forced relocation, escalating hostile pressure, authored objectives, a boss climax, and persistent career pride with minimal permanent power.

This direction may draw general design lessons from classic cooperative survival custom maps, but the product will not reuse protected names, branded abbreviations, characters, lore, maps, assets, exact classes, or implementation details.

## Decision

Pivot Living Kingdoms from army-command RTS gameplay to finite, authored cooperative survival operations for up to eight players. Target 1–4 players in the MVP and preserve an architectural path to eight.

Living Kingdoms remains the temporary working title and internal identifier. Final public branding is unresolved. No repository, folder, Rojo project, script, or namespace rename is part of this decision.

## Why pivot now

The pivot occurs before major gameplay investment. Completed work is mostly genre-neutral foundation and camera functionality; the expensive RTS-specific systems were still roadmap entries. Changing direction now avoids building selection, worker economy, construction, production, formation, and army-command systems that do not serve the new player fantasy. The cost is primarily documentation and sequencing, while the reusable technical foundation remains intact.

## Preserved

- Repository structure and Atlas workflow
- Rojo project and client/server/shared mappings
- Client and server bootstrap scripts
- Pinned StyLua, Selene, and Rojo tooling
- Production, build, and smoke-test procedures
- Server-authority and data-driven configuration principles
- `CameraController` lifecycle
- Elevated overhead view, keyboard panning, mouse-wheel zoom, and configurable focus-point bounds
- Historical Git records of completed work

The camera bounds and control relationship will later be adapted around an authored survival-operation map. Working camera code is not deleted or rewritten by this decision.

## Discarded or superseded

- The fantasy of commanding an army or kingdom
- RTS unit selection and ownership-selection flows
- Worker spawning, movement commands, and formation spacing
- Wood gathering, carrying, deposits, and worker economy
- Town Hall and Barracks gameplay
- Base building, construction, production queues, and Swordsmen
- RTS attack commands and destroying an enemy Town Hall as the win condition
- Former future tasks LK-0015–LK-0017 and LK-0020–LK-0069, as detailed in the master roadmap

These tasks are marked superseded, not completed. Generic concepts such as health, damage, enemy AI, and match state require new survival-specific designs rather than direct continuation of RTS specifications.

## Consequences

- Canonical product, MVP, architecture, roadmap, and readme documents must describe cooperative survival consistently.
- The next gameplay milestone controls one operative rather than selecting units.
- Cooperative visibility, scarcity, classes, operation scripting, and persistence become required product systems.
- Networking must protect ammunition, damage, health, objectives, progression, and gameplay-relevant information on the server.
- Difficulty and progression must reward mastery without selling or accumulating decisive combat power.
- One authored operation is completed before multiple maps, large class rosters, or broad metagame features.

## First follow-up

`LK-0101 — Add camera-relative movement for one local survivor` is the first executable gameplay task. It is intentionally limited to reliable desktop control of one character while preserving the existing tactical camera. It does not implement aiming, weapons, enemies, classes, objectives, progression, or any other gameplay system.
