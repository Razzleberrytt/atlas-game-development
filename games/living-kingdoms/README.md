# Living Kingdoms

Living Kingdoms is the temporary working title and internal identifier for a brutally difficult cooperative isometric survival game on Roblox. Final public branding is unresolved; repository, folder, Rojo project, script, and namespace naming remain unchanged.

## Current stage

P0 reframes the project around finite authored survival operations. The initial MVP targets 1–4 players, while architecture should permit later support for up to 8. Each player will control one specialist operative rather than an army.

No survival gameplay is implemented yet. The existing client starts a fixed elevated tactical camera with desktop keyboard panning, mouse-wheel zoom, and configurable world-space focus-point bounds.

## Preserved project layout

```text
living-kingdoms/
├── default.project.json
├── src/
│   ├── client/
│   │   ├── Controllers/
│   │   │   └── CameraController.luau
│   │   └── init.client.luau
│   ├── server/
│   │   └── init.server.luau
│   └── shared/
├── tests/
└── README.md
```

The shared source and test directories contain placeholder files so Git preserves the scaffold. `default.project.json` maps source into Roblox services as follows:

| Source path | Roblox destination |
| --- | --- |
| `src/client` | `StarterPlayer/StarterPlayerScripts/Client` |
| `src/server` | `ServerScriptService/Server` |
| `src/shared` | `ReplicatedStorage/Shared` |

The bootstrap scripts use strict Luau and print these startup confirmations:

- `[Living Kingdoms] Client bootstrap started`
- `[Living Kingdoms] Server bootstrap started`

## Preserved camera behavior

The client bootstrap initializes and starts `CameraController`. The controller exposes `init()`, `start()`, `stop()`, and `destroy()`; repeated lifecycle calls are safe no-ops when the requested state is already satisfied, and destruction is terminal.

The current view uses initial focus point `(0, 0, 0)`, pitch `-60` degrees, yaw `45` degrees, and height `80` studs. Mouse-wheel zoom changes height by `10` studs per wheel unit and clamps it from `40` to `160` studs. Keyboard panning moves the focus point at `48` studs per second relative to the camera's horizontal frame. The focus point is clamped from `-128` to `128` on X and Z.

These values and controls are not the final survival-camera design. Bounds, framing, follow behavior, and input coexistence must later be adapted to one authored operation map. Working camera code must remain intact until a focused survival task demonstrates a change is needed.

## Canonical direction

The source of truth is:

1. [`docs/bible/00-project-charter.md`](../../docs/bible/00-project-charter.md)
2. [`docs/bible/01-mvp.md`](../../docs/bible/01-mvp.md)
3. [`docs/architecture/technical-blueprint.md`](../../docs/architecture/technical-blueprint.md)
4. [`docs/roadmap/MASTER-ROADMAP.md`](../../docs/roadmap/MASTER-ROADMAP.md)
5. [`docs/decisions/0001-cooperative-survival-pivot.md`](../../docs/decisions/0001-cooperative-survival-pivot.md)
6. [`docs/decisions/0002-automatic-combat-targeting.md`](../../docs/decisions/0002-automatic-combat-targeting.md)

The former worker-selection, economy, construction, production, and army-command plan is superseded. Completed repository and camera work is preserved.

Combat uses server-authoritative automatic target acquisition and fire. Players directly control movement, positioning, interaction, reload timing, class abilities, and resource decisions. A future manual priority-target override remains optional and is not part of the first combat milestone.

## Local validation

Follow [`docs/production/LOCAL-SETUP.md`](../../docs/production/LOCAL-SETUP.md), [`docs/production/LUAU-TOOLING.md`](../../docs/production/LUAU-TOOLING.md), [`docs/production/ROJO-BUILD-VALIDATION.md`](../../docs/production/ROJO-BUILD-VALIDATION.md), and [`docs/production/SMOKE-TEST.md`](../../docs/production/SMOKE-TEST.md).

## Next executable task

`LK-0101 — Add camera-relative movement for one local survivor.`

This task is limited to reliable desktop movement for one character while preserving the existing tactical camera. It must not add combat, aiming, enemies, classes, objectives, progression, saving, or other later systems.
