# Living Kingdoms — Technical Blueprint

## Architecture objective

Support a small Roblox RTS without creating premature framework complexity. Favor clear boundaries, server authority, data-driven configuration, and replaceable systems.

## Authority model

### Client owns

- Camera controls
- Input interpretation
- Selection visuals
- Placement previews
- Immediate UI feedback
- Non-authoritative effects

### Server owns

- Unit and building ownership
- Resource balances
- Command validation
- Construction
- Production
- Health, damage, and death
- Enemy AI
- Match state and victory

The client requests actions. The server validates and applies consequential state changes.

## Initial source layout

```text
games/living-kingdoms/
├── default.project.json
├── src/
│   ├── client/
│   │   ├── Controllers/
│   │   └── UI/
│   ├── server/
│   │   ├── Services/
│   │   └── Systems/
│   └── shared/
│       ├── Config/
│       ├── Network/
│       ├── Types/
│       └── Utilities/
├── tests/
└── README.md
```

## Initial system boundaries

- `CameraController` — overhead camera movement and zoom
- `SelectionController` — local selection state and visuals
- `CommandController` — converts player input into command requests
- `UnitService` — ownership, spawning, and unit lookup
- `MovementSystem` — server-validated destinations and movement state
- `ResourceSystem` — nodes, carrying, deposits, and balances
- `BuildingSystem` — placement validation and construction
- `ProductionSystem` — unit queues and spawn rules
- `CombatSystem` — targeting, attacks, damage, and death
- `EnemyAISystem` — enemy decisions using public system APIs
- `MatchService` — setup, lifecycle, victory, and defeat

## Data-driven rules

Balance values belong in shared configuration modules rather than controller logic. Unit and building definitions should include stable IDs, costs, timings, health, movement or combat statistics, and asset references.

## Networking rules

- Use a small, explicit command surface.
- Validate player ownership and legal targets on the server.
- Rate-limit requests that could be spammed.
- Never accept client-supplied resource totals, damage amounts, or unit ownership.
- Avoid transmitting complete world state when a targeted update is sufficient.

## Engineering standards

- Luau strict mode where practical
- One primary responsibility per module
- No `Manager2`, `HelperFinal`, or similarly ambiguous names
- No hidden balance constants inside algorithms
- No unrelated refactors in feature pull requests
- New behavior requires a manual verification path; deterministic logic should receive automated tests where feasible

## Performance policy

Do not promise hundreds of units before measurement. Initial target:

- Smooth play with 25 active units per player
- Stable desktop prototype before mobile optimization
- No per-unit unbounded polling loops
- Prefer shared update systems and staggered work
- Profile before introducing complex optimization

## Dependency direction

UI and controllers may call shared interfaces. Server systems may depend on shared configuration and utilities. Shared code must not depend on client-only or server-only modules.

## Change policy

Architecture exists to support the next playable milestone. A new abstraction must solve a present, demonstrated need or remove meaningful duplication; speculative frameworks are deferred.
