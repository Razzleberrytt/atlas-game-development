# Living Kingdoms

A match-based Roblox real-time strategy game developed through the Atlas workflow.

## Current stage

Repository foundation complete. The Rojo mappings and minimal client/server bootstraps have passed their first Studio launch smoke test; no gameplay systems have been added yet.

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

They intentionally contain no gameplay systems or framework lifecycle code.

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

`LK-0010` — Create `CameraController` with an explicit public lifecycle.

Use `prompts/codex-master-prompt.md` and append:

```text
Execute task LK-0010: Create CameraController with an explicit public lifecycle.
```
