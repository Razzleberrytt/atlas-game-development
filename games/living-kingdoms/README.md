# Living Kingdoms

A match-based Roblox real-time strategy game developed through the Atlas workflow.

## Current stage

The client now starts a fixed overhead strategy camera. Movement and zoom controls remain deferred.

## First playable milestone

A gray-box map with five Workers where the player can:

- Pan and zoom an overhead camera
- Select one Worker
- Drag-select multiple Workers
- See selection indicators
- Issue a movement command
- Observe basic destination spacing

## Current project layout

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

The shared source and test directories contain placeholder files so Git preserves the remaining scaffold. `default.project.json` maps source into Roblox services as follows:

| Source path | Roblox destination |
| --- | --- |
| `src/client` | `StarterPlayer/StarterPlayerScripts/Client` |
| `src/server` | `ServerScriptService/Server` |
| `src/shared` | `ReplicatedStorage/Shared` |

The client and server bootstrap scripts use strict Luau and print these startup confirmations when they run:

- `[Living Kingdoms] Client bootstrap started`
- `[Living Kingdoms] Server bootstrap started`

The client bootstrap initializes and starts `CameraController` before printing its existing confirmation. The controller exposes `init()`, `start()`, `stop()`, and `destroy()`; repeated lifecycle calls are safe no-ops when the requested state is already satisfied, and destruction is terminal.

The fixed view uses focus point `(0, 0, 0)`, pitch `-60` degrees, yaw `45` degrees, and height `80` studs. These values derive the initial position `(32.6599, 80, 32.6599)`, and `CFrame.lookAt(initialPosition, focusPoint)` aims the camera. While started, the controller keeps `Workspace.CurrentCamera` Scriptable and reapplies the fixed frame each render step. It safely waits when `CurrentCamera` is unavailable, adopts replacements, and restores the captured `CameraType` and `CFrame` when stopped or when switching cameras where practical. Pan, zoom, smoothing, bounds, rotation, edge scrolling, touch controls, and gameplay behavior remain deferred.

### Bootstrap verification

After synchronizing the project into Roblox Studio, start a play session and confirm that the Output window shows each startup message once with no new errors or warnings.

## Local setup

Follow the Windows guide at [`docs/production/LOCAL-SETUP.md`](../../docs/production/LOCAL-SETUP.md) to install the pinned Rojo CLI and Studio plugin, start the server, connect Studio, and complete the verification checklist.

## Luau tooling

Follow [`docs/production/LUAU-TOOLING.md`](../../docs/production/LUAU-TOOLING.md) for the pinned Windows commands to format, check, and lint all Living Kingdoms source.

## Rojo build validation

The pinned Rojo 7.7.0 CLI successfully generated a non-empty place file outside the repository, and the synchronized Roblox Studio tree contained all three documented mappings. See [`docs/production/ROJO-BUILD-VALIDATION.md`](../../docs/production/ROJO-BUILD-VALIDATION.md) for the commands and results.

## Smoke testing

Follow [`docs/production/SMOKE-TEST.md`](../../docs/production/SMOKE-TEST.md) for the reusable Studio launch checklist and the first successful launch record.

## Active task

`LK-0012` — Add keyboard camera panning.

Use `prompts/codex-master-prompt.md` and append:

```text
Execute task LK-0012: Add keyboard camera panning.
```
