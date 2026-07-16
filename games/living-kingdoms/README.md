# Living Kingdoms

A match-based Roblox real-time strategy game developed through the Atlas workflow.

## Current stage

The client now starts a fixed overhead strategy camera with desktop keyboard panning, mouse-wheel zoom, and configurable world-space focus-point bounds.

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

The fixed view uses initial focus point `(0, 0, 0)`, pitch `-60` degrees, yaw `45` degrees, and initial height `80` studs. Mouse-wheel zoom changes height by `10` studs per wheel unit and clamps it to the inclusive range from `40` to `160` studs. Wheel forward decreases height to zoom in; wheel backward increases height to zoom out. Every view update recomputes the camera offset from the unchanged pitch, unchanged yaw, and current height before `CFrame.lookAt(cameraPosition, focusPoint)` aims the camera at the preserved world-space focus point. While started, the controller keeps `Workspace.CurrentCamera` Scriptable and reapplies the frame each render step. It safely waits when `CurrentCamera` is unavailable, adopts replacements, and restores the captured `CameraType` and `CFrame` when stopped or when switching cameras where practical.

Keyboard panning moves the mutable world-space focus point at `48` studs per second. `W` or Up Arrow moves forward, `S` or Down Arrow moves backward, `A` or Left Arrow moves left, and `D` or Right Arrow moves right. Forward and right come from the camera frame projected onto the horizontal XZ plane, combined input is normalized before delta-time movement is applied, and panning remains functional at every zoom height. Game-processed pan and zoom input and input received while a Roblox text box is focused are ignored. Input connections are created by `start()` and disconnected by `stop()` or `destroy()`.

The mutable focus point is clamped after every pan update to the inclusive world-space rectangle from `-128` to `128` on X and from `-128` to `128` on Z. Both axes are clamped independently so diagonal movement stops exactly at corners, and continued or repeated input against an edge cannot accumulate movement outside the boundary. Bounds constrain only the focus point and do not change with camera height or account for the viewport footprint. Smoothing, acceleration, rotation, edge scrolling, touch controls, and gameplay behavior remain deferred.

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

`LK-0015` — Add smoothing without making input feel delayed.

Use `prompts/codex-master-prompt.md` and append:

```text
Execute task LK-0015: Add smoothing without making input feel delayed.
```
