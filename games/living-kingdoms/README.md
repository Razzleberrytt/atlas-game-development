# Living Kingdoms

Living Kingdoms is the temporary working title and internal identifier for a brutally difficult cooperative isometric survival game on Roblox. Final public branding is unresolved; repository, folder, Rojo project, script, and namespace naming remain unchanged.

## Current stage

The project is in P1, tactical player movement and character control. The initial MVP targets 1–4 players, while architecture should permit later support for up to 8. Each player controls one specialist operative rather than an army.

The existing client starts a fixed elevated tactical camera and lets the local player move Roblox's standard character relative to that camera. Mouse-wheel zoom and configurable world-space focus-point bounds remain active. Keyboard camera panning remains implemented but is temporarily disabled while survivor movement is active so one keypress cannot move both the character and camera.

## Preserved project layout

```text
living-kingdoms/
├── default.project.json
├── src/
│   ├── client/
│   │   ├── Controllers/
│   │   │   ├── CameraController.luau
│   │   │   └── SurvivorController.luau
│   │   └── init.client.luau
│   ├── server/
│   │   ├── Systems/
│   │   │   ├── MovementStateReplicationSystem.luau
│   │   │   └── MovementValidationSystem.luau
│   │   └── init.server.luau
│   └── shared/
│       └── Config/
│           ├── MovementLimits.luau
│           └── MovementStateConfig.luau
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

## Local survivor movement

The client bootstrap initializes and starts `SurvivorController` after `CameraController`. Both controllers expose `init()`, `start()`, `stop()`, and `destroy()` with safe repeated calls and terminal destruction.

`SurvivorController` binds to the existing local-player character, `Humanoid`, and `HumanoidRootPart`, including respawns and temporary missing instances. W/A/S/D and arrow-key input is converted through the tactical camera's horizontal look and right vectors, normalized to prevent faster diagonals, and applied every render step through `Humanoid:Move()`. Roblox's normal Humanoid movement, collision, and WalkSpeed remain in use. Processed input and text-box focus suppress movement, and Roblox's default character controls are disabled while this controller is active so movement is not double-applied.

## Prototype movement authority boundary

Responsive movement still uses the local `SurvivorController`, Roblox's standard `Humanoid`, and normal character network ownership. `MovementLimits` names the shared prototype values: maximum horizontal speed `16` studs per second, observation interval `0.25` seconds, horizontal tolerance `4` studs, and warning cooldown `2` seconds. The client uses the configured speed as its intended Humanoid WalkSpeed; the server independently uses the same speed as a validation limit and does not trust any client-reported position, speed, timestamp, or validation state.

The server starts one `MovementValidationSystem` and uses one shared bounded Heartbeat loop for all active players. For each valid living character, it stores the last accepted root position and server timestamp. At an observation, allowed horizontal displacement is `16 * elapsed server seconds + 4 studs`. Vertical displacement is intentionally excluded so normal jumping, falling, slopes, and small physics variation do not cause corrections.

Initial spawn and replacement characters establish a fresh accepted point. Missing characters, missing or replaced `HumanoidRootPart` instances, and dead Humanoids clear the accepted sample so respawn or temporary incomplete character state cannot be compared with stale data. Player state is removed on leave, character replacement overwrites the prior state, and stopping the system disconnects its shared connections and clears all state. No server-authorized teleport or reset gameplay exists yet; any future system that adds one must explicitly coordinate a validation reset before moving the character.

When horizontal displacement clearly exceeds the formula, the server restores the root to the last accepted full position while preserving its orientation, clears assembly linear and angular velocity, advances the accepted timestamp to stabilize the next observation, and emits `[Living Kingdoms] Corrected impossible movement for <player>` at most once per two-second cooldown. Consequential correction remains server-owned.

This is only a prototype movement sanity boundary. It is deliberately tolerant, observes discrete samples rather than continuous paths, and is not production-grade exploit prevention. It does not add movement remotes, custom replication, client prediction/reconciliation, teleport gameplay, or a speculative security framework.

## Survivor facing and replicated movement state

While survivor control is active, `SurvivorController` temporarily disables the local Humanoid's automatic rotation and turns the character toward the normalized camera-relative movement direction. Releasing input preserves the last facing. The controller restores the Humanoid's prior `AutoRotate` value on stop, character replacement, or destruction. No aiming system exists yet, so all current facing is movement-driven; a future aiming task must explicitly define when aim overrides movement facing.

The server observes every active living character from one shared bounded loop. `MovementStateConfig` names the `SurvivorMovementState` and `SurvivorFacingDirection` character attributes, the `Idle` and `Moving` state IDs, a `0.1`-second observation interval, and a `1`-stud-per-second moving threshold. The server derives speed from successive replicated root positions and publishes the root's horizontal look direction while moving. Idle preserves the last known facing so other clients see stable presentation state.

There is no client movement-state remote and the server accepts no client-supplied facing, speed, validation state, or transform. Missing, dead, or replaced characters reset observation samples; replacement clears the old character's attributes, player leave removes state, and system shutdown disconnects the shared connections and clears all replicated state. These attributes are presentation signals, not a production anti-cheat or an animation system. Their discrete observation can briefly lag a transition by one interval and physics-driven horizontal motion can qualify as moving.

## Preserved camera behavior

The client bootstrap initializes and starts `CameraController`. The controller exposes `init()`, `start()`, `stop()`, and `destroy()`; repeated lifecycle calls are safe no-ops when the requested state is already satisfied, and destruction is terminal.

The current view uses initial focus point `(0, 0, 0)`, pitch `-60` degrees, yaw `45` degrees, and height `80` studs. Mouse-wheel zoom changes height by `10` studs per wheel unit and clamps it from `40` to `160` studs. The focus point is clamped from `-128` to `128` on X and Z. Keyboard panning remains available to the camera controller at `48` studs per second, but `SurvivorController` disables it while active and restores it on stop.

These values and controls are not the final survival-camera design. Survivor movement temporarily owns the shared movement keys; LK-0104 will address follow behavior, framing, and longer-term control coexistence. Bounds must later be adapted to one authored operation map. Working camera code remains intact unless a focused survival task demonstrates a change is needed.

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

`LK-0104 — Adapt tactical camera framing around the controlled survivor.`

This task is limited to camera framing and control coexistence. It must not add combat, aiming, enemies, classes, objectives, progression, saving, or other later systems.
