# Living Kingdoms — Technical Blueprint

## Architecture objective

Support a small, server-authoritative cooperative survival operation without premature framework complexity. Favor clear boundaries, responsive local presentation, data-driven configuration, replaceable systems, and an architecture that targets 1–4 players now without preventing 8-player support later.

## Authority model

### Client owns

- Tactical camera controls and presentation
- Local input sampling and interpretation
- Immediate aim, movement, reload, interaction, and UI feedback
- Local visibility presentation, lighting effects, indicators, and non-authoritative effects
- Requests to move, fire, reload, use class abilities, interact, revive, or collect supplies

### Server owns

- Operative identity, class eligibility, spawn assignment, and match participation
- Validation of movement constraints and interaction range
- Weapon configuration, fire cadence, ammunition, reload state, hit validation, damage, and death
- Health, incapacitation, revival, and recovery resources
- Supply availability and collection
- Enemy spawning, navigation, targeting, attacks, and boss state
- Objective, operation, extraction, success, and failure state
- XP awards, ranks, unlocks, and persistent data
- Any gameplay-relevant visibility or discovery rule

The client requests actions and may predict safe presentation for responsiveness. The server validates and applies consequential state. Never trust client-supplied damage, ammunition totals, health, inventory, class unlocks, XP, rank, objective completion, enemy state, or visibility claims.

Roblox character network ownership may provide responsive physical simulation, but it does not make the client authoritative. Movement work must define server-side sanity checks and recovery behavior before competitive integrity or exploit resistance is claimed.

## Source layout

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

This is a boundary guide, not permission to scaffold every future module before it is needed.

## Intended system boundaries

- `CameraController` — existing elevated camera lifecycle, panning, zoom, and current bounds
- `SurvivorController` — local operative input and responsive movement intent
- `AimController` — local pointer-to-world aim interpretation and presentation
- `WeaponController` — local firearm input, feedback, and server requests
- `SquadUIController` — personal status, teammate status, location aids, and operation information
- `PlayerService` — server-owned operative lifecycle, class assignment, and spawn state
- `MovementValidationSystem` — server sanity checks for operative movement and state restrictions
- `CombatSystem` — server-owned firing validation, hits, health, damage, incapacitation, revival, and death
- `InventorySystem` — server-owned ammunition, recovery resources, and supply collection
- `ClassSystem` — server-owned specialist eligibility and class actions
- `VisibilitySystem` — gameplay-relevant discovery and squad-location rules
- `EnemySystem` — enemy lifecycle, pursuit, attacks, horde pressure, and special behaviors
- `ObjectiveSystem` — authored objective state and interactions
- `OperationService` — briefing, insertion, escalation, extraction, success, failure, and results
- `ProgressionService` — persistent XP, ranks, class unlocks, and data-store recovery

Names may be refined in the milestone that first needs them. Avoid duplicate managers or speculative frameworks.

## Reusable existing systems

- Repository layout, Rojo project mappings, bootstrap scripts, pinned toolchain, production documentation, and smoke/build workflows remain valid.
- `CameraController` and its explicit `init`, `start`, `stop`, and `destroy` lifecycle remain valid.
- The fixed overhead/elevated view, keyboard panning, mouse-wheel zoom, replacement-camera handling, and configurable focus-point bounds remain implemented and must not be deleted.
- Current strict-mode and client/server/shared dependency rules remain valid.

The camera is a foundation, not a final survival control design. Its bounds must later be configured around the authored operation map. Panning, follow behavior, framing, input coexistence, touch support, and the relationship between camera and controlled operative require focused adaptation. Existing working camera code should be extended only when a survival milestone demonstrates the need.

## Superseded RTS architecture

The former selection, unit-command, worker, resource-economy, building-placement, construction, production-queue, barracks, swordsman, army AI, and enemy Town Hall boundaries are not part of the active product. They are historical concepts in Git history, not planned modules. Generic ideas such as server authority, data-driven configuration, health, damage, enemies, and match state remain useful but must be specified for one-operative cooperative survival rather than reused as RTS contracts.

## Data-driven rules

Balance values belong in shared configuration modules rather than controller logic. Operative, weapon, class, enemy, wave, supply, objective, boss, rank, and operation definitions should use stable IDs and include only the data required by an implemented system. Authored operation configuration must be versionable and testable.

## Networking rules

- Use a small, explicit request and state-update surface.
- Validate player state, class, range, timing, target legality, resource cost, and operation phase on the server.
- Rate-limit requests that can be spammed.
- Use server timestamps or equivalent state for cadence and reload validation.
- Send only information a client needs; limited visibility must not be undermined by replicating hidden tactical state through custom remotes.
- Do not design the MVP around exactly four array slots or fixed player indices; player collections and spawn assignment must tolerate a later limit of eight.
- Define reconnect, leave, and persistence-failure behavior before progression ships.

## Engineering standards

- Luau strict mode where practical
- One primary responsibility per module
- No ambiguous fallback names such as `Manager2` or `HelperFinal`
- No hidden balance constants inside algorithms
- No unrelated refactors in feature pull requests
- New behavior requires a manual verification path; deterministic logic should receive automated tests where feasible
- No gameplay implementation without a focused specification and acceptance criteria

## Performance policy

Measure the actual cooperative load rather than inheriting former RTS unit-count targets. Prototype with 1–4 players, representative horde counts, projectiles or raycasts, AI navigation, visibility effects, and operation scripting. Preserve a path to eight players by avoiding per-player duplication of global enemy work and unbounded per-entity polling loops. Profile before complex optimization.

## Dependency direction

UI and controllers may call shared interfaces. Server systems may depend on shared configuration and utilities. Shared code must not depend on client-only or server-only modules. Persistent progression must not become a dependency of moment-to-moment combat correctness; a match must fail safely if data services are unavailable.

## Change policy

Architecture exists to support the next playable milestone. A new abstraction must solve a present, demonstrated need or remove meaningful duplication. The first post-pivot gameplay change is only camera-relative movement for one local survivor; it must not introduce weapons, enemies, classes, progression, or other later systems.
