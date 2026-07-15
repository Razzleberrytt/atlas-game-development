# Living Kingdoms

A match-based Roblox real-time strategy game developed through the Atlas workflow.

## Current stage

Repository foundation. No gameplay code has been added yet.

## First playable milestone

A gray-box map with five Workers where the player can:

- Pan and zoom an overhead camera
- Select one Worker
- Drag-select multiple Workers
- See selection indicators
- Issue a movement command
- Observe basic destination spacing

## Planned project layout

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

The folders and Rojo mappings should be introduced by roadmap tasks rather than added as empty speculative structure.

## Active task

`LK-0001` — Create the Rojo-compatible Roblox project scaffold.

Use `prompts/codex-master-prompt.md` and append:

```text
Execute task LK-0001: Create the Rojo-compatible Roblox project scaffold.
```
