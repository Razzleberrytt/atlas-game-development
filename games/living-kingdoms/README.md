# Living Kingdoms

A match-based Roblox real-time strategy game developed through the Atlas workflow.

## Current stage

Repository foundation. The source scaffold and Rojo mappings are in place; no gameplay code has been added yet.

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
│   ├── server/
│   └── shared/
├── tests/
└── README.md
```

The source and test directories contain placeholder files so Git preserves the scaffold. `default.project.json` maps source into Roblox services as follows:

| Source path | Roblox destination |
| --- | --- |
| `src/client` | `StarterPlayer/StarterPlayerScripts/Client` |
| `src/server` | `ServerScriptService/Server` |
| `src/shared` | `ReplicatedStorage/Shared` |

Client and server bootstrap scripts remain part of `LK-0003`.

## Active task

`LK-0003` — Add minimal client and server bootstrap scripts.

Use `prompts/codex-master-prompt.md` and append:

```text
Execute task LK-0003: Add minimal client and server bootstrap scripts.
```
