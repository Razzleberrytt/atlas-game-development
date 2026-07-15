# Living Kingdoms

A match-based Roblox real-time strategy game developed through the Atlas workflow.

## Current stage

Repository foundation. The trackable source and test scaffold is in place; no gameplay code has been added yet.

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
├── src/
│   ├── client/
│   ├── server/
│   └── shared/
├── tests/
└── README.md
```

The source and test directories contain placeholder files so Git preserves the scaffold. Rojo mappings will be added separately in `LK-0002`; client and server bootstrap scripts remain part of `LK-0003`.

## Active task

`LK-0002` — Add `default.project.json` mappings for client, server, and shared source.

Use `prompts/codex-master-prompt.md` and append:

```text
Execute task LK-0002: Add default.project.json mappings for client, server, and shared source.
```
